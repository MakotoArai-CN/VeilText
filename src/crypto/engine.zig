const std = @import("std");
const base = @import("base.zig");
const symmetric = @import("symmetric.zig");
const hash = @import("hash.zig");
const kdf = @import("kdf.zig");
const jsob = @import("jsobfuscation.zig");
const bf = @import("brainfuck.zig");
const openssl = @import("openssl_compat.zig");

// ═══════════════════════════════════════════════════════════════════
//  Pipeline Step Types
// ═══════════════════════════════════════════════════════════════════

pub const StepType = enum {
    // Base encodings (no key needed)
    base16,
    base32,
    base58,
    base64,
    base85,

    // Symmetric encryption (key required)
    aes_256_gcm,
    chacha20_poly1305,
    xchacha20_poly1305,
    aes_256_cbc, // OpenSSL / CryptoJS legacy (Salted__ + EVP_BytesToKey-MD5)

    // Hash (one-way, cannot be reversed)
    hash_sha256,
    hash_sha512,
    hash_blake3,
    hash_md5,

    // JS Obfuscation / Encoding
    js_hex_escape,
    js_unicode_escape,
    js_binary_string,
    js_jjencode,
    js_aaencode,
    js_jsfuck,
    js_eval_wrap,
    js_constructor_wrap,
    js_base36_tostring,

    // Brainfuck (text and emoji-mapped variant)
    bf_text,
    bf_emoji,

    pub fn name(self: StepType) []const u8 {
        return switch (self) {
            .base16 => "Base16",
            .base32 => "Base32",
            .base58 => "Base58",
            .base64 => "Base64",
            .base85 => "Base85",
            .aes_256_gcm => "AES-256-GCM",
            .chacha20_poly1305 => "ChaCha20-Poly1305",
            .xchacha20_poly1305 => "XChaCha20-Poly1305",
            .aes_256_cbc => "AES-256-CBC (OpenSSL/CryptoJS)",
            .hash_sha256 => "SHA-256",
            .hash_sha512 => "SHA-512",
            .hash_blake3 => "BLAKE3",
            .hash_md5 => "MD5",
            .js_hex_escape => "Hex Escape (\\xNN)",
            .js_unicode_escape => "Unicode Escape (\\uNNNN)",
            .js_binary_string => "Binary String",
            .js_jjencode => "JJEncode",
            .js_aaencode => "AAEncode",
            .js_jsfuck => "JSFuck",
            .js_eval_wrap => "Eval Wrap",
            .js_constructor_wrap => "Constructor Wrap",
            .js_base36_tostring => "Base36 ToString",
            .bf_text => "Brainfuck",
            .bf_emoji => "Brainfuck (Emoji)",
        };
    }

    pub fn isReversible(self: StepType) bool {
        return switch (self) {
            .hash_sha256, .hash_sha512, .hash_blake3, .hash_md5 => false,
            else => true,
        };
    }

    pub fn needsKey(self: StepType) bool {
        return switch (self) {
            .aes_256_gcm, .chacha20_poly1305, .xchacha20_poly1305, .aes_256_cbc => true,
            else => false,
        };
    }

    pub fn fromString(s: []const u8) ?StepType {
        const map = .{
            .{ "base16", StepType.base16 },
            .{ "base32", StepType.base32 },
            .{ "base58", StepType.base58 },
            .{ "base64", StepType.base64 },
            .{ "base85", StepType.base85 },
            .{ "aes-256-gcm", StepType.aes_256_gcm },
            .{ "aes_256_gcm", StepType.aes_256_gcm },
            .{ "chacha20-poly1305", StepType.chacha20_poly1305 },
            .{ "chacha20_poly1305", StepType.chacha20_poly1305 },
            .{ "xchacha20-poly1305", StepType.xchacha20_poly1305 },
            .{ "xchacha20_poly1305", StepType.xchacha20_poly1305 },
            .{ "aes-256-cbc", StepType.aes_256_cbc },
            .{ "aes_256_cbc", StepType.aes_256_cbc },
            .{ "openssl", StepType.aes_256_cbc },
            .{ "cryptojs", StepType.aes_256_cbc },
            .{ "sha256", StepType.hash_sha256 },
            .{ "sha-256", StepType.hash_sha256 },
            .{ "sha512", StepType.hash_sha512 },
            .{ "sha-512", StepType.hash_sha512 },
            .{ "blake3", StepType.hash_blake3 },
            .{ "md5", StepType.hash_md5 },
            .{ "js_hex_escape", StepType.js_hex_escape },
            .{ "js_unicode_escape", StepType.js_unicode_escape },
            .{ "js_binary_string", StepType.js_binary_string },
            .{ "js_jjencode", StepType.js_jjencode },
            .{ "js_aaencode", StepType.js_aaencode },
            .{ "js_jsfuck", StepType.js_jsfuck },
            .{ "js_eval_wrap", StepType.js_eval_wrap },
            .{ "js_constructor_wrap", StepType.js_constructor_wrap },
            .{ "js_base36_tostring", StepType.js_base36_tostring },
            .{ "bf", StepType.bf_text },
            .{ "bf_text", StepType.bf_text },
            .{ "brainfuck", StepType.bf_text },
            .{ "bf_emoji", StepType.bf_emoji },
            .{ "brainfuck_emoji", StepType.bf_emoji },
        };
        inline for (map) |entry| {
            if (std.mem.eql(u8, s, entry[0])) return entry[1];
        }
        return null;
    }
};

pub const PipelineStep = struct {
    step_type: StepType,
    key: []const u8 = "",

    pub fn fromJson(obj: std.json.ObjectMap) !PipelineStep {
        const type_str = if (obj.get("type")) |v| switch (v) {
            .string => |s| s,
            else => return error.InvalidStep,
        } else return error.InvalidStep;

        const step_type = StepType.fromString(type_str) orelse return error.UnknownStepType;

        const key_str = if (obj.get("key")) |v| switch (v) {
            .string => |s| s,
            else => "",
        } else "";

        return .{
            .step_type = step_type,
            .key = key_str,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════
//  Pipeline Result
// ═══════════════════════════════════════════════════════════════════

pub const PipelineResult = struct {
    ciphertext: []u8,
    description: []const u8,
};

pub const AutoDecodeOptions = struct {
    key: []const u8 = "",
    max_depth: usize = 8,
};

pub const AutoDecodeResult = struct {
    plaintext: []u8,
    description: []u8,
    steps: []StepType,
    attempts: usize,
    still_encoded: bool,

    pub fn deinit(self: AutoDecodeResult, allocator: std.mem.Allocator) void {
        allocator.free(self.plaintext);
        allocator.free(self.description);
        allocator.free(self.steps);
    }
};

// ═══════════════════════════════════════════════════════════════════
//  Execute Pipeline (Encrypt)
// ═══════════════════════════════════════════════════════════════════

/// Execute encryption pipeline: apply steps in order.
pub fn executePipeline(allocator: std.mem.Allocator, plaintext: []const u8, steps: []const PipelineStep) !PipelineResult {
    var current = try allocator.dupe(u8, plaintext);
    var desc_buf: std.Io.Writer.Allocating = .init(allocator);
    const desc_writer = &desc_buf.writer;

    for (steps, 0..) |step, i| {
        if (i > 0) try desc_writer.writeAll(" -> ");
        try desc_writer.writeAll(step.step_type.name());

        const next = try applyStep(allocator, step, current);
        allocator.free(current);
        current = next;
    }

    const description = desc_buf.toOwnedSlice() catch "pipeline";

    return .{
        .ciphertext = current,
        .description = description,
    };
}

/// Execute reverse pipeline: apply steps in reverse order for decryption.
pub fn executeReversePipeline(allocator: std.mem.Allocator, ciphertext: []const u8, steps: []const PipelineStep) !PipelineResult {
    var current = try allocator.dupe(u8, ciphertext);
    var desc_buf: std.Io.Writer.Allocating = .init(allocator);
    const desc_writer = &desc_buf.writer;

    // Apply in reverse
    var i = steps.len;
    while (i > 0) {
        i -= 1;
        const step = steps[i];

        if (!step.step_type.isReversible()) {
            allocator.free(current);
            return error.IrreversibleStep;
        }

        if (i < steps.len - 1) try desc_writer.writeAll(" -> ");
        try desc_writer.writeAll("undo ");
        try desc_writer.writeAll(step.step_type.name());

        const next = try reverseStep(allocator, step, current);
        allocator.free(current);
        current = next;
    }

    const description = desc_buf.toOwnedSlice() catch "reverse pipeline";

    return .{
        .ciphertext = current,
        .description = description,
    };
}

/// Automatically decode/decrypt layered text by matching ciphertext features.
/// If `initial_steps` is provided, those steps are tried first in reverse order.
pub fn autoDecode(
    allocator: std.mem.Allocator,
    ciphertext: []const u8,
    initial_steps: []const PipelineStep,
    options: AutoDecodeOptions,
) !AutoDecodeResult {
    const max_depth = @max(@as(usize, 1), @min(options.max_depth, @as(usize, 12)));
    var current = try allocator.dupe(u8, std.mem.trim(u8, ciphertext, " \t\r\n"));
    errdefer allocator.free(current);

    var applied: std.ArrayListUnmanaged(StepType) = .empty;
    errdefer applied.deinit(allocator);

    var attempts: usize = 0;

    if (initial_steps.len > 0) {
        var probe = try allocator.dupe(u8, current);
        var probe_steps: std.ArrayListUnmanaged(StepType) = .empty;
        var ok = true;

        var i = initial_steps.len;
        while (i > 0) {
            i -= 1;
            const step = initial_steps[i];
            if (!step.step_type.isReversible()) {
                ok = false;
                break;
            }
            attempts += 1;
            const next = reverseStep(allocator, step, std.mem.trim(u8, probe, " \t\r\n")) catch {
                ok = false;
                break;
            };
            allocator.free(probe);
            probe = next;
            try probe_steps.append(allocator, step.step_type);
            if (probe_steps.items.len >= max_depth) break;
        }

        if (ok and probe_steps.items.len > 0) {
            allocator.free(current);
            current = probe;
            try applied.appendSlice(allocator, probe_steps.items);
        } else {
            allocator.free(probe);
        }
        probe_steps.deinit(allocator);
    }

    while (applied.items.len < max_depth) {
        const confidence = bestEncodedConfidence(current, options.key);
        if (confidence < 60) break;

        const best = try tryBestAutoDecodeStep(allocator, current, options.key, &attempts);
        if (best) |candidate| {
            allocator.free(current);
            current = candidate.output;
            try applied.append(allocator, candidate.step_type);
        } else break;
    }

    const description = try buildAutoDecodeDescription(allocator, applied.items);
    const steps = try applied.toOwnedSlice(allocator);
    return .{
        .plaintext = current,
        .description = description,
        .steps = steps,
        .attempts = attempts,
        .still_encoded = bestEncodedConfidence(current, options.key) >= 75,
    };
}

// ═══════════════════════════════════════════════════════════════════
//  Step Application
// ═══════════════════════════════════════════════════════════════════

fn applyStep(allocator: std.mem.Allocator, step: PipelineStep, data: []const u8) ![]u8 {
    return switch (step.step_type) {
        // Base encodings
        .base16 => base.encode(allocator, .base16, data),
        .base32 => base.encode(allocator, .base32, data),
        .base58 => base.encode(allocator, .base58, data),
        .base64 => base.encode(allocator, .base64, data),
        .base85 => base.encode(allocator, .base85, data),

        // Symmetric encryption — encrypted bytes are base64-encoded for text transport
        .aes_256_gcm => blk: {
            const encrypted = try symmetric.encrypt(allocator, .aes_256_gcm, data, step.key);
            defer allocator.free(encrypted);
            break :blk try base.base64Encode(allocator, encrypted);
        },
        .chacha20_poly1305 => blk: {
            const encrypted = try symmetric.encrypt(allocator, .chacha20_poly1305, data, step.key);
            defer allocator.free(encrypted);
            break :blk try base.base64Encode(allocator, encrypted);
        },
        .xchacha20_poly1305 => blk: {
            const encrypted = try symmetric.encrypt(allocator, .xchacha20_poly1305, data, step.key);
            defer allocator.free(encrypted);
            break :blk try base.base64Encode(allocator, encrypted);
        },
        .aes_256_cbc => blk: {
            const blob = try openssl.encrypt(allocator, data, step.key);
            defer allocator.free(blob);
            break :blk try base.base64Encode(allocator, blob);
        },

        // Hashes (one-way)
        .hash_sha256 => hash.hashHex(allocator, .sha256, data),
        .hash_sha512 => hash.hashHex(allocator, .sha512, data),
        .hash_blake3 => hash.hashHex(allocator, .blake3, data),
        .hash_md5 => hash.hashHex(allocator, .md5, data),

        // JS obfuscation encodings
        .js_hex_escape => jsob.encode(allocator, .hex_escape, data),
        .js_unicode_escape => jsob.encode(allocator, .unicode_escape, data),
        .js_binary_string => jsob.encode(allocator, .binary_string, data),
        .js_jjencode => jsob.encode(allocator, .jjencode, data),
        .js_aaencode => jsob.encode(allocator, .aaencode, data),
        .js_jsfuck => jsob.encode(allocator, .jsfuck, data),
        .js_eval_wrap => jsob.encode(allocator, .eval_wrap, data),
        .js_constructor_wrap => jsob.encode(allocator, .constructor_wrap, data),
        .js_base36_tostring => jsob.encode(allocator, .base36_tostring, data),

        // Brainfuck encodings
        .bf_text => bf.encodeText(allocator, data),
        .bf_emoji => bf.encodeEmoji(allocator, data),
    };
}

fn reverseStep(allocator: std.mem.Allocator, step: PipelineStep, data: []const u8) ![]u8 {
    return switch (step.step_type) {
        // Base decodings
        .base16 => base.decode(allocator, .base16, data),
        .base32 => base.decode(allocator, .base32, data),
        .base58 => base.decode(allocator, .base58, data),
        .base64 => base.decode(allocator, .base64, data),
        .base85 => base.decode(allocator, .base85, data),

        // Symmetric decryption — first base64-decode, then decrypt
        .aes_256_gcm => blk: {
            const raw = try base.base64Decode(allocator, data);
            defer allocator.free(raw);
            break :blk try symmetric.decrypt(allocator, .aes_256_gcm, raw, step.key);
        },
        .chacha20_poly1305 => blk: {
            const raw = try base.base64Decode(allocator, data);
            defer allocator.free(raw);
            break :blk try symmetric.decrypt(allocator, .chacha20_poly1305, raw, step.key);
        },
        .xchacha20_poly1305 => blk: {
            const raw = try base.base64Decode(allocator, data);
            defer allocator.free(raw);
            break :blk try symmetric.decrypt(allocator, .xchacha20_poly1305, raw, step.key);
        },
        .aes_256_cbc => blk: {
            const raw = try base.base64Decode(allocator, data);
            defer allocator.free(raw);
            break :blk try openssl.decrypt(allocator, raw, step.key);
        },

        // Hashes are irreversible
        .hash_sha256, .hash_sha512, .hash_blake3, .hash_md5 => error.IrreversibleStep,

        // JS obfuscation decodings
        .js_hex_escape => jsob.decode(allocator, .hex_escape, data),
        .js_unicode_escape => jsob.decode(allocator, .unicode_escape, data),
        .js_binary_string => jsob.decode(allocator, .binary_string, data),
        .js_jjencode => jsob.decode(allocator, .jjencode, data),
        .js_aaencode => jsob.decode(allocator, .aaencode, data),
        .js_jsfuck => jsob.decode(allocator, .jsfuck, data),
        .js_eval_wrap => jsob.decode(allocator, .eval_wrap, data),
        .js_constructor_wrap => jsob.decode(allocator, .constructor_wrap, data),
        .js_base36_tostring => jsob.decode(allocator, .base36_tostring, data),

        // Brainfuck decodings — execute the BF program, return its output
        .bf_text => bf.decodeText(allocator, data),
        .bf_emoji => bf.decodeEmoji(allocator, data),
    };
}

const AutoStepCandidate = struct {
    step_type: StepType,
    output: []u8,
};

const auto_decode_order = [_]StepType{
    .bf_emoji,
    .bf_text,
    .aes_256_cbc,
    .js_eval_wrap,
    .js_constructor_wrap,
    .js_jjencode,
    .js_aaencode,
    .js_unicode_escape,
    .js_hex_escape,
    .js_binary_string,
    .js_base36_tostring,
    .js_jsfuck,
    .aes_256_gcm,
    .chacha20_poly1305,
    .xchacha20_poly1305,
    .base16,
    .base64,
    .base32,
    .base58,
    .base85,
};

fn tryBestAutoDecodeStep(
    allocator: std.mem.Allocator,
    data: []const u8,
    key: []const u8,
    attempts: *usize,
) !?AutoStepCandidate {
    const trimmed = std.mem.trim(u8, data, " \t\r\n");
    var best: ?AutoStepCandidate = null;
    var best_score: i32 = std.math.minInt(i32);

    for (auto_decode_order) |step_type| {
        const confidence = featureConfidence(step_type, trimmed, key);
        if (confidence < 45) continue;

        attempts.* += 1;
        const next = reverseStep(allocator, .{ .step_type = step_type, .key = key }, trimmed) catch continue;
        errdefer allocator.free(next);

        if (next.len == 0 or std.mem.eql(u8, trimmed, next)) {
            allocator.free(next);
            continue;
        }

        const after_text = textQuality(next);
        const after_encoded = bestEncodedConfidence(next, key);
        if (after_text < 70 and after_encoded < 60) {
            allocator.free(next);
            continue;
        }

        var score: i32 = confidence * 4 + after_text * 2 - after_encoded;
        if (next.len < trimmed.len) score += 20;
        if (next.len > trimmed.len * 4) score -= 50;
        if (after_encoded >= 60) score += 25;

        if (score > best_score) {
            if (best) |old| allocator.free(old.output);
            best = .{ .step_type = step_type, .output = next };
            best_score = score;
        } else {
            allocator.free(next);
        }
    }

    return best;
}

fn buildAutoDecodeDescription(allocator: std.mem.Allocator, steps: []const StepType) ![]u8 {
    var buf: std.Io.Writer.Allocating = .init(allocator);
    const w = &buf.writer;
    if (steps.len == 0) {
        try w.writeAll("AI decode: no additional decoding");
        return buf.toOwnedSlice();
    }

    try w.writeAll("AI decode: ");
    for (steps, 0..) |step_type, i| {
        if (i > 0) try w.writeAll(" -> ");
        try w.writeAll("undo ");
        try w.writeAll(step_type.name());
    }
    return buf.toOwnedSlice();
}

fn bestEncodedConfidence(data: []const u8, key: []const u8) i32 {
    var best: i32 = 0;
    for (auto_decode_order) |step_type| {
        best = @max(best, featureConfidence(step_type, data, key));
    }
    return best;
}

fn featureConfidence(step_type: StepType, data_raw: []const u8, key: []const u8) i32 {
    const data = std.mem.trim(u8, data_raw, " \t\r\n");
    if (data.len == 0) return 0;

    return switch (step_type) {
        .base16 => base16Confidence(data),
        .base32 => base32Confidence(data),
        .base58 => base58Confidence(data),
        .base64 => base64Confidence(data),
        .base85 => base85Confidence(data),
        .aes_256_gcm => symmetricConfidence(data, key, 12 + 16 + 1),
        .chacha20_poly1305 => symmetricConfidence(data, key, 12 + 16 + 1),
        .xchacha20_poly1305 => symmetricConfidence(data, key, 24 + 16 + 1),
        .aes_256_cbc => opensslCbcConfidence(data),
        .js_hex_escape => if (countPattern(data, "\\x") > 0) 96 else 0,
        .js_unicode_escape => if (countPattern(data, "\\u") > 0) 98 else 0,
        .js_binary_string => binaryStringConfidence(data),
        .js_jjencode => if (std.mem.indexOf(u8, data, "$=~[];") != null and
            std.mem.indexOf(u8, data, "String.fromCharCode") != null) 98 else 0,
        .js_aaencode => if (std.mem.indexOf(u8, data, "aaencode:") != null) 98 else 0,
        .js_jsfuck => jsfuckConfidence(data),
        .js_eval_wrap => if (std.mem.startsWith(u8, data, "eval(\"") and std.mem.endsWith(u8, data, "\")")) 98 else 0,
        .js_constructor_wrap => if (std.mem.startsWith(u8, data, "[].constructor.constructor(\"return '") and std.mem.endsWith(u8, data, "'\")()")) 98 else 0,
        .js_base36_tostring => if (std.mem.indexOf(u8, data, ".toString(36)") != null) 98 else 0,
        .bf_text => if (bf.looksLikeBfText(data)) 96 else 0,
        .bf_emoji => if (bf.looksLikeBfEmoji(data)) 98 else 0,
        .hash_sha256, .hash_sha512, .hash_blake3, .hash_md5 => 0,
    };
}

fn base16Confidence(data: []const u8) i32 {
    if (data.len < 4 or data.len % 2 != 0) return 0;
    for (data) |c| {
        if (!isHex(c)) return 0;
    }
    return if (data.len >= 16) 92 else 82;
}

fn base32Confidence(data: []const u8) i32 {
    if (data.len < 8 or data.len % 8 != 0) return 0;
    var padding_seen = false;
    var has_base32_digit = false;
    for (data) |c| {
        if (c == '=') {
            padding_seen = true;
            continue;
        }
        if (padding_seen) return 0;
        if (c >= '2' and c <= '7') has_base32_digit = true;
        if (!((c >= 'A' and c <= 'Z') or (c >= 'a' and c <= 'z') or (c >= '2' and c <= '7'))) return 0;
    }
    return if (has_base32_digit or std.mem.indexOfScalar(u8, data, '=') != null) 82 else 64;
}

fn base58Confidence(data: []const u8) i32 {
    if (data.len < 8) return 0;
    for (data) |c| {
        if (!isBase58(c)) return 0;
    }
    if (base16Confidence(data) >= 80) return 40;
    return if (data.len >= 16) 68 else 56;
}

fn base64Confidence(data: []const u8) i32 {
    var clean_len: usize = 0;
    var padding_seen = false;
    var has_padding = false;
    var has_symbol = false;
    var padding_count: usize = 0;
    for (data) |c| {
        if (c == ' ' or c == '\t' or c == '\r' or c == '\n') continue;
        clean_len += 1;
        if (c == '=') {
            padding_seen = true;
            has_padding = true;
            padding_count += 1;
            continue;
        }
        if (padding_seen) return 0;
        if (c == '+' or c == '/' or c == '-' or c == '_') has_symbol = true;
        if (!((c >= 'A' and c <= 'Z') or (c >= 'a' and c <= 'z') or (c >= '0' and c <= '9') or c == '+' or c == '/' or c == '-' or c == '_')) return 0;
    }
    if (clean_len < 2 or clean_len % 4 == 1) return 0;
    if (has_padding and (clean_len % 4 != 0 or padding_count > 2)) return 0;
    if (has_padding) return 84;
    if (has_symbol) return 78;
    return if (clean_len >= 16) 72 else 64;
}

fn base85Confidence(data: []const u8) i32 {
    if (data.len < 10) return 0;
    var has_punct = false;
    for (data) |c| {
        if (!isBase85(c)) return 0;
        if (!((c >= 'A' and c <= 'Z') or (c >= 'a' and c <= 'z') or (c >= '0' and c <= '9'))) {
            has_punct = true;
        }
    }
    return if (has_punct) 66 else 46;
}

fn symmetricConfidence(data: []const u8, key: []const u8, min_raw_len: usize) i32 {
    if (key.len == 0 or base64Confidence(data) == 0) return 0;
    const approx = decodedBase64Len(data) orelse return 0;
    return if (approx >= min_raw_len) 88 else 0;
}

/// "Salted__" + 8 random salt bytes = 16 bytes whose base64 always starts
/// with "U2FsdGVkX1" — a deterministic 10-char prefix. Detection is reliable
/// even without a key, so we don't gate on key presence.
fn opensslCbcConfidence(data: []const u8) i32 {
    if (base64Confidence(data) == 0) return 0;
    if (std.mem.startsWith(u8, data, "U2FsdGVkX1")) return 99;
    return 0;
}

fn binaryStringConfidence(data: []const u8) i32 {
    var bit_count: usize = 0;
    var chunk_len: usize = 0;
    for (data) |c| {
        if (c == '0' or c == '1') {
            bit_count += 1;
            chunk_len += 1;
            if (chunk_len > 8) return 0;
        } else if (c == ' ' or c == '\n' or c == '\r' or c == '\t') {
            if (chunk_len != 0 and chunk_len != 8) return 0;
            chunk_len = 0;
        } else return 0;
    }
    if (chunk_len != 0 and chunk_len != 8) return 0;
    return if (bit_count >= 16 and bit_count % 8 == 0) 90 else 0;
}

fn jsfuckConfidence(data: []const u8) i32 {
    if (data.len < 8) return 0;
    var has_bracket = false;
    for (data) |c| {
        switch (c) {
            '[', ']', '(', ')', '!', '+', ' ' => {
                if (c == '[' or c == ']') has_bracket = true;
            },
            else => return 0,
        }
    }
    return if (has_bracket) 86 else 0;
}

fn textQuality(data: []const u8) i32 {
    if (data.len == 0) return 0;
    var printable: usize = 0;
    var controls: usize = 0;
    for (data) |c| {
        if ((c >= 32 and c <= 126) or c == '\n' or c == '\r' or c == '\t') {
            printable += 1;
        } else if (c < 32 or c == 127) {
            controls += 1;
        }
    }
    if (controls * 100 / data.len > 8) return 20;
    if (printable == data.len) return 96;
    if (std.unicode.utf8ValidateSlice(data)) return 86;
    if (printable * 100 / data.len >= 80) return 72;
    return 25;
}

fn decodedBase64Len(data: []const u8) ?usize {
    var clean_len: usize = 0;
    var padding: usize = 0;
    var padding_seen = false;
    for (data) |c| {
        if (c == ' ' or c == '\t' or c == '\r' or c == '\n') continue;
        clean_len += 1;
        if (c == '=') {
            padding_seen = true;
            padding += 1;
        } else if (padding_seen) return null;
    }
    if (clean_len % 4 == 1) return null;
    if (padding > 0 and (clean_len % 4 != 0 or padding > 2)) return null;
    return clean_len / 4 * 3 + (clean_len % 4) * 3 / 4 - padding;
}

fn countPattern(data: []const u8, pattern: []const u8) usize {
    if (pattern.len == 0) return 0;
    var count: usize = 0;
    var rest = data;
    while (std.mem.indexOf(u8, rest, pattern)) |idx| {
        count += 1;
        rest = rest[idx + pattern.len ..];
    }
    return count;
}

fn isHex(c: u8) bool {
    return (c >= '0' and c <= '9') or (c >= 'a' and c <= 'f') or (c >= 'A' and c <= 'F');
}

fn isBase58(c: u8) bool {
    return std.mem.indexOfScalar(u8, "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz", c) != null;
}

fn isBase85(c: u8) bool {
    return std.mem.indexOfScalar(u8, "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz!#$%&()*+-;<=>?@^_`{|}~", c) != null;
}

// ═══════════════════════════════════════════════════════════════════
//  Tests
// ═══════════════════════════════════════════════════════════════════

test "single base64 pipeline" {
    const allocator = std.testing.allocator;
    const steps = [_]PipelineStep{.{ .step_type = .base64 }};

    const result = try executePipeline(allocator, "Hello, World!", &steps);
    defer allocator.free(result.ciphertext);
    defer allocator.free(result.description);

    try std.testing.expectEqualStrings("SGVsbG8sIFdvcmxkIQ==", result.ciphertext);

    // Reverse
    const reversed = try executeReversePipeline(allocator, result.ciphertext, &steps);
    defer allocator.free(reversed.ciphertext);
    defer allocator.free(reversed.description);

    try std.testing.expectEqualStrings("Hello, World!", reversed.ciphertext);
}

test "nested base encoding pipeline (base64 -> base16)" {
    const allocator = std.testing.allocator;
    const steps = [_]PipelineStep{
        .{ .step_type = .base64 },
        .{ .step_type = .base16 },
    };

    const result = try executePipeline(allocator, "Hi", &steps);
    defer allocator.free(result.ciphertext);
    defer allocator.free(result.description);

    // Reverse should recover original
    const reversed = try executeReversePipeline(allocator, result.ciphertext, &steps);
    defer allocator.free(reversed.ciphertext);
    defer allocator.free(reversed.description);

    try std.testing.expectEqualStrings("Hi", reversed.ciphertext);
}

test "AES pipeline with base64 wrapping" {
    const allocator = std.testing.allocator;
    const steps = [_]PipelineStep{
        .{ .step_type = .aes_256_gcm, .key = "my-test-key" },
    };

    const result = try executePipeline(allocator, "Secret message", &steps);
    defer allocator.free(result.ciphertext);
    defer allocator.free(result.description);

    const reversed = try executeReversePipeline(allocator, result.ciphertext, &steps);
    defer allocator.free(reversed.ciphertext);
    defer allocator.free(reversed.description);

    try std.testing.expectEqualStrings("Secret message", reversed.ciphertext);
}

test "nested pipeline: base64 -> AES -> base58" {
    const allocator = std.testing.allocator;
    const steps = [_]PipelineStep{
        .{ .step_type = .base64 },
        .{ .step_type = .aes_256_gcm, .key = "test-key-123" },
        .{ .step_type = .base58 },
    };

    const result = try executePipeline(allocator, "Multi-layer encryption!", &steps);
    defer allocator.free(result.ciphertext);
    defer allocator.free(result.description);

    const reversed = try executeReversePipeline(allocator, result.ciphertext, &steps);
    defer allocator.free(reversed.ciphertext);
    defer allocator.free(reversed.description);

    try std.testing.expectEqualStrings("Multi-layer encryption!", reversed.ciphertext);
}

test "hash step is not reversible" {
    const allocator = std.testing.allocator;
    const steps = [_]PipelineStep{
        .{ .step_type = .hash_sha256 },
    };

    const result = try executePipeline(allocator, "hello", &steps);
    defer allocator.free(result.ciphertext);
    defer allocator.free(result.description);

    // Should fail to reverse
    const err = executeReversePipeline(allocator, result.ciphertext, &steps);
    try std.testing.expectError(error.IrreversibleStep, err);
}

test "pipeline description" {
    const allocator = std.testing.allocator;
    const steps = [_]PipelineStep{
        .{ .step_type = .base64 },
        .{ .step_type = .aes_256_gcm, .key = "key" },
        .{ .step_type = .base16 },
    };

    const result = try executePipeline(allocator, "test", &steps);
    defer allocator.free(result.ciphertext);
    defer allocator.free(result.description);

    try std.testing.expectEqualStrings("Base64 -> AES-256-GCM -> Base16", result.description);
}

test "auto decode nested base encodings" {
    const allocator = std.testing.allocator;
    const steps = [_]PipelineStep{
        .{ .step_type = .base64 },
        .{ .step_type = .base16 },
    };

    const encoded = try executePipeline(allocator, "layered text", &steps);
    defer allocator.free(encoded.ciphertext);
    defer allocator.free(encoded.description);

    const decoded = try autoDecode(allocator, encoded.ciphertext, &[_]PipelineStep{}, .{});
    defer decoded.deinit(allocator);

    try std.testing.expectEqualStrings("layered text", decoded.plaintext);
    try std.testing.expectEqual(@as(usize, 2), decoded.steps.len);
}

test "auto decode honors initial selected step" {
    const allocator = std.testing.allocator;
    const steps = [_]PipelineStep{.{ .step_type = .base64 }};

    const encoded = try executePipeline(allocator, "selected step", &steps);
    defer allocator.free(encoded.ciphertext);
    defer allocator.free(encoded.description);

    const decoded = try autoDecode(allocator, encoded.ciphertext, &steps, .{});
    defer decoded.deinit(allocator);

    try std.testing.expectEqualStrings("selected step", decoded.plaintext);
    try std.testing.expectEqual(@as(usize, 1), decoded.steps.len);
}

test "auto decode leaves plain text unchanged" {
    const allocator = std.testing.allocator;
    const decoded = try autoDecode(allocator, "plain text", &[_]PipelineStep{}, .{});
    defer decoded.deinit(allocator);

    try std.testing.expectEqualStrings("plain text", decoded.plaintext);
    try std.testing.expectEqual(@as(usize, 0), decoded.steps.len);
    try std.testing.expect(!decoded.still_encoded);
}

test "auto decode accepts unpadded base64" {
    const allocator = std.testing.allocator;
    const decoded = try autoDecode(allocator, "SGVsbG8", &[_]PipelineStep{}, .{});
    defer decoded.deinit(allocator);

    try std.testing.expectEqualStrings("Hello", decoded.plaintext);
    try std.testing.expectEqual(@as(usize, 1), decoded.steps.len);
}

fn expectSingleStepRoundTrip(allocator: std.mem.Allocator, step: PipelineStep, plaintext: []const u8) !void {
    const steps = [_]PipelineStep{step};
    const encoded = try executePipeline(allocator, plaintext, &steps);
    defer allocator.free(encoded.ciphertext);
    defer allocator.free(encoded.description);

    const decoded = try executeReversePipeline(allocator, encoded.ciphertext, &steps);
    defer allocator.free(decoded.ciphertext);
    defer allocator.free(decoded.description);

    try std.testing.expectEqualStrings(plaintext, decoded.ciphertext);
}

fn expectSmartDecodeWithSelectedStep(allocator: std.mem.Allocator, step: PipelineStep, plaintext: []const u8) !void {
    const steps = [_]PipelineStep{step};
    const encoded = try executePipeline(allocator, plaintext, &steps);
    defer allocator.free(encoded.ciphertext);
    defer allocator.free(encoded.description);

    const decoded = try autoDecode(allocator, encoded.ciphertext, &steps, .{
        .key = step.key,
        .max_depth = 4,
    });
    defer decoded.deinit(allocator);

    try std.testing.expectEqualStrings(plaintext, decoded.plaintext);
    try std.testing.expectEqual(@as(usize, 1), decoded.steps.len);
    try std.testing.expectEqual(step.step_type, decoded.steps[0]);
}

fn expectSmartAutoDecodeSingleStep(allocator: std.mem.Allocator, step: PipelineStep, plaintext: []const u8) !void {
    const steps = [_]PipelineStep{step};
    const encoded = try executePipeline(allocator, plaintext, &steps);
    defer allocator.free(encoded.ciphertext);
    defer allocator.free(encoded.description);

    const decoded = try autoDecode(allocator, encoded.ciphertext, &[_]PipelineStep{}, .{
        .key = step.key,
        .max_depth = 4,
    });
    defer decoded.deinit(allocator);

    try std.testing.expectEqualStrings(plaintext, decoded.plaintext);
    try std.testing.expect(decoded.steps.len >= 1);
    try std.testing.expectEqual(step.step_type, decoded.steps[0]);
}

test "all reversible single-step algorithms round-trip" {
    const allocator = std.testing.allocator;

    const no_key_steps = [_]StepType{
        .base16,
        .base32,
        .base58,
        .base64,
        .base85,
        .js_hex_escape,
        .js_unicode_escape,
        .js_binary_string,
        .js_jjencode,
        .js_aaencode,
        .js_jsfuck,
        .js_eval_wrap,
        .js_constructor_wrap,
        .js_base36_tostring,
        .bf_text,
        .bf_emoji,
    };
    const ascii_samples = [_][]const u8{ "A", "Hi", "Hello!" };

    for (no_key_steps) |step_type| {
        for (ascii_samples) |sample| {
            try expectSingleStepRoundTrip(allocator, .{ .step_type = step_type }, sample);
        }
    }

    const key_steps = [_]StepType{
        .aes_256_gcm,
        .chacha20_poly1305,
        .xchacha20_poly1305,
        .aes_256_cbc,
    };
    const utf8_samples = [_][]const u8{ "A", "Hello, VeilText!", "你好，VeilText" };

    for (key_steps) |step_type| {
        for (utf8_samples) |sample| {
            try expectSingleStepRoundTrip(allocator, .{
                .step_type = step_type,
                .key = "test-key-123",
            }, sample);
        }
    }
}

test "AI decode with selected step handles all reversible single-step algorithms" {
    const allocator = std.testing.allocator;

    const no_key_steps = [_]StepType{
        .base16,
        .base32,
        .base58,
        .base64,
        .base85,
        .js_hex_escape,
        .js_unicode_escape,
        .js_binary_string,
        .js_jjencode,
        .js_aaencode,
        .js_jsfuck,
        .js_eval_wrap,
        .js_constructor_wrap,
        .js_base36_tostring,
        .bf_text,
        .bf_emoji,
    };

    for (no_key_steps) |step_type| {
        try expectSmartDecodeWithSelectedStep(allocator, .{ .step_type = step_type }, "AI decode selected step");
    }

    const key_steps = [_]StepType{
        .aes_256_gcm,
        .chacha20_poly1305,
        .xchacha20_poly1305,
        .aes_256_cbc,
    };

    for (key_steps) |step_type| {
        try expectSmartDecodeWithSelectedStep(allocator, .{
            .step_type = step_type,
            .key = "test-key-123",
        }, "AI decode selected step");
    }
}

test "AI auto decode detects all symmetric encryption algorithms" {
    const allocator = std.testing.allocator;
    const key_steps = [_]StepType{
        .aes_256_gcm,
        .chacha20_poly1305,
        .xchacha20_poly1305,
        .aes_256_cbc,
    };

    for (key_steps) |step_type| {
        try expectSmartAutoDecodeSingleStep(allocator, .{
            .step_type = step_type,
            .key = "test-key-123",
        }, "AI auto decrypts symmetric algorithms");
    }
}
