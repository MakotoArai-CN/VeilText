const std = @import("std");
const compat = @import("../compat.zig");

const Aes256Gcm = std.crypto.aead.aes_gcm.Aes256Gcm;
const ChaCha20Poly1305 = std.crypto.aead.chacha_poly.ChaCha20Poly1305;
const XChaCha20Poly1305 = std.crypto.aead.chacha_poly.XChaCha20Poly1305;

// ═══════════════════════════════════════════════════════════════════
//  Types
// ═══════════════════════════════════════════════════════════════════

pub const SymmetricAlgorithm = enum {
    aes_256_gcm,
    chacha20_poly1305,
    xchacha20_poly1305,

    pub fn name(self: SymmetricAlgorithm) []const u8 {
        return switch (self) {
            .aes_256_gcm => "AES-256-GCM",
            .chacha20_poly1305 => "ChaCha20-Poly1305",
            .xchacha20_poly1305 => "XChaCha20-Poly1305",
        };
    }

    pub fn keyLen(self: SymmetricAlgorithm) usize {
        return switch (self) {
            .aes_256_gcm => Aes256Gcm.key_length,
            .chacha20_poly1305 => ChaCha20Poly1305.key_length,
            .xchacha20_poly1305 => XChaCha20Poly1305.key_length,
        };
    }

    pub fn nonceLen(self: SymmetricAlgorithm) usize {
        return switch (self) {
            .aes_256_gcm => Aes256Gcm.nonce_length,
            .chacha20_poly1305 => ChaCha20Poly1305.nonce_length,
            .xchacha20_poly1305 => XChaCha20Poly1305.nonce_length,
        };
    }

    pub fn tagLen(self: SymmetricAlgorithm) usize {
        return switch (self) {
            .aes_256_gcm => Aes256Gcm.tag_length,
            .chacha20_poly1305 => ChaCha20Poly1305.tag_length,
            .xchacha20_poly1305 => XChaCha20Poly1305.tag_length,
        };
    }
};

pub const EncryptedData = struct {
    ciphertext: []u8,
    nonce: []u8,
    tag: [16]u8,
    algorithm: SymmetricAlgorithm,
};

// ═══════════════════════════════════════════════════════════════════
//  Encryption
// ═══════════════════════════════════════════════════════════════════

/// Encrypt plaintext using the specified algorithm.
/// Returns a enc_data format: [nonce][tag][ciphertext]
pub fn encrypt(allocator: std.mem.Allocator, algorithm: SymmetricAlgorithm, plaintext: []const u8, key: []const u8) ![]u8 {
    return switch (algorithm) {
        .aes_256_gcm => encryptAesGcm(allocator, plaintext, key),
        .chacha20_poly1305 => encryptChaCha20(allocator, plaintext, key),
        .xchacha20_poly1305 => encryptXChaCha20(allocator, plaintext, key),
    };
}

/// Decrypt ciphertext (enc_data format: [nonce][tag][ciphertext]).
pub fn decrypt(allocator: std.mem.Allocator, algorithm: SymmetricAlgorithm, data: []const u8, key: []const u8) ![]u8 {
    return switch (algorithm) {
        .aes_256_gcm => decryptAesGcm(allocator, data, key),
        .chacha20_poly1305 => decryptChaCha20(allocator, data, key),
        .xchacha20_poly1305 => decryptXChaCha20(allocator, data, key),
    };
}

// ═══════════════════════════════════════════════════════════════════
//  AES-256-GCM
// ═══════════════════════════════════════════════════════════════════

fn encryptAesGcm(allocator: std.mem.Allocator, plaintext: []const u8, key_raw: []const u8) ![]u8 {
    const key = padKey(32, key_raw);
    var nonce: [Aes256Gcm.nonce_length]u8 = undefined;
    compat.randomBytes(&nonce);

    const ct = try allocator.alloc(u8, plaintext.len);
    defer allocator.free(ct);
    var tag: [Aes256Gcm.tag_length]u8 = undefined;
    Aes256Gcm.encrypt(ct, &tag, plaintext, "", nonce, key);

    // Pack: [nonce 12][tag 16][ciphertext N]
    const enc_data = try allocator.alloc(u8, nonce.len + tag.len + ct.len);
    @memcpy(enc_data[0..nonce.len], &nonce);
    @memcpy(enc_data[nonce.len..][0..tag.len], &tag);
    @memcpy(enc_data[nonce.len + tag.len ..], ct);
    return enc_data;
}

fn decryptAesGcm(allocator: std.mem.Allocator, enc_data: []const u8, key_raw: []const u8) ![]u8 {
    const nonce_len = Aes256Gcm.nonce_length;
    const tag_len = Aes256Gcm.tag_length;
    const header = nonce_len + tag_len;

    if (enc_data.len < header) return error.InvalidCiphertext;

    const key = padKey(32, key_raw);
    const nonce: [nonce_len]u8 = enc_data[0..nonce_len].*;
    const tag: [tag_len]u8 = enc_data[nonce_len..][0..tag_len].*;
    const ct = enc_data[header..];

    const plaintext = try allocator.alloc(u8, ct.len);
    errdefer allocator.free(plaintext);
    Aes256Gcm.decrypt(plaintext, ct, tag, "", nonce, key) catch {
        return error.DecryptionFailed;
    };
    return plaintext;
}

// ═══════════════════════════════════════════════════════════════════
//  ChaCha20-Poly1305
// ═══════════════════════════════════════════════════════════════════

fn encryptChaCha20(allocator: std.mem.Allocator, plaintext: []const u8, key_raw: []const u8) ![]u8 {
    const key = padKey(ChaCha20Poly1305.key_length, key_raw);
    var nonce: [ChaCha20Poly1305.nonce_length]u8 = undefined;
    compat.randomBytes(&nonce);

    const ct = try allocator.alloc(u8, plaintext.len);
    defer allocator.free(ct);
    var tag: [ChaCha20Poly1305.tag_length]u8 = undefined;
    ChaCha20Poly1305.encrypt(ct, &tag, plaintext, "", nonce, key);

    const enc_data = try allocator.alloc(u8, nonce.len + tag.len + ct.len);
    @memcpy(enc_data[0..nonce.len], &nonce);
    @memcpy(enc_data[nonce.len..][0..tag.len], &tag);
    @memcpy(enc_data[nonce.len + tag.len ..], ct);
    return enc_data;
}

fn decryptChaCha20(allocator: std.mem.Allocator, enc_data: []const u8, key_raw: []const u8) ![]u8 {
    const nonce_len = ChaCha20Poly1305.nonce_length;
    const tag_len = ChaCha20Poly1305.tag_length;
    const header = nonce_len + tag_len;

    if (enc_data.len < header) return error.InvalidCiphertext;

    const key = padKey(ChaCha20Poly1305.key_length, key_raw);
    const nonce: [nonce_len]u8 = enc_data[0..nonce_len].*;
    const tag: [tag_len]u8 = enc_data[nonce_len..][0..tag_len].*;
    const ct = enc_data[header..];

    const plaintext = try allocator.alloc(u8, ct.len);
    errdefer allocator.free(plaintext);
    ChaCha20Poly1305.decrypt(plaintext, ct, tag, "", nonce, key) catch {
        return error.DecryptionFailed;
    };
    return plaintext;
}

// ═══════════════════════════════════════════════════════════════════
//  XChaCha20-Poly1305
// ═══════════════════════════════════════════════════════════════════

fn encryptXChaCha20(allocator: std.mem.Allocator, plaintext: []const u8, key_raw: []const u8) ![]u8 {
    const key = padKey(XChaCha20Poly1305.key_length, key_raw);
    var nonce: [XChaCha20Poly1305.nonce_length]u8 = undefined;
    compat.randomBytes(&nonce);

    const ct = try allocator.alloc(u8, plaintext.len);
    defer allocator.free(ct);
    var tag: [XChaCha20Poly1305.tag_length]u8 = undefined;
    XChaCha20Poly1305.encrypt(ct, &tag, plaintext, "", nonce, key);

    const enc_data = try allocator.alloc(u8, nonce.len + tag.len + ct.len);
    @memcpy(enc_data[0..nonce.len], &nonce);
    @memcpy(enc_data[nonce.len..][0..tag.len], &tag);
    @memcpy(enc_data[nonce.len + tag.len ..], ct);
    return enc_data;
}

fn decryptXChaCha20(allocator: std.mem.Allocator, enc_data: []const u8, key_raw: []const u8) ![]u8 {
    const nonce_len = XChaCha20Poly1305.nonce_length;
    const tag_len = XChaCha20Poly1305.tag_length;
    const header = nonce_len + tag_len;

    if (enc_data.len < header) return error.InvalidCiphertext;

    const key = padKey(XChaCha20Poly1305.key_length, key_raw);
    const nonce: [nonce_len]u8 = enc_data[0..nonce_len].*;
    const tag: [tag_len]u8 = enc_data[nonce_len..][0..tag_len].*;
    const ct = enc_data[header..];

    const plaintext = try allocator.alloc(u8, ct.len);
    errdefer allocator.free(plaintext);
    XChaCha20Poly1305.decrypt(plaintext, ct, tag, "", nonce, key) catch {
        return error.DecryptionFailed;
    };
    return plaintext;
}

// ═══════════════════════════════════════════════════════════════════
//  Helpers
// ═══════════════════════════════════════════════════════════════════

/// Pad or truncate a key to the required length.
/// Uses SHA-256 hash if key is not the right length.
fn padKey(comptime required_len: usize, key_raw: []const u8) [required_len]u8 {
    if (key_raw.len == required_len) {
        return key_raw[0..required_len].*;
    }
    // Use SHA-256 to derive the key from arbitrary-length input
    var hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(key_raw, &hash, .{});
    var result: [required_len]u8 = undefined;
    if (required_len <= 32) {
        @memcpy(&result, hash[0..required_len]);
    } else {
        @memcpy(result[0..32], &hash);
        @memset(result[32..], 0);
    }
    return result;
}

// ═══════════════════════════════════════════════════════════════════
//  Tests
// ═══════════════════════════════════════════════════════════════════

test "AES-256-GCM encrypt/decrypt round-trip" {
    const allocator = std.testing.allocator;
    const plaintext = "Hello, VeilText AES-256-GCM!";
    const key = "my-secret-password-for-testing!!";

    const enc_data = try encrypt(allocator, .aes_256_gcm, plaintext, key);
    defer allocator.free(enc_data);

    const decrypted = try decrypt(allocator, .aes_256_gcm, enc_data, key);
    defer allocator.free(decrypted);

    try std.testing.expectEqualStrings(plaintext, decrypted);
}

test "ChaCha20-Poly1305 encrypt/decrypt round-trip" {
    const allocator = std.testing.allocator;
    const plaintext = "Hello, VeilText ChaCha20!";
    const key = "another-secret-password-test-key";

    const enc_data = try encrypt(allocator, .chacha20_poly1305, plaintext, key);
    defer allocator.free(enc_data);

    const decrypted = try decrypt(allocator, .chacha20_poly1305, enc_data, key);
    defer allocator.free(decrypted);

    try std.testing.expectEqualStrings(plaintext, decrypted);
}

test "XChaCha20-Poly1305 encrypt/decrypt round-trip" {
    const allocator = std.testing.allocator;
    const plaintext = "Hello, VeilText XChaCha20!";
    const key = "xchacha-secret-key-for-testing!!";

    const enc_data = try encrypt(allocator, .xchacha20_poly1305, plaintext, key);
    defer allocator.free(enc_data);

    const decrypted = try decrypt(allocator, .xchacha20_poly1305, enc_data, key);
    defer allocator.free(decrypted);

    try std.testing.expectEqualStrings(plaintext, decrypted);
}

test "wrong key fails decryption" {
    const allocator = std.testing.allocator;
    const enc_data = try encrypt(allocator, .aes_256_gcm, "secret data", "correct-key");
    defer allocator.free(enc_data);

    const result = decrypt(allocator, .aes_256_gcm, enc_data, "wrong-key-here!!");
    try std.testing.expectError(error.DecryptionFailed, result);
}

test "short key is padded via SHA-256" {
    const allocator = std.testing.allocator;
    const plaintext = "Short key test";

    const enc_data = try encrypt(allocator, .aes_256_gcm, plaintext, "short");
    defer allocator.free(enc_data);

    const decrypted = try decrypt(allocator, .aes_256_gcm, enc_data, "short");
    defer allocator.free(decrypted);

    try std.testing.expectEqualStrings(plaintext, decrypted);
}
