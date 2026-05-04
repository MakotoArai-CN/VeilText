const std = @import("std");
const builtin = @import("builtin");
const compat = @import("compat.zig");
const config = @import("config.zig");
const utils = @import("utils.zig");
const crypto_engine = @import("crypto/engine.zig");
const crypto_base = @import("crypto/base.zig");
const crypto_hash = @import("crypto/hash.zig");
const gen = @import("generator/generator.zig");
const ai_mod = @import("generator/ai.zig");
const news_mod = @import("generator/news.zig");
const wordbank_mod = @import("generator/wordbank.zig");
const db_mod = @import("storage/db.zig");
const history_mod = @import("storage/history.zig");
const i18n_mod = @import("i18n/i18n.zig");
const view_layout = @import("view/layout.zig");

// ═══════════════════════════════════════════════════════════════════
//  Server State
// ═══════════════════════════════════════════════════════════════════

pub const ServerState = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    environ_map: *const std.process.Environ.Map,
    cfg: config.Runtime,
    database: *db_mod.DB,
    hist: *history_mod.History,
    template_data: wordbank_mod.TemplateData,
    // Mutable AI config (updated by /api/settings PUT)
    ai_provider: []const u8 = "openai",
    ai_endpoint: []const u8 = "",
    ai_key: []const u8 = "",
    ai_model: []const u8 = "",

    pub fn init(
        allocator: std.mem.Allocator,
        io: std.Io,
        environ_map: *const std.process.Environ.Map,
        cfg: config.Runtime,
    ) !ServerState {
        std.Io.Dir.cwd().createDirPath(io, cfg.data_dir) catch {};

        const database = try allocator.create(db_mod.DB);
        database.* = try db_mod.DB.init(allocator, io, cfg.data_dir, cfg.db_file);

        const hist = try allocator.create(history_mod.History);
        hist.* = history_mod.History.init(allocator, database);

        var template_data = try wordbank_mod.TemplateData.initDefaults(allocator);
        if (database.get("settings:template_data")) |saved| {
            defer allocator.free(saved);
            var loaded = wordbank_mod.TemplateData.fromJson(allocator, saved) catch null;
            if (loaded) |*data| {
                template_data.deinit();
                template_data = data.*;
            }
        }

        return .{
            .allocator = allocator,
            .io = io,
            .environ_map = environ_map,
            .cfg = cfg,
            .database = database,
            .hist = hist,
            .template_data = template_data,
            .ai_provider = "openai",
            .ai_endpoint = cfg.openai_endpoint,
            .ai_key = cfg.openai_api_key,
            .ai_model = "gpt-4o-mini",
        };
    }

    pub fn deinit(self: *ServerState) void {
        self.template_data.deinit();
        self.hist.deinit();
        self.allocator.destroy(self.hist);
        self.database.deinit();
        self.allocator.destroy(self.database);
    }
};

// ═══════════════════════════════════════════════════════════════════
//  Connection context (heap-allocated per connection)
// ═══════════════════════════════════════════════════════════════════

const ConnectionContext = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    stream: std.Io.net.Stream,
    state: *ServerState,
};

// ═══════════════════════════════════════════════════════════════════
//  Mutex for state mutation (AI config updates)
// ═══════════════════════════════════════════════════════════════════
var state_mutex: std.Io.Mutex = .init;

// ═══════════════════════════════════════════════════════════════════
//  HTTP Server
// ═══════════════════════════════════════════════════════════════════

pub fn start(
    allocator: std.mem.Allocator,
    io: std.Io,
    environ_map: *const std.process.Environ.Map,
    cfg: config.Runtime,
) !void {
    var state = try ServerState.init(allocator, io, environ_map, cfg);
    defer state.deinit();

    const address = std.Io.net.IpAddress.parse(cfg.bind_host, cfg.port) catch {
        std.log.err("Invalid bind address: {s}:{d}", .{ cfg.bind_host, cfg.port });
        return error.InvalidAddress;
    };

    var listener = try address.listen(io, .{
        .mode = .stream,
        .reuse_address = true,
    });
    defer listener.deinit(io);

    std.log.info("{s} v{s} listening on {s}:{d}", .{
        config.app_name,
        config.app_version,
        cfg.bind_host,
        cfg.port,
    });
    std.log.info("Open http://{s}:{d}/ in your browser", .{ cfg.bind_host, cfg.port });

    while (true) {
        const stream = listener.accept(io) catch |err| {
            std.log.warn("Accept error: {}", .{err});
            continue;
        };

        const ctx = allocator.create(ConnectionContext) catch {
            stream.close(io);
            continue;
        };
        ctx.* = .{
            .allocator = allocator,
            .io = io,
            .stream = stream,
            .state = &state,
        };

        const thread = std.Thread.spawn(.{}, connectionMain, .{ctx}) catch {
            stream.close(io);
            allocator.destroy(ctx);
            continue;
        };
        thread.detach();
    }
}

fn connectionMain(ctx: *ConnectionContext) void {
    defer {
        ctx.stream.close(ctx.io);
        ctx.allocator.destroy(ctx);
    }

    var read_buf: [16 * 1024]u8 = undefined;
    var write_buf: [16 * 1024]u8 = undefined;
    var net_reader = ctx.stream.reader(ctx.io, &read_buf);
    var net_writer = ctx.stream.writer(ctx.io, &write_buf);
    var http_server = std.http.Server.init(&net_reader.interface, &net_writer.interface);

    while (true) {
        var request = http_server.receiveHead() catch break;
        handleRequest(ctx, &request) catch {
            request.respond(
                "{\"ok\":false,\"error\":\"Internal Server Error\"}",
                .{
                    .status = .internal_server_error,
                    .extra_headers = &[_]std.http.Header{
                        .{ .name = "Content-Type", .value = "application/json; charset=utf-8" },
                    },
                },
            ) catch {};
            break;
        };
    }
}

fn handleRequest(ctx: *ConnectionContext, request: *std.http.Server.Request) !void {
    var arena = std.heap.ArenaAllocator.init(ctx.allocator);
    defer arena.deinit();
    const aa = arena.allocator();

    const path = request.head.target;

    // Detect language from Accept-Language header
    const lang = blk: {
        var it = request.iterateHeaders();
        while (it.next()) |header| {
            if (std.ascii.eqlIgnoreCase(header.name, "accept-language")) {
                break :blk config.Language.fromAcceptLanguage(header.value);
            }
        }
        break :blk config.Language.en;
    };

    // Check for ?lang= query parameter override
    const effective_lang = blk: {
        if (std.mem.indexOf(u8, path, "?lang=")) |idx| {
            const lang_str = path[idx + 6 ..];
            const end = std.mem.indexOfScalar(u8, lang_str, '&') orelse lang_str.len;
            const code = lang_str[0..end];
            if (std.mem.eql(u8, code, "zh")) break :blk config.Language.zh;
            if (std.mem.eql(u8, code, "ja")) break :blk config.Language.ja;
            if (std.mem.eql(u8, code, "en")) break :blk config.Language.en;
        }
        break :blk lang;
    };

    // Strip query string for routing
    const clean_path = if (std.mem.indexOfScalar(u8, path, '?')) |q| path[0..q] else path;

    // Route
    if (std.mem.eql(u8, clean_path, "/") or std.mem.eql(u8, clean_path, "/index.html")) {
        try serveHomePage(aa, request, effective_lang);
    } else if (std.mem.startsWith(u8, clean_path, "/api/")) {
        try handleApiRoute(aa, ctx.state, request, clean_path);
    } else {
        try respondText(request, .not_found, "404 Not Found");
    }
}

// ═══════════════════════════════════════════════════════════════════
//  Route Handlers
// ═══════════════════════════════════════════════════════════════════

fn serveHomePage(alloc: std.mem.Allocator, request: *std.http.Server.Request, lang: config.Language) !void {
    var body_buf: std.Io.Writer.Allocating = .init(alloc);
    const writer = &body_buf.writer;

    try view_layout.renderApp(writer, lang);

    const body = body_buf.toOwnedSlice() catch return;
    defer alloc.free(body);

    try request.respond(body, .{
        .status = .ok,
        .extra_headers = &[_]std.http.Header{
            .{ .name = "Content-Type", .value = "text/html; charset=utf-8" },
            .{ .name = "Cache-Control", .value = "no-cache" },
        },
    });
}

fn handleApiRoute(alloc: std.mem.Allocator, state: *ServerState, request: *std.http.Server.Request, path: []const u8) !void {
    if (std.mem.eql(u8, path, "/api/encrypt") and request.head.method == .POST) {
        try handleEncrypt(alloc, state, request);
    } else if (std.mem.eql(u8, path, "/api/decrypt") and request.head.method == .POST) {
        try handleDecrypt(alloc, state, request);
    } else if (std.mem.eql(u8, path, "/api/decode-smart") and request.head.method == .POST) {
        try handleSmartDecode(alloc, state, request);
    } else if (std.mem.eql(u8, path, "/api/puzzle/split") and request.head.method == .POST) {
        try handlePuzzleSplit(alloc, state, request);
    } else if (std.mem.eql(u8, path, "/api/puzzle/merge") and request.head.method == .POST) {
        try handlePuzzleMerge(alloc, state, request);
    } else if (std.mem.eql(u8, path, "/api/generate") and request.head.method == .POST) {
        try handleGenerate(alloc, state, request);
    } else if (std.mem.eql(u8, path, "/api/history") and request.head.method == .GET) {
        try handleGetHistory(alloc, state, request);
    } else if (std.mem.eql(u8, path, "/api/history") and request.head.method == .DELETE) {
        try handleClearHistory(alloc, state, request);
    } else if (std.mem.startsWith(u8, path, "/api/history/") and request.head.method == .DELETE) {
        try handleDeleteHistory(alloc, state, request, path);
    } else if (std.mem.eql(u8, path, "/api/settings") and request.head.method == .GET) {
        try handleGetSettings(request);
    } else if (std.mem.eql(u8, path, "/api/settings") and request.head.method == .PUT) {
        try handleUpdateSettings(alloc, state, request);
    } else if (std.mem.eql(u8, path, "/api/template-data") and request.head.method == .GET) {
        try handleGetTemplateData(alloc, state, request);
    } else if (std.mem.eql(u8, path, "/api/template-data") and request.head.method == .PUT) {
        try handleUpdateTemplateData(alloc, state, request);
    } else if (std.mem.eql(u8, path, "/api/template-data") and request.head.method == .DELETE) {
        try handleResetTemplateData(state, request);
    } else if (std.mem.eql(u8, path, "/api/ai/chat") and request.head.method == .POST) {
        try handleAiChat(alloc, state, request);
    } else if (std.mem.eql(u8, path, "/api/ai/test") and request.head.method == .POST) {
        try handleAiTest(alloc, state, request);
    } else {
        try respondJson(request, .not_found, "{\"ok\":false,\"error\":\"Not Found\"}");
    }
}

// ═══════════════════════════════════════════════════════════════════
//  API Handlers
// ═══════════════════════════════════════════════════════════════════

fn handleEncrypt(alloc: std.mem.Allocator, state: *ServerState, request: *std.http.Server.Request) !void {
    const body = try readBody(alloc, request);

    const parsed = std.json.parseFromSlice(std.json.Value, alloc, body, .{}) catch {
        try respondJson(request, .bad_request, "{\"ok\":false,\"error\":\"Invalid JSON\"}");
        return;
    };
    const root = parsed.value;

    const plaintext = jsonStr(root, "text");
    if (plaintext.len == 0) {
        try respondJson(request, .bad_request, "{\"ok\":false,\"error\":\"Missing 'text' field\"}");
        return;
    }

    const steps_val = root.object.get("pipeline") orelse {
        try respondJson(request, .bad_request, "{\"ok\":false,\"error\":\"Missing 'pipeline' field\"}");
        return;
    };

    const steps_array = switch (steps_val) {
        .array => |a| a,
        else => {
            try respondJson(request, .bad_request, "{\"ok\":false,\"error\":\"'pipeline' must be an array\"}");
            return;
        },
    };

    var steps: std.ArrayListUnmanaged(crypto_engine.PipelineStep) = .empty;
    defer steps.deinit(alloc);

    for (steps_array.items) |step_val| {
        const step_obj = switch (step_val) {
            .object => |o| o,
            else => continue,
        };
        const step = crypto_engine.PipelineStep.fromJson(step_obj) catch continue;
        try steps.append(alloc, step);
    }

    if (steps.items.len == 0) {
        try respondJson(request, .bad_request, "{\"ok\":false,\"error\":\"Pipeline must have at least one step\"}");
        return;
    }

    const result = crypto_engine.executePipeline(alloc, plaintext, steps.items) catch {
        try respondJson(request, .internal_server_error, "{\"ok\":false,\"error\":\"Encryption failed\"}");
        return;
    };
    defer alloc.free(result.ciphertext);

    const plaintext_hash = crypto_hash.sha256String(plaintext);
    state.hist.addRecord(.{
        .operation = "encrypt",
        .pipeline_desc = result.description,
        .plaintext_hash = &plaintext_hash,
        .ciphertext_preview = result.ciphertext[0..@min(result.ciphertext.len, 512)],
    }) catch {};

    var resp_buf: std.Io.Writer.Allocating = .init(alloc);
    const w = &resp_buf.writer;
    try w.writeAll("{\"ok\":true,\"ciphertext\":");
    try utils.writeJsonString(w, result.ciphertext);
    try w.writeAll(",\"pipeline_desc\":");
    try utils.writeJsonString(w, result.description);
    try w.writeAll(",\"plaintext_hash\":\"");
    try w.writeAll(&plaintext_hash);
    try w.writeAll("\"}");

    const resp = resp_buf.toOwnedSlice() catch return;
    defer alloc.free(resp);
    try respondJson(request, .ok, resp);
}

fn handleDecrypt(alloc: std.mem.Allocator, state: *ServerState, request: *std.http.Server.Request) !void {
    const body = try readBody(alloc, request);

    const parsed = std.json.parseFromSlice(std.json.Value, alloc, body, .{}) catch {
        try respondJson(request, .bad_request, "{\"ok\":false,\"error\":\"Invalid JSON\"}");
        return;
    };
    const root = parsed.value;

    const ciphertext = jsonStr(root, "text");
    if (ciphertext.len == 0) {
        try respondJson(request, .bad_request, "{\"ok\":false,\"error\":\"Missing 'text' field\"}");
        return;
    }

    const steps_val = root.object.get("pipeline") orelse {
        try respondJson(request, .bad_request, "{\"ok\":false,\"error\":\"Missing 'pipeline' field\"}");
        return;
    };

    const steps_array = switch (steps_val) {
        .array => |a| a,
        else => {
            try respondJson(request, .bad_request, "{\"ok\":false,\"error\":\"'pipeline' must be an array\"}");
            return;
        },
    };

    var steps: std.ArrayListUnmanaged(crypto_engine.PipelineStep) = .empty;
    defer steps.deinit(alloc);

    for (steps_array.items) |step_val| {
        const step_obj = switch (step_val) {
            .object => |o| o,
            else => continue,
        };
        const step = crypto_engine.PipelineStep.fromJson(step_obj) catch continue;
        try steps.append(alloc, step);
    }

    const result = crypto_engine.executeReversePipeline(alloc, ciphertext, steps.items) catch {
        try respondJson(request, .internal_server_error, "{\"ok\":false,\"error\":\"Decryption failed\"}");
        return;
    };
    defer alloc.free(result.ciphertext);

    var verified = false;
    var has_expected_hash = false;
    if (root.object.get("expected_hash")) |v| {
        if (v == .string) {
            has_expected_hash = true;
            const actual_hash = crypto_hash.sha256String(result.ciphertext);
            verified = std.mem.eql(u8, &actual_hash, v.string);
        }
    }

    state.hist.addRecord(.{
        .operation = "decrypt",
        .pipeline_desc = result.description,
        .plaintext_hash = "",
        .ciphertext_preview = ciphertext[0..@min(ciphertext.len, 512)],
    }) catch {};

    var resp_buf: std.Io.Writer.Allocating = .init(alloc);
    const w = &resp_buf.writer;
    try w.writeAll("{\"ok\":true,\"plaintext\":");
    try utils.writeJsonString(w, result.ciphertext);
    try w.writeAll(",\"verified\":");
    try w.writeAll(if (has_expected_hash and verified) "true" else if (has_expected_hash) "false" else "null");
    try w.writeAll(",\"hash_match\":");
    try w.writeAll(if (has_expected_hash and verified) "true" else if (has_expected_hash) "false" else "null");
    try w.writeAll("}");

    const resp = resp_buf.toOwnedSlice() catch return;
    defer alloc.free(resp);
    try respondJson(request, .ok, resp);
}

fn handleSmartDecode(alloc: std.mem.Allocator, state: *ServerState, request: *std.http.Server.Request) !void {
    const body = try readBody(alloc, request);

    const parsed = std.json.parseFromSlice(std.json.Value, alloc, body, .{}) catch {
        try respondJson(request, .bad_request, "{\"ok\":false,\"error\":\"Invalid JSON\"}");
        return;
    };
    const root = parsed.value;

    const ciphertext = jsonStr(root, "text");
    if (ciphertext.len == 0) {
        try respondJson(request, .bad_request, "{\"ok\":false,\"error\":\"Missing 'text' field\"}");
        return;
    }

    const key = jsonStr(root, "key");
    const max_depth: usize = if (root.object.get("max_depth")) |v| switch (v) {
        .integer => |i| @intCast(@max(1, @min(i, 12))),
        else => 8,
    } else 8;

    var steps: std.ArrayListUnmanaged(crypto_engine.PipelineStep) = .empty;
    defer steps.deinit(alloc);

    if (root.object.get("pipeline")) |steps_val| {
        if (steps_val == .array) {
            for (steps_val.array.items) |step_val| {
                const step_obj = switch (step_val) {
                    .object => |o| o,
                    else => continue,
                };
                const step = crypto_engine.PipelineStep.fromJson(step_obj) catch continue;
                try steps.append(alloc, step);
            }
        }
    }

    const result = crypto_engine.autoDecode(alloc, ciphertext, steps.items, .{
        .key = key,
        .max_depth = max_depth,
    }) catch {
        try respondJson(request, .internal_server_error, "{\"ok\":false,\"error\":\"AI decode failed\"}");
        return;
    };
    defer result.deinit(alloc);

    state.hist.addRecord(.{
        .operation = "decrypt",
        .pipeline_desc = result.description,
        .plaintext_hash = "",
        .ciphertext_preview = ciphertext[0..@min(ciphertext.len, 512)],
    }) catch {};

    var resp_buf: std.Io.Writer.Allocating = .init(alloc);
    const w = &resp_buf.writer;
    try w.writeAll("{\"ok\":true,\"plaintext\":");
    try utils.writeJsonString(w, result.plaintext);
    try w.writeAll(",\"pipeline_desc\":");
    try utils.writeJsonString(w, result.description);
    try w.writeAll(",\"attempts\":");
    try w.print("{d}", .{result.attempts});
    try w.writeAll(",\"still_encoded\":");
    try w.writeAll(if (result.still_encoded) "true" else "false");
    try w.writeAll(",\"steps\":[");
    for (result.steps, 0..) |step_type, i| {
        if (i > 0) try w.writeByte(',');
        try utils.writeJsonString(w, step_type.name());
    }
    try w.writeAll("]}");

    const resp = resp_buf.toOwnedSlice() catch return;
    defer alloc.free(resp);
    try respondJson(request, .ok, resp);
}

fn handlePuzzleSplit(alloc: std.mem.Allocator, state: *ServerState, request: *std.http.Server.Request) !void {
    _ = state;
    const body = try readBody(alloc, request);

    const parsed = std.json.parseFromSlice(std.json.Value, alloc, body, .{}) catch {
        try respondJson(request, .bad_request, "{\"ok\":false,\"error\":\"Invalid JSON\"}");
        return;
    };
    const root = parsed.value;

    const text = jsonStr(root, "text");
    const num_pieces: usize = if (root.object.get("pieces")) |v| switch (v) {
        .integer => |i| @intCast(@max(2, i)),
        else => 3,
    } else 3;

    if (text.len == 0) {
        try respondJson(request, .bad_request, "{\"ok\":false,\"error\":\"Missing 'text' field\"}");
        return;
    }

    const puzzle = @import("crypto/puzzle.zig");
    const pieces = puzzle.splitToBase64(alloc, text, num_pieces) catch {
        try respondJson(request, .internal_server_error, "{\"ok\":false,\"error\":\"Split failed\"}");
        return;
    };

    var resp_buf: std.Io.Writer.Allocating = .init(alloc);
    const w = &resp_buf.writer;
    try w.writeAll("{\"ok\":true,\"pieces\":[");
    for (pieces, 0..) |piece, i| {
        if (i > 0) try w.writeByte(',');
        try utils.writeJsonString(w, piece);
    }
    try w.writeAll("]}");

    const resp = resp_buf.toOwnedSlice() catch return;
    defer alloc.free(resp);
    try respondJson(request, .ok, resp);
}

fn handlePuzzleMerge(alloc: std.mem.Allocator, state: *ServerState, request: *std.http.Server.Request) !void {
    _ = state;
    const body = try readBody(alloc, request);

    const parsed = std.json.parseFromSlice(std.json.Value, alloc, body, .{}) catch {
        try respondJson(request, .bad_request, "{\"ok\":false,\"error\":\"Invalid JSON\"}");
        return;
    };
    const root = parsed.value;

    const pieces_val = root.object.get("pieces") orelse {
        try respondJson(request, .bad_request, "{\"ok\":false,\"error\":\"Missing 'pieces' field\"}");
        return;
    };

    const pieces_array = switch (pieces_val) {
        .array => |a| a,
        else => {
            try respondJson(request, .bad_request, "{\"ok\":false,\"error\":\"'pieces' must be an array\"}");
            return;
        },
    };

    var pieces: std.ArrayListUnmanaged([]const u8) = .empty;
    defer pieces.deinit(alloc);

    for (pieces_array.items) |item| {
        switch (item) {
            .string => |s| try pieces.append(alloc, s),
            else => {},
        }
    }

    const puzzle = @import("crypto/puzzle.zig");
    const merged = puzzle.mergeFromBase64(alloc, pieces.items) catch {
        try respondJson(request, .internal_server_error, "{\"ok\":false,\"error\":\"Merge failed\"}");
        return;
    };
    defer alloc.free(merged);

    var resp_buf: std.Io.Writer.Allocating = .init(alloc);
    const w = &resp_buf.writer;
    try w.writeAll("{\"ok\":true,\"text\":");
    try utils.writeJsonString(w, merged);
    try w.writeAll("}");

    const resp = resp_buf.toOwnedSlice() catch return;
    defer alloc.free(resp);
    try respondJson(request, .ok, resp);
}

fn handleGenerate(alloc: std.mem.Allocator, state: *ServerState, request: *std.http.Server.Request) !void {
    const body = try readBody(alloc, request);

    const parsed = std.json.parseFromSlice(std.json.Value, alloc, body, .{}) catch {
        try respondJson(request, .bad_request, "{\"ok\":false,\"error\":\"Invalid JSON\"}");
        return;
    };
    const root = parsed.value;

    const template = jsonStr(root, "template");
    if (template.len == 0) {
        try respondJson(request, .bad_request, "{\"ok\":false,\"error\":\"Missing 'template' field\"}");
        return;
    }

    const result = gen.generateWithTemplateData(alloc, template, &state.template_data) catch {
        try respondJson(request, .internal_server_error, "{\"ok\":false,\"error\":\"Generation failed\"}");
        return;
    };
    defer alloc.free(result);

    var resp_buf: std.Io.Writer.Allocating = .init(alloc);
    const w = &resp_buf.writer;
    try w.writeAll("{\"ok\":true,\"text\":");
    try utils.writeJsonString(w, result);
    try w.writeAll("}");

    const resp = resp_buf.toOwnedSlice() catch return;
    defer alloc.free(resp);
    try respondJson(request, .ok, resp);
}

fn handleGetHistory(alloc: std.mem.Allocator, state: *ServerState, request: *std.http.Server.Request) !void {
    const records = state.hist.getAll(alloc) catch {
        try respondJson(request, .internal_server_error, "{\"ok\":false,\"error\":\"Failed to load history\"}");
        return;
    };

    var resp_buf: std.Io.Writer.Allocating = .init(alloc);
    const w = &resp_buf.writer;
    try w.writeAll("{\"ok\":true,\"records\":[");

    for (records, 0..) |rec, i| {
        if (i > 0) try w.writeByte(',');
        try w.writeAll("{\"id\":");
        try utils.writeJsonString(w, rec.id);
        try w.writeAll(",\"operation\":");
        try utils.writeJsonString(w, rec.operation);
        try w.writeAll(",\"pipeline_desc\":");
        try utils.writeJsonString(w, rec.pipeline_desc);
        try w.writeAll(",\"timestamp\":");
        try utils.writeJsonString(w, rec.timestamp);
        try w.writeAll(",\"ciphertext_preview\":");
        try utils.writeJsonString(w, rec.ciphertext_preview);
        try w.writeByte('}');
    }

    try w.writeAll("]}");

    const resp = resp_buf.toOwnedSlice() catch return;
    defer alloc.free(resp);
    try respondJson(request, .ok, resp);
}

fn handleDeleteHistory(alloc: std.mem.Allocator, state: *ServerState, request: *std.http.Server.Request, path: []const u8) !void {
    _ = alloc;
    const prefix = "/api/history/";
    if (path.len <= prefix.len) {
        try respondJson(request, .bad_request, "{\"ok\":false,\"error\":\"Missing history ID\"}");
        return;
    }
    const id = path[prefix.len..];

    state.hist.deleteRecord(id) catch {
        try respondJson(request, .not_found, "{\"ok\":false,\"error\":\"Record not found\"}");
        return;
    };

    try respondJson(request, .ok, "{\"ok\":true}");
}

fn handleClearHistory(alloc: std.mem.Allocator, state: *ServerState, request: *std.http.Server.Request) !void {
    _ = alloc;
    state.hist.clearAll() catch {
        try respondJson(request, .internal_server_error, "{\"ok\":false,\"error\":\"Failed to clear history\"}");
        return;
    };
    try respondJson(request, .ok, "{\"ok\":true}");
}

fn handleGetSettings(request: *std.http.Server.Request) !void {
    try respondJson(request, .ok, "{\"ok\":true,\"settings\":{\"theme\":\"auto\",\"language\":\"auto\"}}");
}

fn handleGetTemplateData(alloc: std.mem.Allocator, state: *ServerState, request: *std.http.Server.Request) !void {
    const json = state.template_data.toJson(alloc) catch {
        try respondJson(request, .internal_server_error, "{\"ok\":false,\"error\":\"Failed to encode template data\"}");
        return;
    };
    defer alloc.free(json);

    var resp_buf: std.Io.Writer.Allocating = .init(alloc);
    const w = &resp_buf.writer;
    try w.writeAll("{\"ok\":true,\"data\":");
    try w.writeAll(json);
    try w.writeByte('}');

    const resp = resp_buf.toOwnedSlice() catch return;
    defer alloc.free(resp);
    try respondJson(request, .ok, resp);
}

fn handleUpdateTemplateData(alloc: std.mem.Allocator, state: *ServerState, request: *std.http.Server.Request) !void {
    const body = try readBody(alloc, request);
    var new_data = wordbank_mod.TemplateData.fromJson(state.allocator, body) catch {
        try respondJson(request, .bad_request, "{\"ok\":false,\"error\":\"Invalid template data\"}");
        return;
    };
    var committed = false;
    defer if (!committed) new_data.deinit();

    const json = new_data.toJson(alloc) catch {
        try respondJson(request, .internal_server_error, "{\"ok\":false,\"error\":\"Failed to save template data\"}");
        return;
    };
    defer alloc.free(json);

    try state_mutex.lock(state.io);
    defer state_mutex.unlock(state.io);

    try state.database.put("settings:template_data", json);
    state.template_data.deinit();
    state.template_data = new_data;
    committed = true;

    try respondJson(request, .ok, "{\"ok\":true}");
}

fn handleResetTemplateData(state: *ServerState, request: *std.http.Server.Request) !void {
    try state_mutex.lock(state.io);
    defer state_mutex.unlock(state.io);

    state.template_data.resetToDefaults() catch {
        try respondJson(request, .internal_server_error, "{\"ok\":false,\"error\":\"Failed to reset template data\"}");
        return;
    };
    state.database.delete("settings:template_data") catch {};

    try respondJson(request, .ok, "{\"ok\":true}");
}

fn handleUpdateSettings(alloc: std.mem.Allocator, state: *ServerState, request: *std.http.Server.Request) !void {
    const body = try readBody(alloc, request);
    const parsed = std.json.parseFromSlice(std.json.Value, alloc, body, .{}) catch {
        try respondJson(request, .ok, "{\"ok\":true}");
        return;
    };
    const root = parsed.value;

    try state_mutex.lock(state.io);
    defer state_mutex.unlock(state.io);

    if (root.object.get("ai_provider")) |v| {
        if (v == .string) state.ai_provider = try state.allocator.dupe(u8, v.string);
    }
    if (root.object.get("ai_endpoint")) |v| {
        if (v == .string) state.ai_endpoint = try state.allocator.dupe(u8, v.string);
    }
    if (root.object.get("ai_key")) |v| {
        if (v == .string) state.ai_key = try state.allocator.dupe(u8, v.string);
    }
    if (root.object.get("ai_model")) |v| {
        if (v == .string) state.ai_model = try state.allocator.dupe(u8, v.string);
    }

    try respondJson(request, .ok, "{\"ok\":true}");
}

fn handleAiChat(alloc: std.mem.Allocator, state: *ServerState, request: *std.http.Server.Request) !void {
    const body = try readBody(alloc, request);
    const parsed = std.json.parseFromSlice(std.json.Value, alloc, body, .{}) catch {
        try respondJson(request, .bad_request, "{\"ok\":false,\"error\":\"Invalid JSON\"}");
        return;
    };
    const root = parsed.value;

    const message = jsonStr(root, "message");
    if (message.len == 0) {
        try respondJson(request, .bad_request, "{\"ok\":false,\"error\":\"Missing 'message'\"}");
        return;
    }

    // Read AI config from request body (client sends its local config)
    const provider_str = if (root.object.get("provider")) |v| switch (v) {
        .string => |s| s,
        else => state.ai_provider,
    } else state.ai_provider;
    const endpoint = if (root.object.get("endpoint")) |v| switch (v) {
        .string => |s| if (s.len > 0) s else state.ai_endpoint,
        else => state.ai_endpoint,
    } else state.ai_endpoint;
    const api_key = if (root.object.get("key")) |v| switch (v) {
        .string => |s| if (s.len > 0) s else state.ai_key,
        else => state.ai_key,
    } else state.ai_key;
    const model = if (root.object.get("model")) |v| switch (v) {
        .string => |s| if (s.len > 0) s else state.ai_model,
        else => state.ai_model,
    } else state.ai_model;
    const system_prompt = if (root.object.get("system_prompt")) |v| switch (v) {
        .string => |s| s,
        else => "You are VeilText AI, a helpful assistant.",
    } else "You are VeilText AI, a helpful assistant.";

    if (api_key.len == 0) {
        try respondJson(request, .bad_request, "{\"ok\":false,\"error\":\"No API key configured\"}");
        return;
    }

    const provider = ai_mod.AiProvider.fromString(provider_str) orelse .openai;

    // Choose endpoint fallback based on provider
    const eff_endpoint = if (endpoint.len > 0) endpoint else switch (provider) {
        .openai => config.default_openai_endpoint,
        .claude => config.default_claude_endpoint,
    };

    const ai_cfg = ai_mod.AiConfig{
        .provider = provider,
        .endpoint = eff_endpoint,
        .api_key = api_key,
        .model = if (model.len > 0) model else switch (provider) {
            .openai => "gpt-4o-mini",
            .claude => "claude-haiku-4-5-20251001",
        },
        .max_tokens = 1024,
    };

    var transcript: std.Io.Writer.Allocating = .init(alloc);
    defer transcript.deinit();
    const tw = &transcript.writer;
    try tw.writeAll("User request:\n");
    try tw.writeAll(message);

    var action_jsons: std.ArrayListUnmanaged([]u8) = .empty;
    defer {
        for (action_jsons.items) |item| alloc.free(item);
        action_jsons.deinit(alloc);
    }

    var final_reply: ?[]u8 = null;
    defer if (final_reply) |reply| alloc.free(reply);

    var round: usize = 0;
    while (round < 4) : (round += 1) {
        const tool_prompt = try buildAiToolSystemPrompt(alloc, system_prompt);
        defer alloc.free(tool_prompt);

        const gen_result = ai_mod.generate(alloc, ai_cfg, .{
            .prompt = transcript.written(),
            .system_prompt = tool_prompt,
        }) catch |err| {
            var err_buf: [128]u8 = undefined;
            const err_msg = std.fmt.bufPrint(&err_buf, "{{\"ok\":false,\"error\":\"{s}\"}}", .{@errorName(err)}) catch "{\"ok\":false,\"error\":\"AI call failed\"}";
            try respondJson(request, .internal_server_error, err_msg);
            return;
        };
        defer gen_result.deinit(alloc);

        // If the API returned an error message (non-200 status), forward it to client
        if (gen_result.is_error) {
            var err_resp_buf: std.Io.Writer.Allocating = .init(alloc);
            const ew = &err_resp_buf.writer;
            try ew.writeAll("{\"ok\":false,\"error\":");
            try utils.writeJsonString(ew, gen_result.text);
            try ew.writeAll("}");
            const err_resp = err_resp_buf.toOwnedSlice() catch return;
            defer alloc.free(err_resp);
            try respondJson(request, .internal_server_error, err_resp);
            return;
        }

        const raw = gen_result.text;

        const trimmed_raw = std.mem.trim(u8, raw, " \r\n\t");
        const json_slice = extractJsonPayload(trimmed_raw) orelse {
            final_reply = try alloc.dupe(u8, trimmed_raw);
            break;
        };

        const ai_parsed = std.json.parseFromSlice(std.json.Value, alloc, json_slice, .{}) catch {
            final_reply = try alloc.dupe(u8, trimmed_raw);
            break;
        };
        defer ai_parsed.deinit();

        const ai_root = switch (ai_parsed.value) {
            .object => |obj| obj,
            else => {
                final_reply = try alloc.dupe(u8, trimmed_raw);
                break;
            },
        };

        const reply_type = objStr(ai_root, "type");
        if (std.mem.eql(u8, reply_type, "tool")) {
            const tool_name = objStr(ai_root, "name");
            const args_obj = if (ai_root.get("args")) |v| switch (v) {
                .object => |obj| obj,
                else => null,
            } else null;

            if (tool_name.len == 0) {
                final_reply = try alloc.dupe(u8, trimmed_raw);
                break;
            }

            const tool_result = executeAiTool(alloc, state, tool_name, args_obj, &action_jsons) catch |err| {
                final_reply = try std.fmt.allocPrint(alloc, "Tool {s} failed: {s}", .{ tool_name, @errorName(err) });
                break;
            };
            defer alloc.free(tool_result);

            try tw.writeAll("\n\nTool result:\n");
            try tw.writeAll(tool_result);
            continue;
        }

        const reply_text = objStr(ai_root, "reply");
        final_reply = try alloc.dupe(u8, if (reply_text.len > 0) reply_text else trimmed_raw);
        break;
    }

    if (final_reply == null) {
        final_reply = try alloc.dupe(u8, "I could not complete the request.");
    }

    var resp_buf: std.Io.Writer.Allocating = .init(alloc);
    const w = &resp_buf.writer;
    try w.writeAll("{\"ok\":true,\"reply\":");
    try utils.writeJsonString(w, final_reply.?);
    try w.writeAll(",\"actions\":[");
    for (action_jsons.items, 0..) |action_json, idx| {
        if (idx > 0) try w.writeByte(',');
        try w.writeAll(action_json);
    }
    try w.writeAll("]}");

    const resp = resp_buf.toOwnedSlice() catch return;
    defer alloc.free(resp);
    try respondJson(request, .ok, resp);
}

fn buildAiToolSystemPrompt(alloc: std.mem.Allocator, mode_prompt: []const u8) ![]u8 {
    const base =
        \\You are VeilText AI. You may call tools and then continue reasoning.
        \\Return ONLY minified JSON. Never use markdown fences.
        \\
        \\Tool request format:
        \\{"type":"tool","name":"encrypt","args":{"text":"hello","algorithm":"base64","key":""}}
        \\
        \\Final response format:
        \\{"type":"final","reply":"Your concise answer to the user."}
        \\
        \\Allowed tools:
        \\- encrypt args: text, algorithm, key
        \\- decrypt args: text, algorithm, key
        \\- generate args: template
        \\- puzzle_split args: text, pieces
        \\- puzzle_merge args: pieces
        \\- web_search args: query, limit
        \\- get_time args: timezone
        \\- system_info args: none
        \\
        \\Supported algorithms: base16, base32, base58, base64, base85, aes_256_gcm, chacha20_poly1305, xchacha20_poly1305, aes_256_cbc, bf_text, bf_emoji, js_hex_escape, js_unicode_escape, js_binary_string, js_jjencode, js_aaencode, js_jsfuck, js_eval_wrap, js_constructor_wrap, js_base36_tostring.
        \\If a tool is required, request exactly one tool at a time.
        \\When enough information is available, return a final response.
        \\
        \\Mode guidance:
    ;
    return std.fmt.allocPrint(alloc, "{s}\n{s}", .{ base, mode_prompt });
}

fn extractJsonPayload(text: []const u8) ?[]const u8 {
    var candidate = std.mem.trim(u8, text, " \r\n\t");
    if (std.mem.startsWith(u8, candidate, "```")) {
        if (std.mem.indexOfScalar(u8, candidate, '\n')) |first_nl| {
            candidate = candidate[first_nl + 1 ..];
        }
        if (std.mem.lastIndexOf(u8, candidate, "```")) |last_tick| {
            candidate = candidate[0..last_tick];
        }
        candidate = std.mem.trim(u8, candidate, " \r\n\t");
    }
    const json_start = std.mem.indexOfScalar(u8, candidate, '{') orelse return null;
    const json_end = std.mem.lastIndexOfScalar(u8, candidate, '}') orelse return null;
    if (json_end < json_start) return null;
    return candidate[json_start .. json_end + 1];
}

fn executeAiTool(
    alloc: std.mem.Allocator,
    state: *ServerState,
    tool_name: []const u8,
    args_obj: ?std.json.ObjectMap,
    action_jsons: *std.ArrayListUnmanaged([]u8),
) ![]u8 {
    if (std.mem.eql(u8, tool_name, "encrypt")) {
        const text = objStrOpt(args_obj, "text");
        const algorithm = objStrOpt(args_obj, "algorithm");
        const key = objStrOpt(args_obj, "key");
        if (text.len == 0 or algorithm.len == 0) return error.InvalidToolArgs;

        const step_type = crypto_engine.StepType.fromString(algorithm) orelse return error.UnknownStepType;
        const steps = [_]crypto_engine.PipelineStep{.{ .step_type = step_type, .key = key }};
        const result = try crypto_engine.executePipeline(alloc, text, &steps);
        defer alloc.free(result.ciphertext);
        defer alloc.free(result.description);

        const action = try buildFillEncryptActionJson(alloc, text, stepTypeId(step_type), key, result.ciphertext);
        try action_jsons.append(alloc, action);
        return buildEncryptToolResultJson(alloc, stepTypeId(step_type), result.ciphertext);
    }

    if (std.mem.eql(u8, tool_name, "decrypt")) {
        const text = objStrOpt(args_obj, "text");
        const algorithm = objStrOpt(args_obj, "algorithm");
        const key = objStrOpt(args_obj, "key");
        if (text.len == 0 or algorithm.len == 0) return error.InvalidToolArgs;

        const step_type = crypto_engine.StepType.fromString(algorithm) orelse return error.UnknownStepType;
        const steps = [_]crypto_engine.PipelineStep{.{ .step_type = step_type, .key = key }};
        const result = try crypto_engine.executeReversePipeline(alloc, text, &steps);
        defer alloc.free(result.ciphertext);
        defer alloc.free(result.description);

        const action = try buildFillDecryptActionJson(alloc, text, stepTypeId(step_type), key, result.ciphertext);
        try action_jsons.append(alloc, action);
        return buildDecryptToolResultJson(alloc, stepTypeId(step_type), result.ciphertext);
    }

    if (std.mem.eql(u8, tool_name, "generate")) {
        const template = objStrOpt(args_obj, "template");
        if (template.len == 0) return error.InvalidToolArgs;

        const result = try gen.generateWithTemplateData(alloc, template, &state.template_data);
        defer alloc.free(result);

        const action = try buildFillGenerateActionJson(alloc, template, result);
        try action_jsons.append(alloc, action);
        return buildGenerateToolResultJson(alloc, template, result);
    }

    if (std.mem.eql(u8, tool_name, "puzzle_split")) {
        const text = objStrOpt(args_obj, "text");
        if (text.len == 0) return error.InvalidToolArgs;

        const piece_count = clampInt(objIntOpt(args_obj, "pieces", 3), 2, 10);
        const pieces = try crypto_base64PuzzleSplit(alloc, text, @intCast(piece_count));
        defer freeStringSliceArray(alloc, pieces);

        const action = try buildFillPuzzleSplitActionJson(alloc, text, piece_count, pieces);
        try action_jsons.append(alloc, action);
        return buildPuzzleSplitToolResultJson(alloc, piece_count, pieces);
    }

    if (std.mem.eql(u8, tool_name, "puzzle_merge")) {
        var pieces = try readPieceArgs(alloc, args_obj);
        defer pieces.deinit(alloc);

        const merged = try @import("crypto/puzzle.zig").mergeFromBase64(alloc, pieces.items);
        defer alloc.free(merged);

        const action = try buildFillPuzzleMergeActionJson(alloc, merged);
        try action_jsons.append(alloc, action);
        return buildPuzzleMergeToolResultJson(alloc, merged);
    }

    if (std.mem.eql(u8, tool_name, "web_search")) {
        const query = objStrOpt(args_obj, "query");
        if (query.len == 0) return error.InvalidToolArgs;
        const limit = clampInt(objIntOpt(args_obj, "limit", 5), 1, 5);
        return buildWebSearchToolResultJson(alloc, query, @intCast(limit));
    }

    if (std.mem.eql(u8, tool_name, "get_time")) {
        return buildTimeToolResultJson(alloc, objStrOpt(args_obj, "timezone"));
    }

    if (std.mem.eql(u8, tool_name, "system_info")) {
        return buildSystemInfoToolResultJson(alloc, state);
    }

    return error.UnknownTool;
}

fn crypto_base64PuzzleSplit(alloc: std.mem.Allocator, text: []const u8, pieces: usize) ![][]u8 {
    return @import("crypto/puzzle.zig").splitToBase64(alloc, text, pieces);
}

fn readPieceArgs(alloc: std.mem.Allocator, args_obj: ?std.json.ObjectMap) !std.ArrayListUnmanaged([]const u8) {
    var pieces: std.ArrayListUnmanaged([]const u8) = .empty;
    errdefer pieces.deinit(alloc);

    const obj = args_obj orelse return error.InvalidToolArgs;
    const value = obj.get("pieces") orelse return error.InvalidToolArgs;
    const items = switch (value) {
        .array => |arr| arr.items,
        else => return error.InvalidToolArgs,
    };

    for (items) |item| {
        switch (item) {
            .string => |s| try pieces.append(alloc, s),
            else => return error.InvalidToolArgs,
        }
    }

    if (pieces.items.len == 0) return error.InvalidToolArgs;
    return pieces;
}

fn buildFillEncryptActionJson(alloc: std.mem.Allocator, text: []const u8, algorithm: []const u8, key: []const u8, result: []const u8) ![]u8 {
    return buildActionWithResultJson(alloc, "fill_encrypt", text, algorithm, key, result);
}

fn buildFillDecryptActionJson(alloc: std.mem.Allocator, text: []const u8, algorithm: []const u8, key: []const u8, result: []const u8) ![]u8 {
    return buildActionWithResultJson(alloc, "fill_decrypt", text, algorithm, key, result);
}

fn buildActionWithResultJson(alloc: std.mem.Allocator, action_type: []const u8, text: []const u8, algorithm: []const u8, key: []const u8, result: []const u8) ![]u8 {
    var buf: std.Io.Writer.Allocating = .init(alloc);
    const w = &buf.writer;
    try w.writeAll("{\"type\":");
    try utils.writeJsonString(w, action_type);
    try w.writeAll(",\"text\":");
    try utils.writeJsonString(w, text);
    try w.writeAll(",\"algorithm\":");
    try utils.writeJsonString(w, algorithm);
    try w.writeAll(",\"key\":");
    try utils.writeJsonString(w, key);
    try w.writeAll(",\"result\":");
    try utils.writeJsonString(w, result);
    try w.writeByte('}');
    return buf.toOwnedSlice();
}

fn buildFillGenerateActionJson(alloc: std.mem.Allocator, template: []const u8, result: []const u8) ![]u8 {
    var buf: std.Io.Writer.Allocating = .init(alloc);
    const w = &buf.writer;
    try w.writeAll("{\"type\":\"fill_generate\",\"template\":");
    try utils.writeJsonString(w, template);
    try w.writeAll(",\"result\":");
    try utils.writeJsonString(w, result);
    try w.writeByte('}');
    return buf.toOwnedSlice();
}

fn buildFillPuzzleSplitActionJson(alloc: std.mem.Allocator, text: []const u8, piece_count: i64, pieces: []const []const u8) ![]u8 {
    var buf: std.Io.Writer.Allocating = .init(alloc);
    const w = &buf.writer;
    try w.writeAll("{\"type\":\"fill_puzzle_split\",\"text\":");
    try utils.writeJsonString(w, text);
    try w.writeAll(",\"pieces_count\":");
    try w.print("{d}", .{piece_count});
    try w.writeAll(",\"pieces\":");
    try writeJsonStringArray(w, pieces);
    try w.writeByte('}');
    return buf.toOwnedSlice();
}

fn buildFillPuzzleMergeActionJson(alloc: std.mem.Allocator, result: []const u8) ![]u8 {
    var buf: std.Io.Writer.Allocating = .init(alloc);
    const w = &buf.writer;
    try w.writeAll("{\"type\":\"fill_puzzle_merge\",\"result\":");
    try utils.writeJsonString(w, result);
    try w.writeByte('}');
    return buf.toOwnedSlice();
}

fn buildEncryptToolResultJson(alloc: std.mem.Allocator, algorithm: []const u8, result: []const u8) ![]u8 {
    return buildNamedResultJson(alloc, "encrypt", algorithm, result);
}

fn buildDecryptToolResultJson(alloc: std.mem.Allocator, algorithm: []const u8, result: []const u8) ![]u8 {
    return buildNamedResultJson(alloc, "decrypt", algorithm, result);
}

fn buildGenerateToolResultJson(alloc: std.mem.Allocator, template: []const u8, result: []const u8) ![]u8 {
    var buf: std.Io.Writer.Allocating = .init(alloc);
    const w = &buf.writer;
    try w.writeAll("{\"tool\":\"generate\",\"template\":");
    try utils.writeJsonString(w, template);
    try w.writeAll(",\"result\":");
    try utils.writeJsonString(w, result);
    try w.writeByte('}');
    return buf.toOwnedSlice();
}

fn buildPuzzleSplitToolResultJson(alloc: std.mem.Allocator, piece_count: i64, pieces: []const []const u8) ![]u8 {
    var buf: std.Io.Writer.Allocating = .init(alloc);
    const w = &buf.writer;
    try w.writeAll("{\"tool\":\"puzzle_split\",\"pieces_count\":");
    try w.print("{d}", .{piece_count});
    try w.writeAll(",\"pieces\":");
    try writeJsonStringArray(w, pieces);
    try w.writeByte('}');
    return buf.toOwnedSlice();
}

fn buildPuzzleMergeToolResultJson(alloc: std.mem.Allocator, result: []const u8) ![]u8 {
    var buf: std.Io.Writer.Allocating = .init(alloc);
    const w = &buf.writer;
    try w.writeAll("{\"tool\":\"puzzle_merge\",\"result\":");
    try utils.writeJsonString(w, result);
    try w.writeByte('}');
    return buf.toOwnedSlice();
}

fn buildNamedResultJson(alloc: std.mem.Allocator, tool_name: []const u8, algorithm: []const u8, result: []const u8) ![]u8 {
    var buf: std.Io.Writer.Allocating = .init(alloc);
    const w = &buf.writer;
    try w.writeAll("{\"tool\":");
    try utils.writeJsonString(w, tool_name);
    try w.writeAll(",\"algorithm\":");
    try utils.writeJsonString(w, algorithm);
    try w.writeAll(",\"result\":");
    try utils.writeJsonString(w, result);
    try w.writeByte('}');
    return buf.toOwnedSlice();
}

fn buildWebSearchToolResultJson(alloc: std.mem.Allocator, query: []const u8, limit: usize) ![]u8 {
    const encoded_query = try urlEncode(alloc, query);
    defer alloc.free(encoded_query);

    const url = try std.fmt.allocPrint(alloc, "https://html.duckduckgo.com/html/?q={s}", .{encoded_query});
    defer alloc.free(url);

    const html = try news_mod.httpGet(alloc, url);
    defer alloc.free(html);

    var buf: std.Io.Writer.Allocating = .init(alloc);
    const w = &buf.writer;
    try w.writeAll("{\"tool\":\"web_search\",\"query\":");
    try utils.writeJsonString(w, query);
    try w.writeAll(",\"results\":[");

    var cursor: usize = 0;
    var count: usize = 0;
    while (count < limit) {
        const marker = std.mem.indexOfPos(u8, html, cursor, "result__a") orelse break;
        const href_idx = std.mem.indexOfPos(u8, html, marker, "href=\"") orelse break;
        const href_start = href_idx + 6;
        const href_end = std.mem.indexOfScalarPos(u8, html, href_start, '"') orelse break;
        const title_start = std.mem.indexOfScalarPos(u8, html, href_end, '>') orelse break;
        const title_end = std.mem.indexOfPos(u8, html, title_start + 1, "</a>") orelse break;

        const title = try htmlDecodeBasic(alloc, html[title_start + 1 .. title_end]);
        defer alloc.free(title);
        const cleaned_url = try normalizeSearchUrl(alloc, html[href_start..href_end]);
        defer alloc.free(cleaned_url);

        if (count > 0) try w.writeByte(',');
        try w.writeAll("{\"title\":");
        try utils.writeJsonString(w, title);
        try w.writeAll(",\"url\":");
        try utils.writeJsonString(w, cleaned_url);
        try w.writeByte('}');

        count += 1;
        cursor = title_end + 4;
    }

    try w.writeAll("]}");
    return buf.toOwnedSlice();
}

fn buildTimeToolResultJson(alloc: std.mem.Allocator, timezone_raw: []const u8) ![]u8 {
    const timezone = if (std.mem.trim(u8, timezone_raw, " \r\n\t").len > 0) std.mem.trim(u8, timezone_raw, " \r\n\t") else "UTC";
    const offset_minutes = try parseTimezoneOffsetMinutes(timezone);
    const shifted = compat.timestamp() + @as(i64, offset_minutes) * 60;

    var ts_buf: [19]u8 = undefined;
    const formatted = utils.formatTimestamp(&ts_buf, shifted);

    var buf: std.Io.Writer.Allocating = .init(alloc);
    const w = &buf.writer;
    try w.writeAll("{\"tool\":\"get_time\",\"timezone\":");
    try utils.writeJsonString(w, timezone);
    try w.writeAll(",\"timestamp\":");
    try w.print("{d}", .{shifted});
    try w.writeAll(",\"formatted\":");
    try utils.writeJsonString(w, formatted);
    try w.writeByte('}');
    return buf.toOwnedSlice();
}

fn buildSystemInfoToolResultJson(alloc: std.mem.Allocator, state: *ServerState) ![]u8 {
    const host_env = if (builtin.os.tag == .windows) "COMPUTERNAME" else "HOSTNAME";
    const hostname = state.environ_map.get(host_env) orelse "";

    var buf: std.Io.Writer.Allocating = .init(alloc);
    const w = &buf.writer;
    try w.writeAll("{\"tool\":\"system_info\",\"app\":\"");
    try w.writeAll(config.app_name);
    try w.writeAll("\",\"version\":\"");
    try w.writeAll(config.app_version);
    try w.writeAll("\",\"os\":\"");
    try w.writeAll(@tagName(builtin.os.tag));
    try w.writeAll("\",\"arch\":\"");
    try w.writeAll(@tagName(builtin.cpu.arch));
    try w.writeAll("\",\"bind_host\":");
    try utils.writeJsonString(w, state.cfg.bind_host);
    try w.writeAll(",\"port\":");
    try w.print("{d}", .{state.cfg.port});
    try w.writeAll(",\"hostname\":");
    try utils.writeJsonString(w, hostname);
    try w.writeByte('}');
    return buf.toOwnedSlice();
}

fn parseTimezoneOffsetMinutes(timezone: []const u8) !i32 {
    if (std.ascii.eqlIgnoreCase(timezone, "UTC") or std.ascii.eqlIgnoreCase(timezone, "Z")) return 0;

    var raw = timezone;
    if (raw.len >= 3 and std.ascii.eqlIgnoreCase(raw[0..3], "UTC")) {
        raw = raw[3..];
        if (raw.len == 0) return 0;
    }

    const sign: i32 = switch (raw[0]) {
        '+' => 1,
        '-' => -1,
        else => return error.InvalidTimezone,
    };
    const remainder = raw[1..];

    var hours: i32 = 0;
    var minutes: i32 = 0;
    if (std.mem.indexOfScalar(u8, remainder, ':')) |sep| {
        hours = try std.fmt.parseInt(i32, remainder[0..sep], 10);
        minutes = try std.fmt.parseInt(i32, remainder[sep + 1 ..], 10);
    } else if (remainder.len == 1 or remainder.len == 2) {
        hours = try std.fmt.parseInt(i32, remainder, 10);
    } else if (remainder.len == 4) {
        hours = try std.fmt.parseInt(i32, remainder[0..2], 10);
        minutes = try std.fmt.parseInt(i32, remainder[2..4], 10);
    } else {
        return error.InvalidTimezone;
    }

    return sign * (hours * 60 + minutes);
}

fn urlEncode(alloc: std.mem.Allocator, input: []const u8) ![]u8 {
    var buf: std.Io.Writer.Allocating = .init(alloc);
    const w = &buf.writer;
    for (input) |c| {
        if ((c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9') or c == '-' or c == '_' or c == '.' or c == '~') {
            try w.writeByte(c);
        } else if (c == ' ') {
            try w.writeByte('+');
        } else {
            try w.print("%{X:0>2}", .{c});
        }
    }
    return buf.toOwnedSlice();
}

fn normalizeSearchUrl(alloc: std.mem.Allocator, raw_url: []const u8) ![]u8 {
    const decoded_html = try htmlDecodeBasic(alloc, raw_url);
    defer alloc.free(decoded_html);

    if (std.mem.indexOf(u8, decoded_html, "uddg=")) |idx| {
        const encoded = decoded_html[idx + 5 ..];
        const end = std.mem.indexOfScalar(u8, encoded, '&') orelse encoded.len;
        return percentDecode(alloc, encoded[0..end]);
    }
    if (std.mem.startsWith(u8, decoded_html, "//")) {
        return std.fmt.allocPrint(alloc, "https:{s}", .{decoded_html});
    }
    return alloc.dupe(u8, decoded_html);
}

fn htmlDecodeBasic(alloc: std.mem.Allocator, input: []const u8) ![]u8 {
    var buf: std.Io.Writer.Allocating = .init(alloc);
    const w = &buf.writer;
    var i: usize = 0;
    while (i < input.len) {
        if (std.mem.startsWith(u8, input[i..], "&amp;")) {
            try w.writeByte('&');
            i += 5;
        } else if (std.mem.startsWith(u8, input[i..], "&quot;")) {
            try w.writeByte('"');
            i += 6;
        } else if (std.mem.startsWith(u8, input[i..], "&#39;")) {
            try w.writeByte('\'');
            i += 5;
        } else if (std.mem.startsWith(u8, input[i..], "&lt;")) {
            try w.writeByte('<');
            i += 4;
        } else if (std.mem.startsWith(u8, input[i..], "&gt;")) {
            try w.writeByte('>');
            i += 4;
        } else {
            try w.writeByte(input[i]);
            i += 1;
        }
    }
    return buf.toOwnedSlice();
}

fn percentDecode(alloc: std.mem.Allocator, input: []const u8) ![]u8 {
    var buf: std.Io.Writer.Allocating = .init(alloc);
    const w = &buf.writer;
    var i: usize = 0;
    while (i < input.len) {
        if (input[i] == '%' and i + 2 < input.len) {
            const hi = hexNibble(input[i + 1]) orelse return error.InvalidPercentEncoding;
            const lo = hexNibble(input[i + 2]) orelse return error.InvalidPercentEncoding;
            try w.writeByte((hi << 4) | lo);
            i += 3;
        } else if (input[i] == '+') {
            try w.writeByte(' ');
            i += 1;
        } else {
            try w.writeByte(input[i]);
            i += 1;
        }
    }
    return buf.toOwnedSlice();
}

fn hexNibble(c: u8) ?u8 {
    return switch (c) {
        '0'...'9' => c - '0',
        'a'...'f' => c - 'a' + 10,
        'A'...'F' => c - 'A' + 10,
        else => null,
    };
}

fn freeStringSliceArray(alloc: std.mem.Allocator, items: [][]u8) void {
    for (items) |item| alloc.free(item);
    alloc.free(items);
}

fn writeJsonStringArray(writer: *std.Io.Writer, items: []const []const u8) !void {
    try writer.writeByte('[');
    for (items, 0..) |item, idx| {
        if (idx > 0) try writer.writeByte(',');
        try utils.writeJsonString(writer, item);
    }
    try writer.writeByte(']');
}

fn stepTypeId(step_type: crypto_engine.StepType) []const u8 {
    return switch (step_type) {
        .base16 => "base16",
        .base32 => "base32",
        .base58 => "base58",
        .base64 => "base64",
        .base85 => "base85",
        .aes_256_gcm => "aes_256_gcm",
        .chacha20_poly1305 => "chacha20_poly1305",
        .xchacha20_poly1305 => "xchacha20_poly1305",
        .aes_256_cbc => "aes_256_cbc",
        .hash_sha256 => "sha256",
        .hash_sha512 => "sha512",
        .hash_blake3 => "blake3",
        .hash_md5 => "md5",
        .js_hex_escape => "js_hex_escape",
        .js_unicode_escape => "js_unicode_escape",
        .js_binary_string => "js_binary_string",
        .js_jjencode => "js_jjencode",
        .js_aaencode => "js_aaencode",
        .js_jsfuck => "js_jsfuck",
        .js_eval_wrap => "js_eval_wrap",
        .js_constructor_wrap => "js_constructor_wrap",
        .js_base36_tostring => "js_base36_tostring",
        .bf_text => "bf_text",
        .bf_emoji => "bf_emoji",
    };
}

fn objStr(obj: std.json.ObjectMap, key: []const u8) []const u8 {
    if (obj.get(key)) |value| {
        return switch (value) {
            .string => |s| s,
            else => "",
        };
    }
    return "";
}

fn objStrOpt(obj: ?std.json.ObjectMap, key: []const u8) []const u8 {
    if (obj) |map| return objStr(map, key);
    return "";
}

fn objIntOpt(obj: ?std.json.ObjectMap, key: []const u8, fallback: i64) i64 {
    if (obj) |map| {
        if (map.get(key)) |value| {
            return switch (value) {
                .integer => |i| i,
                else => fallback,
            };
        }
    }
    return fallback;
}

fn clampInt(value: i64, min_value: i64, max_value: i64) i64 {
    return @max(min_value, @min(max_value, value));
}

fn handleAiTest(alloc: std.mem.Allocator, state: *ServerState, request: *std.http.Server.Request) !void {
    const body = try readBody(alloc, request);
    const parsed = std.json.parseFromSlice(std.json.Value, alloc, body, .{}) catch {
        try respondJson(request, .bad_request, "{\"ok\":false,\"error\":\"Invalid JSON\"}");
        return;
    };
    const root = parsed.value;

    const provider_str = if (root.object.get("provider")) |v| switch (v) {
        .string => |s| s,
        else => state.ai_provider,
    } else state.ai_provider;
    const endpoint = if (root.object.get("endpoint")) |v| switch (v) {
        .string => |s| if (s.len > 0) s else state.ai_endpoint,
        else => state.ai_endpoint,
    } else state.ai_endpoint;
    const api_key = if (root.object.get("key")) |v| switch (v) {
        .string => |s| if (s.len > 0) s else state.ai_key,
        else => state.ai_key,
    } else state.ai_key;
    const model = if (root.object.get("model")) |v| switch (v) {
        .string => |s| if (s.len > 0) s else state.ai_model,
        else => state.ai_model,
    } else state.ai_model;

    if (api_key.len == 0) {
        try respondJson(request, .bad_request, "{\"ok\":false,\"error\":\"No API key\"}");
        return;
    }

    const provider = ai_mod.AiProvider.fromString(provider_str) orelse .openai;
    const eff_endpoint = if (endpoint.len > 0) endpoint else switch (provider) {
        .openai => config.default_openai_endpoint,
        .claude => config.default_claude_endpoint,
    };

    const ai_cfg = ai_mod.AiConfig{
        .provider = provider,
        .endpoint = eff_endpoint,
        .api_key = api_key,
        .model = if (model.len > 0) model else switch (provider) {
            .openai => "gpt-4o-mini",
            .claude => "claude-haiku-4-5-20251001",
        },
        .max_tokens = 8,
    };

    const t0 = compat.milliTimestamp();
    const gen_result = ai_mod.generate(alloc, ai_cfg, .{ .prompt = "ping", .system_prompt = "Reply with: pong" });
    const elapsed = compat.milliTimestamp() - t0;

    if (gen_result) |result| {
        defer result.deinit(alloc);
        if (result.is_error) {
            // API returned a non-200 status with error detail
            var err_resp_buf: std.Io.Writer.Allocating = .init(alloc);
            const ew = &err_resp_buf.writer;
            try ew.writeAll("{\"ok\":false,\"error\":");
            try utils.writeJsonString(ew, result.text);
            try ew.writeAll("}");
            const err_resp = err_resp_buf.toOwnedSlice() catch return;
            defer alloc.free(err_resp);
            try respondJson(request, .ok, err_resp);
        } else {
            var resp_buf: [64]u8 = undefined;
            const resp = std.fmt.bufPrint(&resp_buf, "{{\"ok\":true,\"latency_ms\":{d}}}", .{elapsed}) catch "{\"ok\":true,\"latency_ms\":0}";
            try respondJson(request, .ok, resp);
        }
    } else |err| {
        var err_buf: [128]u8 = undefined;
        const err_msg = std.fmt.bufPrint(&err_buf, "{{\"ok\":false,\"error\":\"{s}\"}}", .{@errorName(err)}) catch "{\"ok\":false,\"error\":\"test failed\"}";
        try respondJson(request, .ok, err_msg);
    }
}

// ═══════════════════════════════════════════════════════════════════
//  Helpers
// ═══════════════════════════════════════════════════════════════════

fn readBody(alloc: std.mem.Allocator, request: *std.http.Server.Request) ![]const u8 {
    var body_buf: [8192]u8 = undefined;
    const body_reader = request.readerExpectNone(&body_buf);
    return body_reader.allocRemaining(alloc, std.Io.Limit.limited(10 * 1024 * 1024)) catch return "";
}

fn respondJson(request: *std.http.Server.Request, status: std.http.Status, body: []const u8) !void {
    try request.respond(body, .{
        .status = status,
        .extra_headers = &[_]std.http.Header{
            .{ .name = "Content-Type", .value = "application/json; charset=utf-8" },
            .{ .name = "Access-Control-Allow-Origin", .value = "*" },
            .{ .name = "Cache-Control", .value = "no-cache" },
        },
    });
}

fn respondText(request: *std.http.Server.Request, status: std.http.Status, body: []const u8) !void {
    try request.respond(body, .{
        .status = status,
        .extra_headers = &[_]std.http.Header{
            .{ .name = "Content-Type", .value = "text/plain; charset=utf-8" },
        },
    });
}

fn jsonStr(root: std.json.Value, key: []const u8) []const u8 {
    if (root.object.get(key)) |v| {
        return switch (v) {
            .string => |s| s,
            else => "",
        };
    }
    return "";
}
