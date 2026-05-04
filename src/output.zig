const std = @import("std");
const builtin = @import("builtin");
const terminal = @import("terminal.zig");

pub const TermCaps = terminal.TermCaps;

// VeilText color palette — mapped from web CSS variables to ANSI 24-bit
pub const Color = struct {
    pub const reset = "\x1b[0m";
    pub const bold = "\x1b[1m";
    pub const dim = "\x1b[2m";

    // --brand:#36c1b7
    pub const vt_cyan = "\x1b[38;2;54;193;183m";
    // --brand-deep:#148f88
    pub const vt_teal = "\x1b[38;2;20;143;136m";
    // lighter brand
    pub const vt_light = "\x1b[38;2;180;235;232m";
    // --accent:#ff8db2
    pub const vt_accent = "\x1b[38;2;255;141;178m";
    // --text-muted
    pub const vt_muted = "\x1b[38;2;99;121;124m";
    // --success:#22c55e
    pub const vt_green = "\x1b[38;2;34;197;94m";
    // --error:#ef4444
    pub const vt_red = "\x1b[38;2;239;68;68m";
    // --warn:#f59e0b
    pub const vt_yellow = "\x1b[38;2;245;158;11m";
};

fn c(caps: TermCaps, code: []const u8) []const u8 {
    return if (caps.color) code else "";
}

fn glyph(caps: TermCaps, unicode: []const u8, ascii: []const u8) []const u8 {
    return if (caps.unicode) unicode else ascii;
}

fn contentWidth(caps: TermCaps) u32 {
    const w = if (caps.width > 10) caps.width - 10 else 56;
    return std.math.clamp(w, 56, 72);
}

pub fn lineEnding() []const u8 {
    return if (builtin.os.tag == .windows) "\r\n" else "\n";
}

fn writeLineBreak(w: anytype) !void {
    try w.writeAll(lineEnding());
}

fn writeBlankLine(w: anytype) !void {
    try writeLineBreak(w);
}

fn boxTopLeft(caps: TermCaps) []const u8 {
    return if (caps.unicode) "\xe2\x95\x94" else "+";
}
fn boxTopRight(caps: TermCaps) []const u8 {
    return if (caps.unicode) "\xe2\x95\x97" else "+";
}
fn boxBottomLeft(caps: TermCaps) []const u8 {
    return if (caps.unicode) "\xe2\x95\x9a" else "+";
}
fn boxBottomRight(caps: TermCaps) []const u8 {
    return if (caps.unicode) "\xe2\x95\x9d" else "+";
}
fn boxHorizontal(caps: TermCaps) []const u8 {
    return if (caps.unicode) "\xe2\x95\x90" else "=";
}
fn boxVertical(caps: TermCaps) []const u8 {
    return if (caps.unicode) "\xe2\x95\x91" else "|";
}

pub fn displayWidth(s: []const u8) u32 {
    var width: u32 = 0;
    var i: usize = 0;
    while (i < s.len) {
        const byte = s[i];
        const seq_len: usize = if (byte < 0x80)
            1
        else if (byte < 0xE0)
            2
        else if (byte < 0xF0)
            3
        else
            4;
        if (i + seq_len > s.len) break;

        if (seq_len == 1) {
            width += 1;
        } else {
            const cp: u21 = switch (seq_len) {
                2 => @as(u21, byte & 0x1F) << 6 | @as(u21, s[i + 1] & 0x3F),
                3 => @as(u21, byte & 0x0F) << 12 | @as(u21, s[i + 1] & 0x3F) << 6 | @as(u21, s[i + 2] & 0x3F),
                4 => @as(u21, byte & 0x07) << 18 | @as(u21, s[i + 1] & 0x3F) << 12 | @as(u21, s[i + 2] & 0x3F) << 6 | @as(u21, s[i + 3] & 0x3F),
                else => 0,
            };
            width += if (isCjkWide(cp)) 2 else 1;
        }
        i += seq_len;
    }
    return width;
}

fn isCjkWide(cp: u21) bool {
    return (cp >= 0x1100 and cp <= 0x115F) or
        (cp >= 0x2E80 and cp <= 0x303E) or
        (cp >= 0x3040 and cp <= 0x33BF) or
        (cp >= 0x3400 and cp <= 0x4DBF) or
        (cp >= 0x4E00 and cp <= 0x9FFF) or
        (cp >= 0xA000 and cp <= 0xA4CF) or
        (cp >= 0xAC00 and cp <= 0xD7AF) or
        (cp >= 0xF900 and cp <= 0xFAFF) or
        (cp >= 0xFE30 and cp <= 0xFE4F) or
        (cp >= 0xFF01 and cp <= 0xFF60) or
        (cp >= 0xFFE0 and cp <= 0xFFE6) or
        (cp >= 0x20000 and cp <= 0x2FA1F);
}

pub fn printBanner(w: anytype, caps: TermCaps, version: []const u8, url: []const u8) !void {
    const inner = contentWidth(caps);
    if (caps.unicode and inner >= 48) {
        try w.print("{s}{s}", .{ c(caps, Color.vt_cyan), c(caps, Color.bold) });
        try printBoxBorder(w, caps, inner, boxTopLeft(caps), boxTopRight(caps));
        const title = "VeilText — Text Encryption Toolkit";
        try printBoxRow(w, caps, inner, title);

        // version line
        var ver_buf: [64]u8 = undefined;
        const ver_line = std.fmt.bufPrint(&ver_buf, "v{s}  \xc2\xb7  {s}", .{ version, url }) catch "VeilText";
        try printBoxRow(w, caps, inner, ver_line);

        try printBoxRow(w, caps, inner, "AES-256-GCM \xc2\xb7 ChaCha20 \xc2\xb7 BLAKE3 \xc2\xb7 Argon2");
        try printBoxBorder(w, caps, inner, boxBottomLeft(caps), boxBottomRight(caps));
        try w.print("{s}", .{c(caps, Color.reset)});
        try writeBlankLine(w);
    } else {
        try w.print("{s}{s}VeilText v{s}  {s}{s}{s}", .{
            c(caps, Color.vt_cyan),
            c(caps, Color.bold),
            version,
            url,
            c(caps, Color.reset),
            lineEnding(),
        });
        try writeBlankLine(w);
    }
}

fn printBoxBorder(w: anytype, caps: TermCaps, inner: u32, left: []const u8, right: []const u8) !void {
    try w.print("  {s}", .{left});
    var i: u32 = 0;
    while (i < inner) : (i += 1) {
        try w.print("{s}", .{boxHorizontal(caps)});
    }
    try w.print("{s}", .{right});
    try writeLineBreak(w);
}

fn printBoxRow(w: anytype, caps: TermCaps, inner: u32, content: []const u8) !void {
    const content_w = displayWidth(content);
    const padding = if (inner > content_w) inner - content_w else 0;
    const left_pad = padding / 2;
    const right_pad = padding - left_pad;

    try w.print("  {s}", .{boxVertical(caps)});
    var j: u32 = 0;
    while (j < left_pad) : (j += 1) try w.writeByte(' ');
    if (content.len > 0) try w.writeAll(content);
    var k: u32 = 0;
    while (k < right_pad) : (k += 1) try w.writeByte(' ');
    try w.print("{s}", .{boxVertical(caps)});
    try writeLineBreak(w);
}

pub fn printKeyValue(w: anytype, key: []const u8, value: []const u8, caps: TermCaps) !void {
    try w.print("  {s}{s} {s}", .{
        c(caps, Color.vt_accent),
        glyph(caps, "\xe2\x96\xb8", "-"),
        c(caps, Color.vt_muted),
    });
    try writePadded(w, key, 18);
    try w.print(" {s}{s} {s}{s}{s}", .{
        c(caps, Color.vt_teal),
        glyph(caps, "\xc2\xb7", ":"),
        c(caps, Color.vt_cyan),
        value,
        c(caps, Color.reset),
    });
    try writeLineBreak(w);
}

pub fn printSuccess(w: anytype, message: []const u8, caps: TermCaps) !void {
    try w.print("  {s}{s}{s} {s}{s}{s}", .{
        c(caps, Color.vt_green),
        c(caps, Color.bold),
        glyph(caps, "\xe2\x9c\x93", "+"),
        c(caps, Color.vt_light),
        message,
        c(caps, Color.reset),
    });
    try writeLineBreak(w);
}

pub fn printWarn(w: anytype, message: []const u8, caps: TermCaps) !void {
    try w.print("  {s}{s}{s} {s}{s}{s}", .{
        c(caps, Color.vt_yellow),
        c(caps, Color.bold),
        glyph(caps, "\xe2\x9a\xa0", "!"),
        c(caps, Color.vt_yellow),
        message,
        c(caps, Color.reset),
    });
    try writeLineBreak(w);
}

fn writePadded(w: anytype, s: []const u8, target_width: u32) !void {
    try w.writeAll(s);
    const width = displayWidth(s);
    if (width < target_width) {
        var remaining = target_width - width;
        while (remaining > 0) : (remaining -= 1) try w.writeByte(' ');
    }
}
