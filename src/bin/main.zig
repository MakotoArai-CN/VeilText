const std = @import("std");
const veiltext = @import("veiltext");
const config = veiltext.config;
const server = veiltext.server;
const output = veiltext.output;

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var cfg = config.Runtime{};
    if (init.environ_map.get("VEILTEXT_ADMIN_TOKEN")) |val| {
        if (val.len > 0) cfg.admin_token = try allocator.dupe(u8, val);
    }

    // Parse CLI arguments
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, allocator);
    defer args.deinit();
    _ = args.next(); // skip program name

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "-port") or std.mem.eql(u8, arg, "--port")) {
            if (args.next()) |val| {
                cfg.port = std.fmt.parseInt(u16, val, 10) catch {
                    std.log.err("Invalid port: {s}", .{val});
                    return error.InvalidArgs;
                };
            }
        } else if (std.mem.eql(u8, arg, "-bind") or std.mem.eql(u8, arg, "--bind")) {
            if (args.next()) |val| cfg.bind_host = try allocator.dupe(u8, val);
        } else if (std.mem.eql(u8, arg, "-data") or std.mem.eql(u8, arg, "--data")) {
            if (args.next()) |val| cfg.data_dir = try allocator.dupe(u8, val);
        } else if (std.mem.eql(u8, arg, "-openai-key") or std.mem.eql(u8, arg, "--openai-key")) {
            if (args.next()) |val| cfg.openai_api_key = try allocator.dupe(u8, val);
        } else if (std.mem.eql(u8, arg, "-openai-endpoint") or std.mem.eql(u8, arg, "--openai-endpoint")) {
            if (args.next()) |val| cfg.openai_endpoint = try allocator.dupe(u8, val);
        } else if (std.mem.eql(u8, arg, "-claude-key") or std.mem.eql(u8, arg, "--claude-key")) {
            if (args.next()) |val| cfg.claude_api_key = try allocator.dupe(u8, val);
        } else if (std.mem.eql(u8, arg, "-claude-endpoint") or std.mem.eql(u8, arg, "--claude-endpoint")) {
            if (args.next()) |val| cfg.claude_endpoint = try allocator.dupe(u8, val);
        } else if (std.mem.eql(u8, arg, "-admin-token") or std.mem.eql(u8, arg, "--admin-token")) {
            if (args.next()) |val| cfg.admin_token = try allocator.dupe(u8, val);
        } else if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            printUsage();
            return;
        } else if (std.mem.eql(u8, arg, "-v") or std.mem.eql(u8, arg, "--version")) {
            std.debug.print("{s} v{s}\n", .{ config.app_name, config.app_version });
            return;
        }
    }

    // Detect terminal capabilities and print styled banner
    const caps = output.TermCaps.detect(init.environ_map);

    var url_buf: [64]u8 = undefined;
    const url = std.fmt.bufPrint(&url_buf, "http://{s}:{d}", .{ cfg.bind_host, cfg.port }) catch "http://127.0.0.1:7478";

    // Write banner to stderr via std.debug infrastructure
    var banner_buf: [4096]u8 = undefined;
    var w: std.Io.Writer = .fixed(&banner_buf);

    try w.writeByte('\n');
    try output.printBanner(&w, caps, config.app_version, url);
    try output.printKeyValue(&w, "Listen", url, caps);
    try output.printKeyValue(&w, "Data dir", cfg.data_dir, caps);
    if (cfg.openai_api_key.len > 0) {
        try output.printKeyValue(&w, "OpenAI", "configured", caps);
    }
    if (cfg.claude_api_key.len > 0) {
        try output.printKeyValue(&w, "Claude", "configured", caps);
    }
    if (cfg.admin_token.len > 0) {
        try output.printKeyValue(&w, "Admin audit API", "token protected", caps);
    }
    try w.writeByte('\n');
    try output.printSuccess(&w, "Server starting...", caps);
    try w.writeByte('\n');

    const written = w.buffered();
    std.debug.print("{s}", .{written});

    try server.start(allocator, init.io, init.environ_map, cfg);
}

fn printUsage() void {
    std.debug.print(
        \\VeilText - Text Encryption Toolkit
        \\
        \\Usage: veiltext [options]
        \\
        \\Options:
        \\  -port <port>              Listen port (default: 7478)
        \\  -bind <address>           Bind address (default: 127.0.0.1)
        \\  -data <dir>               Data directory (default: .veiltext-data)
        \\  -openai-key <key>         OpenAI API key
        \\  -openai-endpoint <url>    OpenAI-compatible API endpoint
        \\  -claude-key <key>         Claude API key
        \\  -claude-endpoint <url>    Claude API endpoint
        \\  -admin-token <token>      Admin token for audit APIs (or VEILTEXT_ADMIN_TOKEN)
        \\  -h, --help                Show this help
        \\  -v, --version             Show version
        \\
    , .{});
}
