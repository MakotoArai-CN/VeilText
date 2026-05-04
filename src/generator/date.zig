const std = @import("std");
const compat = @import("../compat.zig");

// ═══════════════════════════════════════════════════════════════════
//  Date Generator
// ═══════════════════════════════════════════════════════════════════

pub const DateFormat = enum {
    /// YYYY-MM-DD
    iso,
    /// YYYYMMDD
    compact,
    /// MM-DD
    mmdd,
    /// MMDD
    mmdd_compact,
    /// DD
    dd,
    /// YYYY
    yyyy,
    /// MM
    mm,
    /// Unix timestamp
    unix,

    pub fn fromString(s: []const u8) ?DateFormat {
        const map = .{
            .{ "iso", DateFormat.iso },
            .{ "YYYY-MM-DD", DateFormat.iso },
            .{ "compact", DateFormat.compact },
            .{ "YYYYMMDD", DateFormat.compact },
            .{ "MM-DD", DateFormat.mmdd },
            .{ "MMDD", DateFormat.mmdd_compact },
            .{ "DD", DateFormat.dd },
            .{ "YYYY", DateFormat.yyyy },
            .{ "MM", DateFormat.mm },
            .{ "unix", DateFormat.unix },
        };
        inline for (map) |entry| {
            if (std.mem.eql(u8, s, entry[0])) return entry[1];
        }
        return null;
    }
};

pub fn generate(allocator: std.mem.Allocator, format: DateFormat) ![]u8 {
    const ts = compat.timestamp();
    const epoch = std.time.epoch.EpochSeconds{ .secs = @intCast(ts) };
    const day = epoch.getEpochDay();
    const yd = day.calculateYearDay();
    const md = yd.calculateMonthDay();

    const year = yd.year;
    const month = md.month.numeric();
    const day_num = md.day_index + 1;

    return switch (format) {
        .iso => try std.fmt.allocPrint(allocator, "{d:0>4}-{d:0>2}-{d:0>2}", .{ year, month, day_num }),
        .compact => try std.fmt.allocPrint(allocator, "{d:0>4}{d:0>2}{d:0>2}", .{ year, month, day_num }),
        .mmdd => try std.fmt.allocPrint(allocator, "{d:0>2}-{d:0>2}", .{ month, day_num }),
        .mmdd_compact => try std.fmt.allocPrint(allocator, "{d:0>2}{d:0>2}", .{ month, day_num }),
        .dd => try std.fmt.allocPrint(allocator, "{d:0>2}", .{day_num}),
        .yyyy => try std.fmt.allocPrint(allocator, "{d:0>4}", .{year}),
        .mm => try std.fmt.allocPrint(allocator, "{d:0>2}", .{month}),
        .unix => try std.fmt.allocPrint(allocator, "{d}", .{ts}),
    };
}

// ═══════════════════════════════════════════════════════════════════
//  Tests
// ═══════════════════════════════════════════════════════════════════

test "date generate iso format" {
    const allocator = std.testing.allocator;
    const result = try generate(allocator, .iso);
    defer allocator.free(result);
    // Should be in YYYY-MM-DD format
    try std.testing.expect(result.len == 10);
    try std.testing.expect(result[4] == '-');
    try std.testing.expect(result[7] == '-');
}

test "date generate compact format" {
    const allocator = std.testing.allocator;
    const result = try generate(allocator, .compact);
    defer allocator.free(result);
    try std.testing.expect(result.len == 8);
}

test "date format from string" {
    try std.testing.expect(DateFormat.fromString("iso") == .iso);
    try std.testing.expect(DateFormat.fromString("YYYY-MM-DD") == .iso);
    try std.testing.expect(DateFormat.fromString("MMDD") == .mmdd_compact);
    try std.testing.expect(DateFormat.fromString("unknown") == null);
}
