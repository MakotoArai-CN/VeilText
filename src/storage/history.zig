const std = @import("std");
const db_mod = @import("db.zig");
const utils = @import("../utils.zig");
const record_mod = @import("../crypto/record.zig");

// ═══════════════════════════════════════════════════════════════════
//  History Manager
// ═══════════════════════════════════════════════════════════════════

pub const HistoryRecord = struct {
    id: []const u8,
    timestamp: []const u8,
    operation: []const u8,
    pipeline_desc: []const u8,
    ciphertext_preview: []const u8,
};

pub const AddRecordInput = struct {
    operation: []const u8,
    pipeline_desc: []const u8,
    plaintext_hash: []const u8,
    ciphertext_preview: []const u8,
};

pub const History = struct {
    allocator: std.mem.Allocator,
    database: *db_mod.DB,

    pub fn init(allocator: std.mem.Allocator, database: *db_mod.DB) History {
        return .{
            .allocator = allocator,
            .database = database,
        };
    }

    pub fn deinit(self: *History) void {
        _ = self;
    }

    /// Add a new history record.
    pub fn addRecord(self: *History, input: AddRecordInput) !void {
        const id_bytes = record_mod.generateRecordId();
        const id = try self.allocator.dupe(u8, &id_bytes);
        defer self.allocator.free(id);

        var ts_buf: [19]u8 = undefined;
        const ts = utils.formatTimestamp(&ts_buf, utils.timestamp());

        // Store as: history:{id}=timestamp|operation|pipeline_desc|ciphertext_preview
        const key = try std.fmt.allocPrint(self.allocator, "history:{s}", .{id});
        defer self.allocator.free(key);

        const value = try std.fmt.allocPrint(self.allocator, "{s}|{s}|{s}|{s}", .{
            ts,
            input.operation,
            input.pipeline_desc,
            input.ciphertext_preview,
        });
        defer self.allocator.free(value);

        try self.database.put(key, value);
    }

    /// Get all history records.
    pub fn getAll(self: *History, allocator: std.mem.Allocator) ![]HistoryRecord {
        const keys = try self.database.listKeys("history:");
        defer {
            for (keys) |k| self.allocator.free(k);
            self.allocator.free(keys);
        }

        var records: std.ArrayListUnmanaged(HistoryRecord) = .empty;
        errdefer records.deinit(allocator);

        for (keys) |key| {
            const value = self.database.get(key) orelse continue;
            defer self.allocator.free(value);

            // Parse: timestamp|operation|pipeline_desc|ciphertext_preview
            var parts_it = std.mem.splitScalar(u8, value, '|');
            const timestamp = parts_it.next() orelse continue;
            const operation = parts_it.next() orelse continue;
            const pipeline_desc = parts_it.next() orelse continue;
            const ciphertext_preview = parts_it.rest();

            // Extract ID from key "history:XXXX"
            const id = if (key.len > 8) key[8..] else key;

            try records.append(allocator, .{
                .id = try allocator.dupe(u8, id),
                .timestamp = try allocator.dupe(u8, timestamp),
                .operation = try allocator.dupe(u8, operation),
                .pipeline_desc = try allocator.dupe(u8, pipeline_desc),
                .ciphertext_preview = try allocator.dupe(u8, ciphertext_preview),
            });
        }

        return records.toOwnedSlice(allocator);
    }

    /// Delete a history record by ID.
    pub fn deleteRecord(self: *History, id: []const u8) !void {
        const key = try std.fmt.allocPrint(self.allocator, "history:{s}", .{id});
        defer self.allocator.free(key);

        if (self.database.get(key) == null) return error.RecordNotFound;
        try self.database.delete(key);
    }

    /// Clear all history.
    pub fn clearAll(self: *History) !void {
        const keys = try self.database.listKeys("history:");
        defer {
            for (keys) |k| self.allocator.free(k);
            self.allocator.free(keys);
        }

        for (keys) |key| {
            self.database.delete(key) catch {};
        }
    }
};

// ═══════════════════════════════════════════════════════════════════
//  Tests
// ═══════════════════════════════════════════════════════════════════

test "History addRecord and getAll" {
    const allocator = std.testing.allocator;

    var database = try db_mod.DB.init(allocator, std.testing.io, "/tmp/veiltext-test-hist", "hist.db");
    defer database.deinit();

    var hist = History.init(allocator, &database);
    defer hist.deinit();

    try hist.addRecord(.{
        .operation = "encrypt",
        .pipeline_desc = "Base64 -> AES-256-GCM",
        .plaintext_hash = "abc123",
        .ciphertext_preview = "SGVsbG8=",
    });

    const records = try hist.getAll(allocator);
    defer {
        for (records) |r| {
            allocator.free(r.id);
            allocator.free(r.timestamp);
            allocator.free(r.operation);
            allocator.free(r.pipeline_desc);
            allocator.free(r.ciphertext_preview);
        }
        allocator.free(records);
    }

    try std.testing.expect(records.len >= 1);
}
