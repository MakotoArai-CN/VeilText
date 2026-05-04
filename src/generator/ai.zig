const std = @import("std");
const compat = @import("../compat.zig");

// ═══════════════════════════════════════════════════════════════════
//  AI API Integration (OpenAI-compatible + Claude API)
// ═══════════════════════════════════════════════════════════════════

pub const AiProvider = enum {
    openai,
    claude,

    pub fn name(self: AiProvider) []const u8 {
        return switch (self) {
            .openai => "OpenAI",
            .claude => "Claude",
        };
    }

    pub fn fromString(s: []const u8) ?AiProvider {
        if (std.mem.eql(u8, s, "openai")) return .openai;
        if (std.mem.eql(u8, s, "claude")) return .claude;
        return null;
    }
};

pub const AiConfig = struct {
    provider: AiProvider = .openai,
    endpoint: []const u8 = "https://api.openai.com/v1",
    api_key: []const u8 = "",
    model: []const u8 = "gpt-4o-mini",
    max_tokens: u32 = 256,
};

pub const AiRequest = struct {
    prompt: []const u8,
    system_prompt: []const u8 = "You are a helpful assistant that generates creative text based on current events and user requirements. Respond with ONLY the generated text, no explanations.",
};

pub const GenerateResult = struct {
    text: []u8,
    is_error: bool = false,

    pub fn deinit(self: GenerateResult, allocator: std.mem.Allocator) void {
        allocator.free(self.text);
    }
};

/// Call AI API and return generated text, or an error detail message.
pub fn generate(allocator: std.mem.Allocator, ai_config: AiConfig, request: AiRequest) !GenerateResult {
    if (ai_config.api_key.len == 0) {
        return error.NoApiKey;
    }

    return switch (ai_config.provider) {
        .openai => callOpenAi(allocator, ai_config, request),
        .claude => callClaude(allocator, ai_config, request),
    };
}

/// Call OpenAI-compatible API.
fn callOpenAi(allocator: std.mem.Allocator, ai_config: AiConfig, request: AiRequest) !GenerateResult {
    // Build request body
    var body_buf: std.Io.Writer.Allocating = .init(allocator);
    const w = &body_buf.writer;

    try w.writeAll("{\"model\":\"");
    try w.writeAll(ai_config.model);
    try w.writeAll("\",\"max_tokens\":");
    try w.print("{d}", .{ai_config.max_tokens});
    try w.writeAll(",\"messages\":[{\"role\":\"system\",\"content\":");
    try writeJsonStr(w, request.system_prompt);
    try w.writeAll("},{\"role\":\"user\",\"content\":");
    try writeJsonStr(w, request.prompt);
    try w.writeAll("}]}");

    const body = body_buf.toOwnedSlice() catch return error.OutOfMemory;
    defer allocator.free(body);

    // Build URL: endpoint + /chat/completions
    const url = try std.fmt.allocPrint(allocator, "{s}/chat/completions", .{ai_config.endpoint});
    defer allocator.free(url);

    // Make HTTP request
    const result = try httpPost(allocator, url, body, ai_config.api_key, "Bearer");
    defer allocator.free(result.body);

    if (result.status != .ok) {
        // Try to extract error message from API response
        return extractApiError(allocator, result.body, result.status);
    }

    // Parse response — extract content from choices[0].message.content
    const text = try parseOpenAiResponse(allocator, result.body);
    return .{ .text = text };
}

/// Call Claude API.
fn callClaude(allocator: std.mem.Allocator, ai_config: AiConfig, request: AiRequest) !GenerateResult {
    // Build request body
    var body_buf: std.Io.Writer.Allocating = .init(allocator);
    const w = &body_buf.writer;

    try w.writeAll("{\"model\":\"");
    try w.writeAll(if (ai_config.model.len > 0) ai_config.model else "claude-sonnet-4-20250514");
    try w.writeAll("\",\"max_tokens\":");
    try w.print("{d}", .{ai_config.max_tokens});
    try w.writeAll(",\"system\":");
    try writeJsonStr(w, request.system_prompt);
    try w.writeAll(",\"messages\":[{\"role\":\"user\",\"content\":");
    try writeJsonStr(w, request.prompt);
    try w.writeAll("}]}");

    const body = body_buf.toOwnedSlice() catch return error.OutOfMemory;
    defer allocator.free(body);

    // Build URL: endpoint + /messages
    const url = try std.fmt.allocPrint(allocator, "{s}/messages", .{ai_config.endpoint});
    defer allocator.free(url);

    // Make HTTP request with x-api-key header
    const result = try httpPost(allocator, url, body, ai_config.api_key, "x-api-key");
    defer allocator.free(result.body);

    if (result.status != .ok) {
        return extractApiError(allocator, result.body, result.status);
    }

    // Parse response — extract content from content[0].text
    const text = try parseClaudeResponse(allocator, result.body);
    return .{ .text = text };
}

// ═══════════════════════════════════════════════════════════════════
//  HTTP Client
// ═══════════════════════════════════════════════════════════════════

pub const HttpResult = struct {
    body: []u8,
    status: std.http.Status,
};

fn httpPost(allocator: std.mem.Allocator, url: []const u8, body: []const u8, api_key: []const u8, auth_type: []const u8) !HttpResult {
    const is_claude = std.mem.eql(u8, auth_type, "x-api-key");
    const auth_header_name: []const u8 = if (is_claude) "x-api-key" else "authorization";

    // Build auth value: Bearer prefix for OpenAI-style, raw key for Claude
    const auth_value = if (is_claude)
        try allocator.dupe(u8, api_key)
    else
        try std.fmt.allocPrint(allocator, "Bearer {s}", .{api_key});
    defer allocator.free(auth_value);

    var client = std.http.Client{ .allocator = allocator, .io = compat.io };
    defer client.deinit();

    var response_buf: std.Io.Writer.Allocating = .init(allocator);
    errdefer response_buf.deinit();

    const claude_headers = [_]std.http.Header{
        .{ .name = "content-type", .value = "application/json" },
        .{ .name = auth_header_name, .value = auth_value },
        .{ .name = "anthropic-version", .value = "2023-06-01" },
        .{ .name = "accept", .value = "application/json" },
    };
    const openai_headers = [_]std.http.Header{
        .{ .name = "content-type", .value = "application/json" },
        .{ .name = auth_header_name, .value = auth_value },
        .{ .name = "accept", .value = "application/json" },
    };

    const result = client.fetch(.{
        .location = .{ .url = url },
        .method = .POST,
        .payload = body,
        .extra_headers = if (is_claude) &claude_headers else &openai_headers,
        .response_writer = &response_buf.writer,
    }) catch return error.ConnectionFailed;

    return .{
        .body = try response_buf.toOwnedSlice(),
        .status = result.status,
    };
}

// ═══════════════════════════════════════════════════════════════════
//  Response Parsing
// ═══════════════════════════════════════════════════════════════════

fn parseOpenAiResponse(allocator: std.mem.Allocator, response: []const u8) ![]u8 {
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, response, .{}) catch
        return error.InvalidResponse;
    defer parsed.deinit();

    const root = parsed.value;
    const choices = root.object.get("choices") orelse return error.InvalidResponse;
    const choices_arr = switch (choices) {
        .array => |a| a,
        else => return error.InvalidResponse,
    };
    if (choices_arr.items.len == 0) return error.InvalidResponse;

    const message = choices_arr.items[0].object.get("message") orelse return error.InvalidResponse;
    if (message != .object) return error.InvalidResponse;

    // Prefer "content"; fall back to "reasoning_content" (DeepSeek, etc.).
    if (message.object.get("content")) |content| {
        if (content == .string and content.string.len > 0) {
            return allocator.dupe(u8, content.string);
        }
    }
    if (message.object.get("reasoning_content")) |rc| {
        if (rc == .string and rc.string.len > 0) {
            return allocator.dupe(u8, rc.string);
        }
    }
    return error.InvalidResponse;
}

fn parseClaudeResponse(allocator: std.mem.Allocator, response: []const u8) ![]u8 {
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, response, .{}) catch
        return error.InvalidResponse;
    defer parsed.deinit();

    const root = parsed.value;
    const content = root.object.get("content") orelse return error.InvalidResponse;
    const content_arr = switch (content) {
        .array => |a| a,
        else => return error.InvalidResponse,
    };
    if (content_arr.items.len == 0) return error.InvalidResponse;

    // Concatenate every text block (Claude can return multiple).
    var buf: std.Io.Writer.Allocating = .init(allocator);
    errdefer buf.deinit();
    const w = &buf.writer;

    for (content_arr.items) |block| {
        if (block != .object) continue;
        const block_type = block.object.get("type") orelse continue;
        if (block_type != .string) continue;
        if (!std.mem.eql(u8, block_type.string, "text")) continue;
        const text = block.object.get("text") orelse continue;
        if (text != .string) continue;
        try w.writeAll(text.string);
    }

    if (buf.written().len == 0) return error.InvalidResponse;
    return buf.toOwnedSlice();
}

// ═══════════════════════════════════════════════════════════════════
//  Helpers
// ═══════════════════════════════════════════════════════════════════

/// Extract a human-readable error message from an API error response body.
/// Returns a GenerateResult with is_error=true containing the error detail.
fn extractApiError(allocator: std.mem.Allocator, body: []const u8, status: std.http.Status) !GenerateResult {
    // Try to parse JSON error response: {"error":{"message":"..."}} or {"error":"..."}
    if (body.len > 0) {
        if (std.json.parseFromSlice(std.json.Value, allocator, body, .{})) |parsed| {
            defer parsed.deinit();
            const root = parsed.value;
            if (root == .object) {
                if (root.object.get("error")) |err_val| {
                    // OpenAI format: {"error":{"message":"...", "type":"...", "code":"..."}}
                    if (err_val == .object) {
                        if (err_val.object.get("message")) |msg| {
                            if (msg == .string) {
                                const detail = try std.fmt.allocPrint(allocator, "API {d}: {s}", .{ @intFromEnum(status), msg.string });
                                return .{ .text = detail, .is_error = true };
                            }
                        }
                    }
                    // Simple format: {"error":"some string"}
                    if (err_val == .string) {
                        const detail = try std.fmt.allocPrint(allocator, "API {d}: {s}", .{ @intFromEnum(status), err_val.string });
                        return .{ .text = detail, .is_error = true };
                    }
                }
                // Claude format: {"type":"error","error":{"type":"...","message":"..."}}
                if (root.object.get("message")) |msg| {
                    if (msg == .string) {
                        const detail = try std.fmt.allocPrint(allocator, "API {d}: {s}", .{ @intFromEnum(status), msg.string });
                        return .{ .text = detail, .is_error = true };
                    }
                }
            }
        } else |_| {}

        // If JSON parsing failed, return raw body (truncated)
        const max_len: usize = 256;
        const truncated = if (body.len > max_len) body[0..max_len] else body;
        const detail = try std.fmt.allocPrint(allocator, "API {d}: {s}", .{ @intFromEnum(status), truncated });
        return .{ .text = detail, .is_error = true };
    }

    // Empty body fallback
    const detail = try std.fmt.allocPrint(allocator, "API error (HTTP {d})", .{@intFromEnum(status)});
    return .{ .text = detail, .is_error = true };
}

fn writeJsonStr(writer: *std.Io.Writer, s: []const u8) !void {
    try writer.writeByte('"');
    for (s) |c| {
        switch (c) {
            '"' => try writer.writeAll("\\\""),
            '\\' => try writer.writeAll("\\\\"),
            '\n' => try writer.writeAll("\\n"),
            '\r' => try writer.writeAll("\\r"),
            '\t' => try writer.writeAll("\\t"),
            else => {
                if (c < 0x20) {
                    try writer.print("\\u{x:0>4}", .{c});
                } else {
                    try writer.writeByte(c);
                }
            },
        }
    }
    try writer.writeByte('"');
}

// ═══════════════════════════════════════════════════════════════════
//  Tests
// ═══════════════════════════════════════════════════════════════════

test "AiProvider fromString" {
    try std.testing.expect(AiProvider.fromString("openai") == .openai);
    try std.testing.expect(AiProvider.fromString("claude") == .claude);
    try std.testing.expect(AiProvider.fromString("nope") == null);
}

test "generate without API key returns error" {
    const allocator = std.testing.allocator;
    const cfg = AiConfig{};
    const result = generate(allocator, cfg, .{ .prompt = "test" });
    try std.testing.expectError(error.NoApiKey, result);
}

test "parseOpenAiResponse" {
    const allocator = std.testing.allocator;
    const json =
        \\{"choices":[{"message":{"content":"generated text"}}]}
    ;
    const result = try parseOpenAiResponse(allocator, json);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("generated text", result);
}

test "parseClaudeResponse" {
    const allocator = std.testing.allocator;
    const json =
        \\{"content":[{"type":"text","text":"claude output"}]}
    ;
    const result = try parseClaudeResponse(allocator, json);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("claude output", result);
}
