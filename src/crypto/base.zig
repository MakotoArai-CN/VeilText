const std = @import("std");

// ═══════════════════════════════════════════════════════════════════
//  Base16 (Hex)
// ═══════════════════════════════════════════════════════════════════

const hex_chars_upper = "0123456789ABCDEF";
const hex_chars_lower = "0123456789abcdef";

pub fn base16Encode(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
    const out = try allocator.alloc(u8, data.len * 2);
    for (data, 0..) |b, i| {
        out[i * 2] = hex_chars_upper[b >> 4];
        out[i * 2 + 1] = hex_chars_upper[b & 0x0f];
    }
    return out;
}

pub fn base16Decode(allocator: std.mem.Allocator, hex: []const u8) ![]u8 {
    if (hex.len % 2 != 0) return error.InvalidBase16Length;
    const out = try allocator.alloc(u8, hex.len / 2);
    errdefer allocator.free(out);
    for (0..out.len) |i| {
        const hi = hexVal(hex[i * 2]) orelse return error.InvalidBase16Char;
        const lo = hexVal(hex[i * 2 + 1]) orelse return error.InvalidBase16Char;
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
//  Base32 (RFC 4648)
// ═══════════════════════════════════════════════════════════════════

const b32_alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";

pub fn base32Encode(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
    if (data.len == 0) return try allocator.dupe(u8, "");
    const out_len = ((data.len + 4) / 5) * 8;
    const out = try allocator.alloc(u8, out_len);
    var oi: usize = 0;
    var i: usize = 0;

    while (i < data.len) {
        const remaining = data.len - i;
        var buf: [5]u8 = .{ 0, 0, 0, 0, 0 };
        const chunk = @min(remaining, 5);
        @memcpy(buf[0..chunk], data[i..][0..chunk]);

        out[oi + 0] = b32_alphabet[buf[0] >> 3];
        out[oi + 1] = b32_alphabet[((buf[0] & 0x07) << 2) | (buf[1] >> 6)];
        out[oi + 2] = if (chunk > 1) b32_alphabet[(buf[1] >> 1) & 0x1f] else '=';
        out[oi + 3] = if (chunk > 1) b32_alphabet[((buf[1] & 0x01) << 4) | (buf[2] >> 4)] else '=';
        out[oi + 4] = if (chunk > 2) b32_alphabet[((buf[2] & 0x0f) << 1) | (buf[3] >> 7)] else '=';
        out[oi + 5] = if (chunk > 3) b32_alphabet[(buf[3] >> 2) & 0x1f] else '=';
        out[oi + 6] = if (chunk > 3) b32_alphabet[((buf[3] & 0x03) << 3) | (buf[4] >> 5)] else '=';
        out[oi + 7] = if (chunk > 4) b32_alphabet[buf[4] & 0x1f] else '=';

        oi += 8;
        i += 5;
    }
    return out;
}

pub fn base32Decode(allocator: std.mem.Allocator, encoded: []const u8) ![]u8 {
    if (encoded.len == 0) return try allocator.dupe(u8, "");
    if (encoded.len % 8 != 0) return error.InvalidBase32Length;

    // Count padding
    var padding: usize = 0;
    var j: usize = encoded.len;
    while (j > 0 and encoded[j - 1] == '=') {
        padding += 1;
        j -= 1;
    }

    const data_bits = (encoded.len - padding) * 5;
    const out_len = data_bits / 8;
    const out = try allocator.alloc(u8, out_len);
    errdefer allocator.free(out);

    var bit_buf: u32 = 0;
    var bits: u5 = 0;
    var oi: usize = 0;

    for (encoded) |c| {
        if (c == '=') break;
        const val = b32DecodeChar(c) orelse return error.InvalidBase32Char;
        bit_buf = (bit_buf << 5) | @as(u32, val);
        bits += 5;
        if (bits >= 8) {
            bits -= 8;
            out[oi] = @truncate(bit_buf >> bits);
            oi += 1;
        }
    }
    return out[0..oi];
}

fn b32DecodeChar(c: u8) ?u5 {
    return switch (c) {
        'A'...'Z' => @intCast(c - 'A'),
        'a'...'z' => @intCast(c - 'a'),
        '2'...'7' => @intCast(c - '2' + 26),
        else => null,
    };
}

// ═══════════════════════════════════════════════════════════════════
//  Base58 (Bitcoin alphabet)
// ═══════════════════════════════════════════════════════════════════

const b58_alphabet = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";

pub fn base58Encode(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
    if (data.len == 0) return try allocator.dupe(u8, "");

    // Count leading zeros
    var leading_zeros: usize = 0;
    for (data) |b| {
        if (b != 0) break;
        leading_zeros += 1;
    }

    // Allocate enough space (log(256)/log(58) ≈ 1.366)
    const size = data.len * 138 / 100 + 1;
    var buf = try allocator.alloc(u8, size);
    defer allocator.free(buf);
    @memset(buf, 0);

    var length: usize = 0;
    for (data) |b| {
        var carry: u32 = @intCast(b);
        var i: usize = 0;
        var idx = size;
        while (idx > 0) {
            idx -= 1;
            if (carry == 0 and i >= length) break;
            carry += @as(u32, buf[idx]) * 256;
            buf[idx] = @truncate(carry % 58);
            carry /= 58;
            i += 1;
        }
        length = i;
    }

    // Skip leading zeros in the output
    var start: usize = size - length;
    while (start < size and buf[start] == 0) start += 1;

    // Build result: leading '1's + encoded
    const result_len = leading_zeros + (size - start);
    const result = try allocator.alloc(u8, result_len);
    @memset(result[0..leading_zeros], '1');
    for (start..size) |i| {
        result[leading_zeros + (i - start)] = b58_alphabet[buf[i]];
    }
    return result;
}

pub fn base58Decode(allocator: std.mem.Allocator, encoded: []const u8) ![]u8 {
    if (encoded.len == 0) return try allocator.dupe(u8, "");

    // Count leading '1's
    var leading_ones: usize = 0;
    for (encoded) |c| {
        if (c != '1') break;
        leading_ones += 1;
    }

    const size = encoded.len * 733 / 1000 + 1;
    var buf = try allocator.alloc(u8, size);
    defer allocator.free(buf);
    @memset(buf, 0);

    var length: usize = 0;
    for (encoded) |c| {
        const val = b58DecodeChar(c) orelse return error.InvalidBase58Char;
        var carry: u32 = @intCast(val);
        var i: usize = 0;
        var idx = size;
        while (idx > 0) {
            idx -= 1;
            if (carry == 0 and i >= length) break;
            carry += @as(u32, buf[idx]) * 58;
            buf[idx] = @truncate(carry % 256);
            carry /= 256;
            i += 1;
        }
        length = i;
    }

    var start: usize = size - length;
    while (start < size and buf[start] == 0) start += 1;

    const result_len = leading_ones + (size - start);
    const result = try allocator.alloc(u8, result_len);
    @memset(result[0..leading_ones], 0);
    @memcpy(result[leading_ones..], buf[start..size]);
    return result;
}

fn b58DecodeChar(c: u8) ?u8 {
    for (b58_alphabet, 0..) |ch, i| {
        if (ch == c) return @intCast(i);
    }
    return null;
}

// ═══════════════════════════════════════════════════════════════════
//  Base64 (std.base64 wrapper)
// ═══════════════════════════════════════════════════════════════════

pub fn base64Encode(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
    const encoder = std.base64.standard.Encoder;
    const len = encoder.calcSize(data.len);
    const out = try allocator.alloc(u8, len);
    _ = encoder.encode(out, data);
    return out;
}

pub fn base64Decode(allocator: std.mem.Allocator, encoded: []const u8) ![]u8 {
    var cleaned: std.ArrayListUnmanaged(u8) = .empty;
    defer cleaned.deinit(allocator);

    var has_padding = false;
    var has_url_chars = false;
    for (encoded) |c| {
        switch (c) {
            ' ', '\t', '\r', '\n' => continue,
            '-' => {
                has_url_chars = true;
                try cleaned.append(allocator, c);
            },
            '_' => {
                has_url_chars = true;
                try cleaned.append(allocator, c);
            },
            '=' => {
                has_padding = true;
                try cleaned.append(allocator, c);
            },
            else => try cleaned.append(allocator, c),
        }
    }

    if (cleaned.items.len == 0) return try allocator.dupe(u8, "");
    if (cleaned.items.len % 4 == 1) return error.InvalidBase64;

    const decoder = if (has_url_chars)
        (if (has_padding) std.base64.url_safe.Decoder else std.base64.url_safe_no_pad.Decoder)
    else
        (if (has_padding) std.base64.standard.Decoder else std.base64.standard_no_pad.Decoder);

    const len = decoder.calcSizeForSlice(cleaned.items) catch return error.InvalidBase64;
    const out = try allocator.alloc(u8, len);
    errdefer allocator.free(out);
    decoder.decode(out, cleaned.items) catch return error.InvalidBase64;
    return out;
}

// ═══════════════════════════════════════════════════════════════════
//  Base85 (Ascii85 / Z85 variant)
// ═══════════════════════════════════════════════════════════════════

const b85_chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz!#$%&()*+-;<=>?@^_`{|}~";

pub fn base85Encode(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
    if (data.len == 0) return try allocator.dupe(u8, "");

    // Pad to multiple of 4
    const padded_len = ((data.len + 3) / 4) * 4;
    var padded = try allocator.alloc(u8, padded_len);
    defer allocator.free(padded);
    @memcpy(padded[0..data.len], data);
    @memset(padded[data.len..], 0);

    const out_len = (padded_len / 4) * 5;
    const out = try allocator.alloc(u8, out_len);
    var oi: usize = 0;

    var i: usize = 0;
    while (i < padded_len) : (i += 4) {
        var val: u32 = @as(u32, padded[i]) << 24 |
            @as(u32, padded[i + 1]) << 16 |
            @as(u32, padded[i + 2]) << 8 |
            @as(u32, padded[i + 3]);

        var block: [5]u8 = undefined;
        var k: usize = 5;
        while (k > 0) {
            k -= 1;
            block[k] = b85_chars[@intCast(val % 85)];
            val /= 85;
        }
        @memcpy(out[oi..][0..5], &block);
        oi += 5;
    }

    // Trim output to account for padding
    const extra_bytes = padded_len - data.len;
    const final_len = out_len - extra_bytes;
    const result = try allocator.alloc(u8, final_len);
    @memcpy(result, out[0..final_len]);
    allocator.free(out);
    return result;
}

pub fn base85Decode(allocator: std.mem.Allocator, encoded: []const u8) ![]u8 {
    if (encoded.len == 0) return try allocator.dupe(u8, "");

    // Pad to multiple of 5
    const padded_len = ((encoded.len + 4) / 5) * 5;
    var padded = try allocator.alloc(u8, padded_len);
    defer allocator.free(padded);
    @memcpy(padded[0..encoded.len], encoded);
    @memset(padded[encoded.len..], b85_chars[84]); // pad with highest char

    const out_len = (padded_len / 5) * 4;
    const out = try allocator.alloc(u8, out_len);
    var oi: usize = 0;

    var i: usize = 0;
    while (i < padded_len) : (i += 5) {
        var val: u32 = 0;
        for (0..5) |j| {
            const c = b85DecodeChar(padded[i + j]) orelse return error.InvalidBase85Char;
            val = val * 85 + @as(u32, c);
        }
        out[oi + 0] = @truncate(val >> 24);
        out[oi + 1] = @truncate(val >> 16);
        out[oi + 2] = @truncate(val >> 8);
        out[oi + 3] = @truncate(val);
        oi += 4;
    }

    // Trim for original padding
    const extra_input = padded_len - encoded.len;
    const final_len = out_len - extra_input;
    const result = try allocator.alloc(u8, final_len);
    @memcpy(result, out[0..final_len]);
    allocator.free(out);
    return result;
}

fn b85DecodeChar(c: u8) ?u8 {
    for (b85_chars, 0..) |ch, i| {
        if (ch == c) return @intCast(i);
    }
    return null;
}

// ═══════════════════════════════════════════════════════════════════
//  Unified Interface
// ═══════════════════════════════════════════════════════════════════

pub const BaseEncoding = enum {
    base16,
    base32,
    base58,
    base64,
    base85,

    pub fn name(self: BaseEncoding) []const u8 {
        return switch (self) {
            .base16 => "Base16",
            .base32 => "Base32",
            .base58 => "Base58",
            .base64 => "Base64",
            .base85 => "Base85",
        };
    }
};

/// Encode data using the specified base encoding.
pub fn encode(allocator: std.mem.Allocator, encoding: BaseEncoding, data: []const u8) ![]u8 {
    return switch (encoding) {
        .base16 => base16Encode(allocator, data),
        .base32 => base32Encode(allocator, data),
        .base58 => base58Encode(allocator, data),
        .base64 => base64Encode(allocator, data),
        .base85 => base85Encode(allocator, data),
    };
}

/// Decode data using the specified base encoding.
pub fn decode(allocator: std.mem.Allocator, encoding: BaseEncoding, data: []const u8) ![]u8 {
    return switch (encoding) {
        .base16 => base16Decode(allocator, data),
        .base32 => base32Decode(allocator, data),
        .base58 => base58Decode(allocator, data),
        .base64 => base64Decode(allocator, data),
        .base85 => base85Decode(allocator, data),
    };
}

// ═══════════════════════════════════════════════════════════════════
//  Tests
// ═══════════════════════════════════════════════════════════════════

test "base16 round-trip" {
    const allocator = std.testing.allocator;
    const data = "Hello, VeilText!";
    const encoded = try base16Encode(allocator, data);
    defer allocator.free(encoded);
    const decoded = try base16Decode(allocator, encoded);
    defer allocator.free(decoded);
    try std.testing.expectEqualStrings(data, decoded);
}

test "base32 round-trip" {
    const allocator = std.testing.allocator;
    const data = "Hello, VeilText!";
    const encoded = try base32Encode(allocator, data);
    defer allocator.free(encoded);
    const decoded = try base32Decode(allocator, encoded);
    defer allocator.free(decoded);
    try std.testing.expectEqualStrings(data, decoded);
}

test "base58 round-trip" {
    const allocator = std.testing.allocator;
    const data = "Hello, VeilText!";
    const encoded = try base58Encode(allocator, data);
    defer allocator.free(encoded);
    const decoded = try base58Decode(allocator, encoded);
    defer allocator.free(decoded);
    try std.testing.expectEqualStrings(data, decoded);
}

test "base64 round-trip" {
    const allocator = std.testing.allocator;
    const data = "Hello, VeilText!";
    const encoded = try base64Encode(allocator, data);
    defer allocator.free(encoded);
    const decoded = try base64Decode(allocator, encoded);
    defer allocator.free(decoded);
    try std.testing.expectEqualStrings(data, decoded);
}

test "base85 round-trip" {
    const allocator = std.testing.allocator;
    const data = "Hello, VeilText!";
    const encoded = try base85Encode(allocator, data);
    defer allocator.free(encoded);
    const decoded = try base85Decode(allocator, encoded);
    defer allocator.free(decoded);
    try std.testing.expectEqualStrings(data, decoded);
}

test "base64 known value" {
    const allocator = std.testing.allocator;
    const encoded = try base64Encode(allocator, "Hello");
    defer allocator.free(encoded);
    try std.testing.expectEqualStrings("SGVsbG8=", encoded);
}

test "base64 accepts unpadded and pasted input" {
    const allocator = std.testing.allocator;

    const unpadded = try base64Decode(allocator, "SGVsbG8");
    defer allocator.free(unpadded);
    try std.testing.expectEqualStrings("Hello", unpadded);

    const single = try base64Decode(allocator, "QQ");
    defer allocator.free(single);
    try std.testing.expectEqualStrings("A", single);

    const pasted = try base64Decode(allocator, "SGVs\r\nbG8=");
    defer allocator.free(pasted);
    try std.testing.expectEqualStrings("Hello", pasted);

    const url_safe = try base64Decode(allocator, "-_8");
    defer allocator.free(url_safe);
    try std.testing.expectEqualSlices(u8, &.{ 0xfb, 0xff }, url_safe);
}

test "base16 known value" {
    const allocator = std.testing.allocator;
    const encoded = try base16Encode(allocator, "AB");
    defer allocator.free(encoded);
    try std.testing.expectEqualStrings("4142", encoded);
}
