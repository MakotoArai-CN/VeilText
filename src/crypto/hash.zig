const std = @import("std");

// ═══════════════════════════════════════════════════════════════════
//  Hash Algorithms
// ═══════════════════════════════════════════════════════════════════

pub const HashAlgorithm = enum {
    sha256,
    sha512,
    blake3,
    md5,

    pub fn name(self: HashAlgorithm) []const u8 {
        return switch (self) {
            .sha256 => "SHA-256",
            .sha512 => "SHA-512",
            .blake3 => "BLAKE3",
            .md5 => "MD5",
        };
    }

    pub fn digestLen(self: HashAlgorithm) usize {
        return switch (self) {
            .sha256 => 32,
            .sha512 => 64,
            .blake3 => 32,
            .md5 => 16,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════
//  Hash Functions
// ═══════════════════════════════════════════════════════════════════

/// Compute hash and return raw bytes.
pub fn hashBytes(algorithm: HashAlgorithm, data: []const u8) [64]u8 {
    var result: [64]u8 = undefined;
    switch (algorithm) {
        .sha256 => {
            var hash: [32]u8 = undefined;
            std.crypto.hash.sha2.Sha256.hash(data, &hash, .{});
            @memcpy(result[0..32], &hash);
            @memset(result[32..], 0);
        },
        .sha512 => {
            std.crypto.hash.sha2.Sha512.hash(data, &result, .{});
        },
        .blake3 => {
            var hash: [32]u8 = undefined;
            std.crypto.hash.Blake3.hash(data, &hash, .{});
            @memcpy(result[0..32], &hash);
            @memset(result[32..], 0);
        },
        .md5 => {
            var hash: [16]u8 = undefined;
            std.crypto.hash.Md5.hash(data, &hash, .{});
            @memcpy(result[0..16], &hash);
            @memset(result[16..], 0);
        },
    }
    return result;
}

/// Compute hash and return as lowercase hex string.
pub fn hashHex(allocator: std.mem.Allocator, algorithm: HashAlgorithm, data: []const u8) ![]u8 {
    const raw = hashBytes(algorithm, data);
    const digest_len = algorithm.digestLen();
    const out = try allocator.alloc(u8, digest_len * 2);
    const hex_chars = "0123456789abcdef";
    for (0..digest_len) |i| {
        out[i * 2] = hex_chars[raw[i] >> 4];
        out[i * 2 + 1] = hex_chars[raw[i] & 0x0f];
    }
    return out;
}

/// Compute SHA-256 hash as a 64-char hex string (stack allocated).
pub fn sha256String(data: []const u8) [64]u8 {
    var hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(data, &hash, .{});
    var hex: [64]u8 = undefined;
    const chars = "0123456789abcdef";
    for (hash, 0..) |b, i| {
        hex[i * 2] = chars[b >> 4];
        hex[i * 2 + 1] = chars[b & 0x0f];
    }
    return hex;
}

// ═══════════════════════════════════════════════════════════════════
//  HMAC
// ═══════════════════════════════════════════════════════════════════

const HmacSha256 = std.crypto.auth.hmac.sha2.HmacSha256;

/// Compute HMAC-SHA256.
pub fn hmacSha256(data: []const u8, key: []const u8) [32]u8 {
    var out: [32]u8 = undefined;
    HmacSha256.create(&out, data, key);
    return out;
}

/// Constant-time comparison.
pub fn constTimeEql(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    var diff: u8 = 0;
    for (a, b) |x, y| diff |= x ^ y;
    return diff == 0;
}

// ═══════════════════════════════════════════════════════════════════
//  Tests
// ═══════════════════════════════════════════════════════════════════

test "sha256 known value" {
    const hex = sha256String("hello");
    try std.testing.expectEqualStrings("2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824", &hex);
}

test "sha256 empty string" {
    const hex = sha256String("");
    try std.testing.expectEqualStrings("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", &hex);
}

test "hashHex SHA-256" {
    const allocator = std.testing.allocator;
    const hex = try hashHex(allocator, .sha256, "hello");
    defer allocator.free(hex);
    try std.testing.expectEqualStrings("2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824", hex);
}

test "hashHex BLAKE3" {
    const allocator = std.testing.allocator;
    const hex = try hashHex(allocator, .blake3, "hello");
    defer allocator.free(hex);
    try std.testing.expect(hex.len == 64);
}

test "hashHex MD5" {
    const allocator = std.testing.allocator;
    const hex = try hashHex(allocator, .md5, "hello");
    defer allocator.free(hex);
    try std.testing.expect(hex.len == 32);
}

test "hmac produces consistent output" {
    const a = hmacSha256("hello", "key");
    const b = hmacSha256("hello", "key");
    try std.testing.expectEqualSlices(u8, &a, &b);

    const c = hmacSha256("hello", "different-key");
    try std.testing.expect(!std.mem.eql(u8, &a, &c));
}
