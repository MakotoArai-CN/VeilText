const std = @import("std");
const builtin = @import("builtin");
const compat = @import("compat.zig");

pub const TermCaps = struct {
    color: bool = false,
    unicode: bool = false,
    width: u32 = 80,

    pub fn detect(environ_map: *const std.process.Environ.Map) TermCaps {
        var caps = TermCaps{};
        switch (builtin.os.tag) {
            .windows => detectWindows(&caps),
            else => detectPosix(&caps),
        }
        if (environ_map.get("NO_COLOR")) |_| {
            caps.color = false;
        }
        return caps;
    }
};

fn detectWindows(caps: *TermCaps) void {
    const windows = std.os.windows;
    const k32 = struct {
        const CONSOLE_SCREEN_BUFFER_INFO = extern struct {
            dwSize: extern struct { X: i16, Y: i16 },
            dwCursorPosition: extern struct { X: i16, Y: i16 },
            wAttributes: u16,
            srWindow: extern struct { Left: i16, Top: i16, Right: i16, Bottom: i16 },
            dwMaximumWindowSize: extern struct { X: i16, Y: i16 },
        };

        extern "kernel32" fn GetStdHandle(nStdHandle: windows.DWORD) callconv(.winapi) ?windows.HANDLE;
        extern "kernel32" fn GetConsoleMode(hConsole: windows.HANDLE, lpMode: *windows.DWORD) callconv(.winapi) windows.BOOL;
        extern "kernel32" fn SetConsoleMode(hConsole: windows.HANDLE, dwMode: windows.DWORD) callconv(.winapi) windows.BOOL;
        extern "kernel32" fn SetConsoleOutputCP(wCodePageID: windows.UINT) callconv(.winapi) windows.BOOL;
        extern "kernel32" fn GetConsoleScreenBufferInfo(hConsole: windows.HANDLE, lpInfo: *CONSOLE_SCREEN_BUFFER_INFO) callconv(.winapi) windows.BOOL;
    };

    const STD_OUTPUT_HANDLE: windows.DWORD = @bitCast(@as(i32, -11));
    const ENABLE_VIRTUAL_TERMINAL_PROCESSING: windows.DWORD = 0x0004;

    const handle = k32.GetStdHandle(STD_OUTPUT_HANDLE) orelse return;
    var mode: windows.DWORD = 0;
    if (!k32.GetConsoleMode(handle, &mode).toBool()) return;

    if (k32.SetConsoleMode(handle, mode | ENABLE_VIRTUAL_TERMINAL_PROCESSING).toBool()) {
        caps.color = true;
    }
    if (k32.SetConsoleOutputCP(65001).toBool()) {
        caps.unicode = true;
    }

    var csbi: k32.CONSOLE_SCREEN_BUFFER_INFO = undefined;
    if (k32.GetConsoleScreenBufferInfo(handle, &csbi).toBool()) {
        const width = csbi.srWindow.Right - csbi.srWindow.Left + 1;
        if (width > 0) caps.width = @intCast(width);
    }
}

fn detectPosix(caps: *TermCaps) void {
    const fd = std.posix.STDOUT_FILENO;
    if (!(std.Io.File.stdout().isTty(compat.io) catch return)) return;
    caps.color = true;
    caps.unicode = true;

    var ws: std.posix.winsize = undefined;
    const rc = std.posix.system.ioctl(fd, std.posix.T.IOCGWINSZ, @intFromPtr(&ws));
    const ok = if (@TypeOf(rc) == usize) (@as(isize, @bitCast(rc)) == 0) else (rc == 0);
    if (ok and ws.col > 0) caps.width = ws.col;
}
