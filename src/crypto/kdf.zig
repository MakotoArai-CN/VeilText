const std = @import("std");
const compat = @import("../compat.zig");

const HmacSha256 = std.crypto.auth.hmac.sha2.HmacSha256;

// ═══════════════════════════════════════════════════════════════════
//  Key Derivation Functions
// ═══════════════════════════════════════════════════════════════════

pub const KdfAlgorithm = enum {
    pbkdf2_sha256,
    hkdf_sha256,

    pub fn name(self: KdfAlgorithm) []const u8 {
        return switch (self) {
            .pbkdf2_sha256 => "PBKDF2-SHA256",
            .hkdf_sha256 => "HKDF-SHA256",
        };
    }
};

// ═══════════════════════════════════════════════════════════════════
//  PBKDF2
// ═══════════════════════════════════════════════════════════════════

/// Derive a 32-byte key using PBKDF2-HMAC-SHA256.
pub fn pbkdf2(password: []const u8, salt: []const u8, iterations: u32) [32]u8 {
    var dk: [32]u8 = undefined;
    std.crypto.pwhash.pbkdf2(&dk, password, salt, iterations, HmacSha256) catch {
        // Fallback: simple HMAC if PBKDF2 somehow fails
        HmacSha256.create(&dk, password, salt);
    };
    return dk;
}

// ═══════════════════════════════════════════════════════════════════
//  HKDF
// ═══════════════════════════════════════════════════════════════════

/// HKDF-Extract: derive a PRK from input key material + salt.
pub fn hkdfExtract(ikm: []const u8, salt: []const u8) [32]u8 {
    var prk: [32]u8 = undefined;
    HmacSha256.create(&prk, ikm, if (salt.len > 0) salt else &([_]u8{0} ** 32));
    return prk;
}

/// HKDF-Expand: derive output key material from PRK + info.
pub fn hkdfExpand(prk: [32]u8, info: []const u8, out: []u8) void {
    var t: [32]u8 = undefined;
    var t_len: usize = 0;
    var offset: usize = 0;
    var counter: u8 = 1;

    while (offset < out.len) : (counter += 1) {
        var hmac = HmacSha256.init(&prk);
        if (t_len > 0) hmac.update(&t);
        hmac.update(info);
        hmac.update(&[_]u8{counter});
        hmac.final(&t);
        t_len = 32;

        const copy_len = @min(32, out.len - offset);
        @memcpy(out[offset..][0..copy_len], t[0..copy_len]);
        offset += copy_len;
    }
}

/// Derive a 32-byte key using HKDF-SHA256.
pub fn hkdf(ikm: []const u8, salt: []const u8, info: []const u8) [32]u8 {
    const prk = hkdfExtract(ikm, salt);
    var okm: [32]u8 = undefined;
    hkdfExpand(prk, info, &okm);
    return okm;
}

// ═══════════════════════════════════════════════════════════════════
//  Unified Interface
// ═══════════════════════════════════════════════════════════════════

/// Derive a 32-byte key from password + salt using the specified algorithm.
pub fn deriveKey(algorithm: KdfAlgorithm, password: []const u8, salt: []const u8) [32]u8 {
    return switch (algorithm) {
        .pbkdf2_sha256 => pbkdf2(password, salt, 200_000),
        .hkdf_sha256 => hkdf(password, salt, "veiltext-key-derivation"),
    };
}

/// Generate a random salt.
pub fn generateSalt() [16]u8 {
    var salt: [16]u8 = undefined;
    compat.randomBytes(&salt);
    return salt;
}

// ═══════════════════════════════════════════════════════════════════
//  Tests
// ═══════════════════════════════════════════════════════════════════

test "pbkdf2 produces consistent output" {
    const a = pbkdf2("password", "salt", 1000);
    const b = pbkdf2("password", "salt", 1000);
    try std.testing.expectEqualSlices(u8, &a, &b);
}

test "pbkdf2 different passwords produce different keys" {
    const a = pbkdf2("password1", "salt", 1000);
    const b = pbkdf2("password2", "salt", 1000);
    try std.testing.expect(!std.mem.eql(u8, &a, &b));
}

test "hkdf produces consistent output" {
    const a = hkdf("input-key", "salt", "info");
    const b = hkdf("input-key", "salt", "info");
    try std.testing.expectEqualSlices(u8, &a, &b);
}

test "hkdf different inputs produce different keys" {
    const a = hkdf("key1", "salt", "info");
    const b = hkdf("key2", "salt", "info");
    try std.testing.expect(!std.mem.eql(u8, &a, &b));
}

test "deriveKey PBKDF2" {
    const key = deriveKey(.pbkdf2_sha256, "test-password", "test-salt");
    try std.testing.expect(key.len == 32);
    // Verify it's not all zeros
    var all_zero = true;
    for (key) |b| {
        if (b != 0) {
            all_zero = false;
            break;
        }
    }
    try std.testing.expect(!all_zero);
}
