const std = @import("std");

// ═══════════════════════════════════════════════════════════════════
//  Append-Only Key-Value Store (inspired by VeilDB)
//
//  File format:
//    [key_len:u16][value_len:u32][key][value][\n]
//    ...
//
//  On read, later entries override earlier ones (last-write-wins).
//  Compact: rewrite file with only latest values.
// ═══════════════════════════════════════════════════════════════════

pub const DB = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    data_dir: []const u8,
    db_file: []const u8,
    cache: std.StringHashMap([]u8),

    pub fn init(allocator: std.mem.Allocator, io: std.Io, data_dir: []const u8, db_file: []const u8) !DB {
        var db = DB{
            .allocator = allocator,
            .io = io,
            .data_dir = data_dir,
            .db_file = db_file,
            .cache = std.StringHashMap([]u8).init(allocator),
        };
        db.load() catch {}; // OK if file doesn't exist yet
        return db;
    }

    pub fn deinit(self: *DB) void {
        var it = self.cache.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.cache.deinit();
    }

    /// Get a value by key. Returns a copy (caller owns).
    pub fn get(self: *DB, key: []const u8) ?[]u8 {
        const val = self.cache.get(key) orelse return null;
        return self.allocator.dupe(u8, val) catch null;
    }

    /// Put a key-value pair. Writes to cache + appends to file.
    pub fn put(self: *DB, key: []const u8, value: []const u8) !void {
        // Update cache
        const key_copy = try self.allocator.dupe(u8, key);
        const val_copy = try self.allocator.dupe(u8, value);

        if (self.cache.fetchPut(key_copy, val_copy) catch null) |old| {
            self.allocator.free(key_copy);
            self.allocator.free(old.value);
        }

        // Append to file
        try self.appendToFile(key, value);
    }

    /// Delete a key by writing an empty value marker.
    pub fn delete(self: *DB, key: []const u8) !void {
        if (self.cache.fetchRemove(key)) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value);
        }
        // Write tombstone
        try self.appendToFile(key, "");
    }

    /// List all keys matching a prefix.
    pub fn listKeys(self: *DB, prefix: []const u8) ![][]u8 {
        var keys: std.ArrayListUnmanaged([]u8) = .empty;
        errdefer {
            for (keys.items) |k| self.allocator.free(k);
            keys.deinit(self.allocator);
        }

        var it = self.cache.iterator();
        while (it.next()) |entry| {
            if (std.mem.startsWith(u8, entry.key_ptr.*, prefix)) {
                try keys.append(self.allocator, try self.allocator.dupe(u8, entry.key_ptr.*));
            }
        }

        return keys.toOwnedSlice(self.allocator);
    }

    // ═════════════════════════════════════════════════════════════
    //  File I/O
    // ═════════════════════════════════════════════════════════════

    fn getFilePath(self: *DB) ![]u8 {
        return std.fmt.allocPrint(self.allocator, "{s}/{s}", .{ self.data_dir, self.db_file });
    }

    fn load(self: *DB) !void {
        const path = try self.getFilePath();
        defer self.allocator.free(path);

        const file = std.Io.Dir.cwd().openFile(self.io, path, .{}) catch return;
        defer file.close(self.io);

        var read_buf: [8192]u8 = undefined;
        var fr = file.reader(self.io, &read_buf);
        const content = fr.interface.allocRemaining(self.allocator, .limited(100 * 1024 * 1024)) catch return;
        defer self.allocator.free(content);

        // Parse line-delimited JSON entries
        var it = std.mem.splitScalar(u8, content, '\n');
        while (it.next()) |line| {
            if (line.len < 3) continue; // minimum: "k=v"

            // Format: key=value (simple text format)
            if (std.mem.indexOfScalar(u8, line, '=')) |sep| {
                const key = line[0..sep];
                const value = line[sep + 1 ..];

                const key_copy = self.allocator.dupe(u8, key) catch continue;
                const val_copy = self.allocator.dupe(u8, value) catch {
                    self.allocator.free(key_copy);
                    continue;
                };

                if (value.len == 0) {
                    // Tombstone: delete
                    if (self.cache.fetchRemove(key)) |old| {
                        self.allocator.free(old.key);
                        self.allocator.free(old.value);
                    }
                    self.allocator.free(key_copy);
                    self.allocator.free(val_copy);
                } else {
                    if (self.cache.fetchPut(key_copy, val_copy) catch null) |old| {
                        self.allocator.free(key_copy);
                        self.allocator.free(old.value);
                    }
                }
            }
        }
    }

    fn appendToFile(self: *DB, key: []const u8, value: []const u8) !void {
        const path = try self.getFilePath();
        defer self.allocator.free(path);

        // Ensure directory exists
        std.Io.Dir.cwd().createDirPath(self.io, self.data_dir) catch {};

        const file = std.Io.Dir.cwd().openFile(self.io, path, .{ .mode = .write_only }) catch blk: {
            break :blk try std.Io.Dir.cwd().createFile(self.io, path, .{});
        };
        defer file.close(self.io);

        // Write: key=value\n
        var write_buf: [4096]u8 = undefined;
        var w = file.writer(self.io, &write_buf);
        if (file.stat(self.io)) |stat| {
            w.seekTo(stat.size) catch {};
        } else |_| {}
        w.interface.writeAll(key) catch return;
        w.interface.writeAll("=") catch return;
        w.interface.writeAll(value) catch return;
        w.interface.writeAll("\n") catch return;
        w.interface.flush() catch return;
    }

    /// Compact the database file by rewriting only current values.
    pub fn compact(self: *DB) !void {
        const path = try self.getFilePath();
        defer self.allocator.free(path);

        const tmp_path = try std.fmt.allocPrint(self.allocator, "{s}.tmp", .{path});
        defer self.allocator.free(tmp_path);

        const file = try std.Io.Dir.cwd().createFile(self.io, tmp_path, .{});
        defer file.close(self.io);

        var write_buf: [4096]u8 = undefined;
        var w = file.writer(self.io, &write_buf);

        var it = self.cache.iterator();
        while (it.next()) |entry| {
            w.interface.writeAll(entry.key_ptr.*) catch return;
            w.interface.writeAll("=") catch return;
            w.interface.writeAll(entry.value_ptr.*) catch return;
            w.interface.writeAll("\n") catch return;
        }
        w.interface.flush() catch return;

        // Atomic rename
        const cwd_dir = std.Io.Dir.cwd();
        cwd_dir.rename(tmp_path, cwd_dir, path, self.io) catch {
            // Fallback: delete old, rename new
            cwd_dir.deleteFile(self.io, path) catch {};
            cwd_dir.rename(tmp_path, cwd_dir, path, self.io) catch return error.CompactFailed;
        };
    }
};

// ═══════════════════════════════════════════════════════════════════
//  Tests
// ═══════════════════════════════════════════════════════════════════

test "DB put and get" {
    const allocator = std.testing.allocator;

    // Use temp directory
    var db = try DB.init(allocator, std.testing.io, "/tmp/veiltext-test-db", "test.db");
    defer db.deinit();

    try db.put("key1", "value1");
    try db.put("key2", "value2");

    const v1 = db.get("key1");
    defer if (v1) |v| allocator.free(v);
    try std.testing.expect(v1 != null);
    try std.testing.expectEqualStrings("value1", v1.?);

    const v2 = db.get("key2");
    defer if (v2) |v| allocator.free(v);
    try std.testing.expectEqualStrings("value2", v2.?);

    // Non-existent key
    try std.testing.expect(db.get("nonexistent") == null);
}

test "DB overwrite" {
    const allocator = std.testing.allocator;
    var db = try DB.init(allocator, std.testing.io, "/tmp/veiltext-test-db2", "test2.db");
    defer db.deinit();

    try db.put("k", "old");
    try db.put("k", "new");

    const val = db.get("k");
    defer if (val) |v| allocator.free(v);
    try std.testing.expectEqualStrings("new", val.?);
}

test "DB delete" {
    const allocator = std.testing.allocator;
    var db = try DB.init(allocator, std.testing.io, "/tmp/veiltext-test-db3", "test3.db");
    defer db.deinit();

    try db.put("dk", "val");
    try db.delete("dk");
    try std.testing.expect(db.get("dk") == null);
}

test "DB listKeys" {
    const allocator = std.testing.allocator;
    var db = try DB.init(allocator, std.testing.io, "/tmp/veiltext-test-db4", "test4.db");
    defer db.deinit();

    try db.put("history:001", "a");
    try db.put("history:002", "b");
    try db.put("settings:theme", "dark");

    const keys = try db.listKeys("history:");
    defer {
        for (keys) |k| allocator.free(k);
        allocator.free(keys);
    }
    try std.testing.expect(keys.len == 2);
}
