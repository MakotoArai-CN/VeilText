const std = @import("std");
/// Fill a buffer with cryptographically-secure random bytes.
/// Uses Zig's default secure process RNG, which is implemented per-platform
/// in stdlib and compatible with Zig 0.16 cross-target builds.
pub fn bytes(buf: []u8) void {
    std.Options.debug_io.random(buf);
}
