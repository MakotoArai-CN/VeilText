const std = @import("std");
const compat = @import("compat.zig");

// ═══════════════════════════════════════════════════════════════════
//  HTML Escaping
// ═══════════════════════════════════════════════════════════════════

/// Escape HTML special characters. Caller owns returned memory.
pub fn htmlEscape(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var size: usize = 0;
    for (input) |c| {
        size += switch (c) {
            '&' => 5, // &amp;
            '<' => 4, // &lt;
            '>' => 4, // &gt;
            '"' => 6, // &quot;
            '\'' => 5, // &#39;
            else => 1,
        };
    }
    if (size == input.len) return try allocator.dupe(u8, input);

    const out = try allocator.alloc(u8, size);
    var i: usize = 0;
    for (input) |c| {
        switch (c) {
            '&' => {
                @memcpy(out[i..][0..5], "&amp;");
                i += 5;
            },
            '<' => {
                @memcpy(out[i..][0..4], "&lt;");
                i += 4;
            },
            '>' => {
                @memcpy(out[i..][0..4], "&gt;");
                i += 4;
            },
            '"' => {
                @memcpy(out[i..][0..6], "&quot;");
                i += 6;
            },
            '\'' => {
                @memcpy(out[i..][0..5], "&#39;");
                i += 5;
            },
            else => {
                out[i] = c;
                i += 1;
            },
        }
    }
    return out;
}

// ═══════════════════════════════════════════════════════════════════
//  JSON Helpers
// ═══════════════════════════════════════════════════════════════════

/// Write a JSON string value, properly escaped.
pub fn writeJsonString(writer: *std.Io.Writer, s: []const u8) !void {
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
//  Hex Encoding
// ═══════════════════════════════════════════════════════════════════

const hex_chars = "0123456789abcdef";

/// Encode bytes to lowercase hex string. Caller owns returned memory.
pub fn hexEncode(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
    const out = try allocator.alloc(u8, data.len * 2);
    for (data, 0..) |b, i| {
        out[i * 2] = hex_chars[b >> 4];
        out[i * 2 + 1] = hex_chars[b & 0x0f];
    }
    return out;
}

/// Decode hex string to bytes. Caller owns returned memory.
pub fn hexDecode(allocator: std.mem.Allocator, hex: []const u8) ![]u8 {
    if (hex.len % 2 != 0) return error.InvalidHexLength;
    const out = try allocator.alloc(u8, hex.len / 2);
    errdefer allocator.free(out);
    for (0..out.len) |i| {
        const hi = hexVal(hex[i * 2]) orelse return error.InvalidHexChar;
        const lo = hexVal(hex[i * 2 + 1]) orelse return error.InvalidHexChar;
        out[i] = (@as(u8, hi) << 4) | @as(u8, lo);
    }
    return out;
}

fn hexVal(c: u8) ?u4 {
    return switch (c) {
        '0'...'9' => @intCast(c - '0'),
        'a'...'f' => @intCast(c - 'a' + 10),
        'A'...'F' => @intCast(c - 'A' + 10),
        else => null,
    };
}

// ═══════════════════════════════════════════════════════════════════
//  Formatting
// ═══════════════════════════════════════════════════════════════════

/// Format byte count as human-readable (e.g. "4.2 MB").
pub fn formatBytes(buf: *[64]u8, bytes: u64) []const u8 {
    const units = [_][]const u8{ "B", "KB", "MB", "GB", "TB" };
    var value: f64 = @floatFromInt(bytes);
    var unit_idx: usize = 0;
    while (value >= 1024.0 and unit_idx < units.len - 1) {
        value /= 1024.0;
        unit_idx += 1;
    }
    if (unit_idx == 0) {
        return std.fmt.bufPrint(buf, "{d} {s}", .{ bytes, units[0] }) catch "? B";
    }
    return std.fmt.bufPrint(buf, "{d:.1} {s}", .{ value, units[unit_idx] }) catch "? B";
}

// ═══════════════════════════════════════════════════════════════════
//  Timestamp
// ═══════════════════════════════════════════════════════════════════

/// Get current Unix timestamp in seconds.
pub fn timestamp() i64 {
    return compat.timestamp();
}

/// Format timestamp as ISO 8601 string (YYYY-MM-DD HH:MM:SS).
pub fn formatTimestamp(buf: *[19]u8, ts: i64) []const u8 {
    const epoch = std.time.epoch.EpochSeconds{ .secs = @intCast(ts) };
    const day = epoch.getEpochDay();
    const yd = day.calculateYearDay();
    const md = yd.calculateMonthDay();
    const ds = epoch.getDaySeconds();

    return std.fmt.bufPrint(buf, "{d:0>4}-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2}:{d:0>2}", .{
        yd.year,
        md.month.numeric(),
        md.day_index + 1,
        ds.getHoursIntoDay(),
        ds.getMinutesIntoHour(),
        ds.getSecondsIntoMinute(),
    }) catch "????-??-?? ??:??:??";
}

/// Get today's date as "YYYY-MM-DD".
pub fn todayDate(buf: *[10]u8) []const u8 {
    const ts = timestamp();
    const epoch = std.time.epoch.EpochSeconds{ .secs = @intCast(ts) };
    const day = epoch.getEpochDay();
    const yd = day.calculateYearDay();
    const md = yd.calculateMonthDay();
    return std.fmt.bufPrint(buf, "{d:0>4}-{d:0>2}-{d:0>2}", .{
        yd.year,
        md.month.numeric(),
        md.day_index + 1,
    }) catch "????-??-??";
}

// ═══════════════════════════════════════════════════════════════════
//  Tests
// ═══════════════════════════════════════════════════════════════════

test "htmlEscape basic" {
    const allocator = std.testing.allocator;
    const result = try htmlEscape(allocator, "<script>alert('xss')</script>");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("&lt;script&gt;alert(&#39;xss&#39;)&lt;/script&gt;", result);
}

test "htmlEscape no change" {
    const allocator = std.testing.allocator;
    const result = try htmlEscape(allocator, "hello world");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("hello world", result);
}

test "hexEncode and hexDecode round-trip" {
    const allocator = std.testing.allocator;
    const data = "Hello, VeilText!";
    const hex = try hexEncode(allocator, data);
    defer allocator.free(hex);
    const decoded = try hexDecode(allocator, hex);
    defer allocator.free(decoded);
    try std.testing.expectEqualStrings(data, decoded);
}

test "formatBytes" {
    var buf: [64]u8 = undefined;
    try std.testing.expectEqualStrings("0 B", formatBytes(&buf, 0));
    var buf2: [64]u8 = undefined;
    try std.testing.expectEqualStrings("1.0 KB", formatBytes(&buf2, 1024));
    var buf3: [64]u8 = undefined;
    try std.testing.expectEqualStrings("1.5 MB", formatBytes(&buf3, 1572864));
}
