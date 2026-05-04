const std = @import("std");
const compat = @import("../compat.zig");

// ═══════════════════════════════════════════════════════════════════
//  News / Realtime Info Fetcher
// ═══════════════════════════════════════════════════════════════════

/// News source types.
pub const NewsSource = enum {
    /// Generic web scraping via URL
    web,
    /// Keyword-based news search
    keyword,

    pub fn fromString(s: []const u8) ?NewsSource {
        if (std.mem.eql(u8, s, "web")) return .web;
        if (std.mem.eql(u8, s, "keyword")) return .keyword;
        return null;
    }
};

/// Realtime data types.
pub const RealtimeType = enum {
    /// Gold price
    gold_price,
    /// Date info
    date,

    pub fn fromString(s: []const u8) ?RealtimeType {
        const map = .{
            .{ "gold", RealtimeType.gold_price },
            .{ "gold_price", RealtimeType.gold_price },
            .{ "date", RealtimeType.date },
        };
        inline for (map) |entry| {
            if (std.mem.eql(u8, s, entry[0])) return entry[1];
        }
        return null;
    }
};

/// Fetch news keywords from a URL. Returns extracted text keywords.
/// NOTE: This is a simplified implementation. Full web scraping would need
/// a proper HTTP client with TLS, which Zig's std.http.Client provides.
pub fn fetchKeywords(allocator: std.mem.Allocator, url: []const u8) ![]u8 {
    _ = url;
    // Placeholder: In production, this would:
    // 1. Make HTTP GET request to the URL
    // 2. Parse HTML response
    // 3. Extract keywords from title/meta/content
    // For now, return a placeholder that includes the current date
    const date_mod = @import("date.zig");
    const date_str = try date_mod.generate(allocator, .compact);
    defer allocator.free(date_str);

    return try std.fmt.allocPrint(allocator, "news-{s}", .{date_str});
}

/// Fetch realtime data value.
pub fn fetchRealtimeValue(allocator: std.mem.Allocator, data_type: RealtimeType) ![]u8 {
    return switch (data_type) {
        .gold_price => {
            // Placeholder: would fetch from a gold price API
            // e.g., https://api.gold-api.com/price/XAU
            return try allocator.dupe(u8, "2350");
        },
        .date => {
            const date_mod = @import("date.zig");
            return try date_mod.generate(allocator, .iso);
        },
    };
}

/// Simple HTTP GET request using Zig's std.http.Client.
/// Returns response body as a string.
pub fn httpGet(allocator: std.mem.Allocator, url: []const u8) ![]u8 {
    var client = std.http.Client{ .allocator = allocator, .io = compat.io };
    defer client.deinit();

    var response_buf: std.Io.Writer.Allocating = .init(allocator);
    defer response_buf.deinit();

    const result = try client.fetch(.{
        .location = .{ .url = url },
        .method = .GET,
        .extra_headers = &.{
            .{ .name = "user-agent", .value = "VeilText/0.1.0" },
        },
        .response_writer = &response_buf.writer,
    });

    if (result.status != .ok) {
        return error.HttpError;
    }

    return response_buf.toOwnedSlice();
}

// ═══════════════════════════════════════════════════════════════════
//  Tests
// ═══════════════════════════════════════════════════════════════════

test "fetchRealtimeValue gold_price" {
    const allocator = std.testing.allocator;
    const result = try fetchRealtimeValue(allocator, .gold_price);
    defer allocator.free(result);
    try std.testing.expect(result.len > 0);
}

test "fetchRealtimeValue date" {
    const allocator = std.testing.allocator;
    const result = try fetchRealtimeValue(allocator, .date);
    defer allocator.free(result);
    try std.testing.expect(result.len == 10); // YYYY-MM-DD
}

test "realtime type fromString" {
    try std.testing.expect(RealtimeType.fromString("gold") == .gold_price);
    try std.testing.expect(RealtimeType.fromString("date") == .date);
    try std.testing.expect(RealtimeType.fromString("unknown") == null);
}
