const std = @import("std");

// ═══════════════════════════════════════════════════════════════════
//  Puzzle Split / Merge
// ═══════════════════════════════════════════════════════════════════

/// Split data into N pieces. Each piece can be independently distributed.
/// Uses simple sequential splitting with metadata header.
/// Format of each piece: [piece_index:u8][total_pieces:u8][data...]
pub fn split(allocator: std.mem.Allocator, data: []const u8, num_pieces: usize) ![][]u8 {
    if (num_pieces < 2) return error.TooFewPieces;
    if (num_pieces > 255) return error.TooManyPieces;
    if (data.len < num_pieces) return error.DataTooShort;

    const pieces = try allocator.alloc([]u8, num_pieces);
    errdefer {
        for (pieces) |p| allocator.free(p);
        allocator.free(pieces);
    }

    const chunk_size = data.len / num_pieces;
    const remainder = data.len % num_pieces;

    var offset: usize = 0;
    for (0..num_pieces) |i| {
        const this_chunk = chunk_size + (if (i < remainder) @as(usize, 1) else @as(usize, 0));
        const chunk_data = data[offset..][0..this_chunk];

        // Piece format: [index][total][data]
        const piece = try allocator.alloc(u8, 2 + this_chunk);
        piece[0] = @intCast(i);
        piece[1] = @intCast(num_pieces);
        @memcpy(piece[2..], chunk_data);

        pieces[i] = piece;
        offset += this_chunk;
    }

    return pieces;
}

/// Merge puzzle pieces back into original data.
/// Pieces can be provided in any order — they self-describe their position.
pub fn merge(allocator: std.mem.Allocator, pieces: []const []const u8) ![]u8 {
    if (pieces.len < 2) return error.TooFewPieces;

    // Validate and sort pieces by index
    const total: usize = pieces[0][1];
    if (pieces.len != total) return error.MissingPieces;

    // Create sorted array
    var sorted = try allocator.alloc(?[]const u8, total);
    defer allocator.free(sorted);
    @memset(sorted, null);

    for (pieces) |piece| {
        if (piece.len < 2) return error.InvalidPiece;
        const idx: usize = piece[0];
        const piece_total: usize = piece[1];
        if (piece_total != total) return error.InconsistentPieces;
        if (idx >= total) return error.InvalidPieceIndex;
        if (sorted[idx] != null) return error.DuplicatePiece;
        sorted[idx] = piece[2..];
    }

    // Calculate total size
    var total_size: usize = 0;
    for (sorted) |maybe_piece| {
        const piece = maybe_piece orelse return error.MissingPieces;
        total_size += piece.len;
    }

    // Assemble
    const result = try allocator.alloc(u8, total_size);
    var offset: usize = 0;
    for (sorted) |maybe_piece| {
        const piece = maybe_piece.?;
        @memcpy(result[offset..][0..piece.len], piece);
        offset += piece.len;
    }

    return result;
}

// ═══════════════════════════════════════════════════════════════════
//  Base64 Piece Encoding (for text-safe transport)
// ═══════════════════════════════════════════════════════════════════

const base64 = std.base64.standard;

/// Split and encode pieces as Base64 strings.
pub fn splitToBase64(allocator: std.mem.Allocator, data: []const u8, num_pieces: usize) ![][]u8 {
    const raw_pieces = try split(allocator, data, num_pieces);
    defer {
        for (raw_pieces) |p| allocator.free(p);
        allocator.free(raw_pieces);
    }

    const b64_pieces = try allocator.alloc([]u8, num_pieces);
    errdefer {
        for (b64_pieces) |p| allocator.free(p);
        allocator.free(b64_pieces);
    }

    for (raw_pieces, 0..) |piece, i| {
        const encoded_len = base64.Encoder.calcSize(piece.len);
        const encoded = try allocator.alloc(u8, encoded_len);
        _ = base64.Encoder.encode(encoded, piece);
        b64_pieces[i] = encoded;
    }

    return b64_pieces;
}

/// Decode Base64 pieces and merge.
pub fn mergeFromBase64(allocator: std.mem.Allocator, b64_pieces: []const []const u8) ![]u8 {
    var raw_pieces = try allocator.alloc([]u8, b64_pieces.len);
    defer {
        for (raw_pieces) |p| allocator.free(p);
        allocator.free(raw_pieces);
    }

    for (b64_pieces, 0..) |b64, i| {
        const decoded_len = base64.Decoder.calcSizeForSlice(b64) catch return error.InvalidBase64;
        const decoded = try allocator.alloc(u8, decoded_len);
        base64.Decoder.decode(decoded, b64) catch {
            allocator.free(decoded);
            return error.InvalidBase64;
        };
        raw_pieces[i] = decoded;
    }

    return try merge(allocator, raw_pieces);
}

// ═══════════════════════════════════════════════════════════════════
//  Tests
// ═══════════════════════════════════════════════════════════════════

test "split and merge round-trip" {
    const allocator = std.testing.allocator;
    const data = "Hello, this is a test message for puzzle splitting!";

    const pieces = try split(allocator, data, 3);
    defer {
        for (pieces) |p| allocator.free(p);
        allocator.free(pieces);
    }

    try std.testing.expect(pieces.len == 3);

    const merged = try merge(allocator, pieces);
    defer allocator.free(merged);

    try std.testing.expectEqualStrings(data, merged);
}

test "split and merge with different piece count" {
    const allocator = std.testing.allocator;
    const data = "ABCDEFGHIJKLMNOP";

    const pieces = try split(allocator, data, 4);
    defer {
        for (pieces) |p| allocator.free(p);
        allocator.free(pieces);
    }

    try std.testing.expect(pieces.len == 4);

    const merged = try merge(allocator, pieces);
    defer allocator.free(merged);

    try std.testing.expectEqualStrings(data, merged);
}

test "merge in shuffled order" {
    const allocator = std.testing.allocator;
    const data = "Shuffled merge test data!!";

    const pieces = try split(allocator, data, 3);
    defer {
        for (pieces) |p| allocator.free(p);
        allocator.free(pieces);
    }

    // Shuffle: [2, 0, 1]
    var shuffled: [3][]u8 = .{ pieces[2], pieces[0], pieces[1] };
    const merged = try merge(allocator, &shuffled);
    defer allocator.free(merged);

    try std.testing.expectEqualStrings(data, merged);
}

test "base64 split and merge" {
    const allocator = std.testing.allocator;
    const data = "Base64 puzzle test!";

    const b64_pieces = try splitToBase64(allocator, data, 3);
    defer {
        for (b64_pieces) |p| allocator.free(p);
        allocator.free(b64_pieces);
    }

    const merged = try mergeFromBase64(allocator, b64_pieces);
    defer allocator.free(merged);

    try std.testing.expectEqualStrings(data, merged);
}

test "too few pieces error" {
    const allocator = std.testing.allocator;
    const err = split(allocator, "hello", 1);
    try std.testing.expectError(error.TooFewPieces, err);
}

test "data too short error" {
    const allocator = std.testing.allocator;
    const err = split(allocator, "ab", 5);
    try std.testing.expectError(error.DataTooShort, err);
}
