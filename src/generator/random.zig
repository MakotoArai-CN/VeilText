const std = @import("std");
const compat = @import("../compat.zig");

// ═══════════════════════════════════════════════════════════════════
//  Random Generator
// ═══════════════════════════════════════════════════════════════════

pub const RandomType = enum {
    /// Decimal digits (0-9)
    decimal,
    /// Hexadecimal (0-9a-f)
    hex,
    /// Alphanumeric (a-z A-Z 0-9)
    alphanumeric,
    /// Lowercase letters only
    alpha_lower,
    /// Uppercase letters only
    alpha_upper,
    /// Full ASCII printable (no space)
    ascii,
    /// UUID v4 format
    uuid,

    pub fn fromString(s: []const u8) ?RandomType {
        const map = .{
            .{ "decimal", RandomType.decimal },
            .{ "dec", RandomType.decimal },
            .{ "hex", RandomType.hex },
            .{ "alphanumeric", RandomType.alphanumeric },
            .{ "alnum", RandomType.alphanumeric },
            .{ "alpha_lower", RandomType.alpha_lower },
            .{ "lower", RandomType.alpha_lower },
            .{ "alpha_upper", RandomType.alpha_upper },
            .{ "upper", RandomType.alpha_upper },
            .{ "ascii", RandomType.ascii },
            .{ "uuid", RandomType.uuid },
        };
        inline for (map) |entry| {
            if (std.mem.eql(u8, s, entry[0])) return entry[1];
        }
        return null;
    }
};

const decimal_chars = "0123456789";
const hex_chars = "0123456789abcdef";
const alpha_lower_chars = "abcdefghijklmnopqrstuvwxyz";
const alpha_upper_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
const alphanumeric_chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";
const ascii_chars = "!\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~";

/// Generate a random string of the specified type and length.
pub fn generate(allocator: std.mem.Allocator, random_type: RandomType, length: usize) ![]u8 {
    if (random_type == .uuid) return generateUUID(allocator);

    const charset: []const u8 = switch (random_type) {
        .decimal => decimal_chars,
        .hex => hex_chars,
        .alphanumeric => alphanumeric_chars,
        .alpha_lower => alpha_lower_chars,
        .alpha_upper => alpha_upper_chars,
        .ascii => ascii_chars,
        .uuid => unreachable,
    };

    const out = try allocator.alloc(u8, length);
    var random_bytes: [256]u8 = undefined;

    var i: usize = 0;
    while (i < length) {
        const batch = @min(length - i, 256);
        compat.randomBytes(random_bytes[0..batch]);
        for (0..batch) |j| {
            out[i + j] = charset[random_bytes[j] % @as(u8, @intCast(charset.len))];
        }
        i += batch;
    }

    return out;
}

/// Generate a UUID v4.
fn generateUUID(allocator: std.mem.Allocator) ![]u8 {
    var raw: [16]u8 = undefined;
    compat.randomBytes(&raw);

    // Set version 4
    raw[6] = (raw[6] & 0x0f) | 0x40;
    // Set variant
    raw[8] = (raw[8] & 0x3f) | 0x80;

    return try std.fmt.allocPrint(allocator, "{x:0>2}{x:0>2}{x:0>2}{x:0>2}-{x:0>2}{x:0>2}-{x:0>2}{x:0>2}-{x:0>2}{x:0>2}-{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}", .{
        raw[0],  raw[1],  raw[2],  raw[3],
        raw[4],  raw[5],
        raw[6],  raw[7],
        raw[8],  raw[9],
        raw[10], raw[11], raw[12], raw[13], raw[14], raw[15],
    });
}

/// Generate a random number in range [min, max].
pub fn randomInRange(min: i64, max: i64) i64 {
    if (min >= max) return min;
    const range: u64 = @intCast(max - min + 1);
    var buf: [8]u8 = undefined;
    compat.randomBytes(&buf);
    const raw = std.mem.readInt(u64, &buf, .little);
    return min + @as(i64, @intCast(raw % range));
}

// ═══════════════════════════════════════════════════════════════════
//  Tests
// ═══════════════════════════════════════════════════════════════════

test "generate decimal" {
    const allocator = std.testing.allocator;
    const result = try generate(allocator, .decimal, 10);
    defer allocator.free(result);
    try std.testing.expect(result.len == 10);
    for (result) |c| {
        try std.testing.expect(c >= '0' and c <= '9');
    }
}

test "generate hex" {
    const allocator = std.testing.allocator;
    const result = try generate(allocator, .hex, 16);
    defer allocator.free(result);
    try std.testing.expect(result.len == 16);
    for (result) |c| {
        try std.testing.expect((c >= '0' and c <= '9') or (c >= 'a' and c <= 'f'));
    }
}

test "generate uuid" {
    const allocator = std.testing.allocator;
    const result = try generate(allocator, .uuid, 0);
    defer allocator.free(result);
    // UUID format: 8-4-4-4-12
    try std.testing.expect(result.len == 36);
    try std.testing.expect(result[8] == '-');
    try std.testing.expect(result[13] == '-');
    try std.testing.expect(result[18] == '-');
    try std.testing.expect(result[23] == '-');
}

test "randomInRange" {
    const val = randomInRange(1, 100);
    try std.testing.expect(val >= 1 and val <= 100);
}

test "random type from string" {
    try std.testing.expect(RandomType.fromString("hex") == .hex);
    try std.testing.expect(RandomType.fromString("uuid") == .uuid);
    try std.testing.expect(RandomType.fromString("nope") == null);
}
