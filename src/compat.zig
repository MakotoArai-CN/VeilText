const std = @import("std");

pub const io = std.Options.debug_io;
pub const Writer = std.Io.Writer;
pub const AllocatingWriter = std.Io.Writer.Allocating;

pub fn randomBytes(buffer: []u8) void {
    io.random(buffer);
}

pub fn timestamp() i64 {
    return std.Io.Clock.real.now(io).toSeconds();
}

pub fn milliTimestamp() i64 {
    return std.Io.Clock.real.now(io).toMilliseconds();
}

pub fn cwd() std.Io.Dir {
    return std.Io.Dir.cwd();
}

pub fn makePath(path: []const u8) !void {
    try cwd().createDirPath(io, path);
}

