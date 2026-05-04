const std = @import("std");
const compat = @import("../compat.zig");
const utils = @import("../utils.zig");

// ═══════════════════════════════════════════════════════════════════
//  Encryption Record
// ═══════════════════════════════════════════════════════════════════

pub const Record = struct {
    id: []const u8,
    timestamp: []const u8,
    operation: []const u8, // "encrypt" | "decrypt" | "puzzle_split" | "puzzle_merge" | "generate"
    pipeline_desc: []const u8, // Human-readable pipeline description
    plaintext_hash: []const u8, // SHA-256 hash of original plaintext (for verification)
    ciphertext_preview: []const u8, // First N chars of ciphertext
    decrypt_hint: []const u8, // Hint for decryption (optional)
};

pub const RecordInput = struct {
    operation: []const u8,
    pipeline_desc: []const u8,
    plaintext_hash: []const u8,
    ciphertext_preview: []const u8,
};

/// Generate a unique record ID.
pub fn generateRecordId() [16]u8 {
    var raw: [8]u8 = undefined;
    compat.randomBytes(&raw);
    var hex: [16]u8 = undefined;
    const chars = "0123456789abcdef";
    for (raw, 0..) |b, i| {
        hex[i * 2] = chars[b >> 4];
        hex[i * 2 + 1] = chars[b & 0x0f];
    }
    return hex;
}

/// Serialize a record to JSON string.
pub fn toJson(allocator: std.mem.Allocator, record: Record) ![]u8 {
    var buf: std.Io.Writer.Allocating = .init(allocator);
    const w = &buf.writer;

    try w.writeAll("{\"id\":");
    try utils.writeJsonString(w, record.id);
    try w.writeAll(",\"timestamp\":");
    try utils.writeJsonString(w, record.timestamp);
    try w.writeAll(",\"operation\":");
    try utils.writeJsonString(w, record.operation);
    try w.writeAll(",\"pipeline_desc\":");
    try utils.writeJsonString(w, record.pipeline_desc);
    try w.writeAll(",\"plaintext_hash\":");
    try utils.writeJsonString(w, record.plaintext_hash);
    try w.writeAll(",\"ciphertext_preview\":");
    try utils.writeJsonString(w, record.ciphertext_preview);
    try w.writeAll(",\"decrypt_hint\":");
    try utils.writeJsonString(w, record.decrypt_hint);
    try w.writeByte('}');

    return buf.toOwnedSlice();
}

// ═══════════════════════════════════════════════════════════════════
//  Tests
// ═══════════════════════════════════════════════════════════════════

test "generateRecordId produces 16 hex chars" {
    const id = generateRecordId();
    for (id) |c| {
        try std.testing.expect((c >= '0' and c <= '9') or (c >= 'a' and c <= 'f'));
    }
}
