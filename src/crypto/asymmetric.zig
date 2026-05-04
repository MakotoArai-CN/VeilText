const std = @import("std");
const compat = @import("../compat.zig");

// ═══════════════════════════════════════════════════════════════════
//  Asymmetric Encryption (Hybrid: X25519 + AES-256-GCM)
// ═══════════════════════════════════════════════════════════════════

const X25519 = std.crypto.dh.X25519;
const Ed25519 = std.crypto.sign.Ed25519;
const Aes256Gcm = std.crypto.aead.aes_gcm.Aes256Gcm;

pub const AsymmetricAlgorithm = enum {
    x25519_aes_gcm,
    ed25519_sign,

    pub fn name(self: AsymmetricAlgorithm) []const u8 {
        return switch (self) {
            .x25519_aes_gcm => "X25519+AES-256-GCM",
            .ed25519_sign => "Ed25519 Signature",
        };
    }
};

pub const KeyPair = struct {
    public_key: [32]u8,
    secret_key: [32]u8,
};

pub const SignKeyPair = struct {
    public_key: [32]u8,
    secret_key: [64]u8,
};

// ═══════════════════════════════════════════════════════════════════
//  Key Generation
// ═══════════════════════════════════════════════════════════════════

/// Generate an X25519 key pair for encryption.
pub fn generateX25519KeyPair() KeyPair {
    const kp = X25519.KeyPair.generate(compat.io);
    return .{
        .public_key = kp.public_key,
        .secret_key = kp.secret_key,
    };
}

/// Generate an Ed25519 key pair for signing.
pub fn generateEd25519KeyPair() SignKeyPair {
    const kp = Ed25519.KeyPair.generate(compat.io);
    return .{
        .public_key = kp.public_key.toBytes(),
        .secret_key = kp.secret_key.toBytes(),
    };
}

// ═══════════════════════════════════════════════════════════════════
//  Hybrid Encryption (X25519 + AES-256-GCM)
// ═══════════════════════════════════════════════════════════════════

/// Encrypt using hybrid scheme:
/// 1. Generate ephemeral X25519 key pair
/// 2. Derive shared secret via X25519 DH
/// 3. Encrypt plaintext with AES-256-GCM using derived key
/// Output format: [ephemeral_public_key 32][nonce 12][tag 16][ciphertext N]
pub fn hybridEncrypt(allocator: std.mem.Allocator, plaintext: []const u8, recipient_public_key: [32]u8) ![]u8 {
    // Generate ephemeral key pair
    const ephemeral = X25519.KeyPair.generate(compat.io);

    // Derive shared secret
    const shared = X25519.scalarmult(ephemeral.secret_key, recipient_public_key) catch
        return error.KeyExchangeFailed;

    // Use SHA-256(shared_secret) as AES key
    var aes_key: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(&shared, &aes_key, .{});

    // Encrypt with AES-256-GCM
    var nonce: [Aes256Gcm.nonce_length]u8 = undefined;
    compat.randomBytes(&nonce);

    const ct = try allocator.alloc(u8, plaintext.len);
    defer allocator.free(ct);
    var tag: [Aes256Gcm.tag_length]u8 = undefined;
    Aes256Gcm.encrypt(ct, &tag, plaintext, "", nonce, aes_key);

    // Pack: [ephemeral_pk 32][nonce 12][tag 16][ciphertext]
    const packed_len = 32 + nonce.len + tag.len + ct.len;
    const result_buf = try allocator.alloc(u8, packed_len);
    @memcpy(result_buf[0..32], &ephemeral.public_key);
    @memcpy(result_buf[32..][0..nonce.len], &nonce);
    @memcpy(result_buf[32 + nonce.len ..][0..tag.len], &tag);
    @memcpy(result_buf[32 + nonce.len + tag.len ..], ct);

    return result_buf;
}

/// Decrypt hybrid-encrypted data.
pub fn hybridDecrypt(allocator: std.mem.Allocator, enc_data: []const u8, secret_key: [32]u8) ![]u8 {
    const header_len = 32 + Aes256Gcm.nonce_length + Aes256Gcm.tag_length;
    if (enc_data.len < header_len) return error.InvalidCiphertext;

    const ephemeral_pk: [32]u8 = enc_data[0..32].*;
    const nonce: [Aes256Gcm.nonce_length]u8 = enc_data[32..][0..Aes256Gcm.nonce_length].*;
    const tag: [Aes256Gcm.tag_length]u8 = enc_data[32 + Aes256Gcm.nonce_length ..][0..Aes256Gcm.tag_length].*;
    const ct = enc_data[header_len..];

    // Derive shared secret
    const shared = X25519.scalarmult(secret_key, ephemeral_pk) catch
        return error.KeyExchangeFailed;

    var aes_key: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(&shared, &aes_key, .{});

    // Decrypt
    const plaintext = try allocator.alloc(u8, ct.len);
    errdefer allocator.free(plaintext);
    Aes256Gcm.decrypt(plaintext, ct, tag, "", nonce, aes_key) catch {
        return error.DecryptionFailed;
    };

    return plaintext;
}

// ═══════════════════════════════════════════════════════════════════
//  Ed25519 Signing
// ═══════════════════════════════════════════════════════════════════

/// Sign a message with Ed25519.
pub fn sign(message: []const u8, secret_key: [64]u8) ![64]u8 {
    const sk = try Ed25519.SecretKey.fromBytes(secret_key);
    const kp = try Ed25519.KeyPair.fromSecretKey(sk);
    const sig = try kp.sign(message, null);
    return sig.toBytes();
}

/// Verify an Ed25519 signature.
pub fn verify(message: []const u8, signature: [64]u8, public_key: [32]u8) bool {
    const sig = Ed25519.Signature.fromBytes(signature);
    const pk = Ed25519.PublicKey.fromBytes(public_key) catch return false;
    sig.verify(message, pk) catch return false;
    return true;
}

// ═══════════════════════════════════════════════════════════════════
//  Tests
// ═══════════════════════════════════════════════════════════════════

test "X25519 hybrid encrypt/decrypt round-trip" {
    const allocator = std.testing.allocator;
    const plaintext = "Hello, hybrid encryption!";

    const kp = generateX25519KeyPair();
    const encrypted = try hybridEncrypt(allocator, plaintext, kp.public_key);
    defer allocator.free(encrypted);

    const decrypted = try hybridDecrypt(allocator, encrypted, kp.secret_key);
    defer allocator.free(decrypted);

    try std.testing.expectEqualStrings(plaintext, decrypted);
}

test "Ed25519 sign/verify" {
    const kp = generateEd25519KeyPair();
    const message = "Sign this message";
    const sig = try sign(message, kp.secret_key);
    try std.testing.expect(verify(message, sig, kp.public_key));
    try std.testing.expect(!verify("Wrong message", sig, kp.public_key));
}
