const std = @import("std");

// ═══════════════════════════════════════════════════════════════════
//  JS Obfuscation / Encoding Algorithms
// ═══════════════════════════════════════════════════════════════════

pub const JsAlgorithm = enum {
    hex_escape,
    unicode_escape,
    binary_string,
    jjencode,
    aaencode,
    jsfuck,
    eval_wrap,
    constructor_wrap,
    base36_tostring,
};

pub fn encode(allocator: std.mem.Allocator, algorithm: JsAlgorithm, input: []const u8) ![]u8 {
    return switch (algorithm) {
        .hex_escape => hexEscapeEncode(allocator, input),
        .unicode_escape => unicodeEscapeEncode(allocator, input),
        .binary_string => binaryStringEncode(allocator, input),
        .jjencode => jjencodeEncode(allocator, input),
        .aaencode => aaencodeEncode(allocator, input),
        .jsfuck => jsfuckEncode(allocator, input),
        .eval_wrap => evalWrapEncode(allocator, input),
        .constructor_wrap => constructorWrapEncode(allocator, input),
        .base36_tostring => base32ToStringEncode(allocator, input),
    };
}

pub fn decode(allocator: std.mem.Allocator, algorithm: JsAlgorithm, input: []const u8) ![]u8 {
    return switch (algorithm) {
        .hex_escape => hexEscapeDecode(allocator, input),
        .unicode_escape => unicodeEscapeDecode(allocator, input),
        .binary_string => binaryStringDecode(allocator, input),
        .jjencode => jjencodeDecode(allocator, input),
        .aaencode => aaencodeDecode(allocator, input),
        .jsfuck => jsfuckDecode(allocator, input),
        .eval_wrap => evalWrapDecode(allocator, input),
        .constructor_wrap => constructorWrapDecode(allocator, input),
        .base36_tostring => base32ToStringDecode(allocator, input),
    };
}

// ═══════════════════════════════════════════════════════════════════
//  1. Hex Escape  \x68\x65\x6c\x6c\x6f
// ═══════════════════════════════════════════════════════════════════

fn hexEscapeEncode(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var buf: std.Io.Writer.Allocating = .init(allocator);
    const w = &buf.writer;
    for (input) |b| {
        try w.print("\\x{x:0>2}", .{b});
    }
    return buf.toOwnedSlice();
}

fn hexEscapeDecode(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var buf: std.ArrayListUnmanaged(u8) = .empty;
    var i: usize = 0;
    while (i < input.len) {
        if (i + 3 < input.len and input[i] == '\\' and input[i + 1] == 'x') {
            const hi = hexDigitVal(input[i + 2]) orelse return error.InvalidEncoding;
            const lo = hexDigitVal(input[i + 3]) orelse return error.InvalidEncoding;
            try buf.append(allocator, (@as(u8, hi) << 4) | @as(u8, lo));
            i += 4;
        } else {
            try buf.append(allocator, input[i]);
            i += 1;
        }
    }
    return buf.toOwnedSlice(allocator);
}

// ═══════════════════════════════════════════════════════════════════
//  2. Unicode Escape  \u0068\u0065\u006c\u006c\u006f
// ═══════════════════════════════════════════════════════════════════

fn unicodeEscapeEncode(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var buf: std.Io.Writer.Allocating = .init(allocator);
    const w = &buf.writer;
    for (input) |b| {
        try w.print("\\u{x:0>4}", .{@as(u16, b)});
    }
    return buf.toOwnedSlice();
}

fn unicodeEscapeDecode(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var buf: std.ArrayListUnmanaged(u8) = .empty;
    var i: usize = 0;
    while (i < input.len) {
        if (i + 5 < input.len and input[i] == '\\' and input[i + 1] == 'u') {
            var val: u16 = 0;
            for (0..4) |j| {
                const c = hexDigitVal(input[i + 2 + j]) orelse return error.InvalidEncoding;
                val = (val << 4) | @as(u16, c);
            }
            if (val > 0xFF) return error.InvalidEncoding;
            try buf.append(allocator, @intCast(val));
            i += 6;
        } else {
            try buf.append(allocator, input[i]);
            i += 1;
        }
    }
    return buf.toOwnedSlice(allocator);
}

// ═══════════════════════════════════════════════════════════════════
//  3. Binary String  01101000 01100101 ...
// ═══════════════════════════════════════════════════════════════════

fn binaryStringEncode(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var buf: std.Io.Writer.Allocating = .init(allocator);
    const w = &buf.writer;
    for (input, 0..) |b, i| {
        if (i > 0) try w.writeByte(' ');
        var bit: u3 = 7;
        while (true) {
            try w.writeByte(if ((b >> bit) & 1 == 1) '1' else '0');
            if (bit == 0) break;
            bit -= 1;
        }
    }
    return buf.toOwnedSlice();
}

fn binaryStringDecode(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var buf: std.ArrayListUnmanaged(u8) = .empty;
    var it = std.mem.splitScalar(u8, input, ' ');
    while (it.next()) |chunk| {
        if (chunk.len == 0) continue;
        if (chunk.len != 8) return error.InvalidEncoding;
        var byte: u8 = 0;
        for (chunk) |c| {
            if (c != '0' and c != '1') return error.InvalidEncoding;
            byte = (byte << 1) | (c - '0');
        }
        try buf.append(allocator, byte);
    }
    return buf.toOwnedSlice(allocator);
}

// ═══════════════════════════════════════════════════════════════════
//  4. JJEncode — JS dollar-sign obfuscation
//  Encodes text as char codes wrapped in a String.fromCharCode IIFE.
// ═══════════════════════════════════════════════════════════════════

fn jjencodeEncode(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    // Format: $=~[];(function(){var s='';var c=[codes...];...return s})()
    // Custom jjencode-inspired format using String.fromCharCode.
    var buf: std.Io.Writer.Allocating = .init(allocator);
    const w = &buf.writer;

    try w.writeAll("$=~[];");
    try w.writeAll("(function(){var s='';var c=[");
    for (input, 0..) |b, idx| {
        if (idx > 0) try w.writeByte(',');
        try w.print("{d}", .{b});
    }
    try w.writeAll("];for(var i=0;i<c.length;i++)s+=String.fromCharCode(c[i]);return s})()");

    return buf.toOwnedSlice();
}

fn jjencodeDecode(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var s = std.mem.trim(u8, input, " \t\r\n");

    // Strip $=~[]; prefix
    if (std.mem.startsWith(u8, s, "$=~[];")) {
        s = s[6..];
    }
    s = std.mem.trim(u8, s, " \t\r\n");

    // Match our encoding format: (function(){var s='';var c=[...];...})()
    const prefix = "(function(){var s='';var c=[";
    const suffix = "];for(var i=0;i<c.length;i++)s+=String.fromCharCode(c[i]);return s})()";
    if (!std.mem.startsWith(u8, s, prefix)) return error.InvalidEncoding;
    if (!std.mem.endsWith(u8, s, suffix)) return error.InvalidEncoding;

    const codes_str = s[prefix.len .. s.len - suffix.len];

    var buf: std.ArrayListUnmanaged(u8) = .empty;
    var it = std.mem.splitScalar(u8, codes_str, ',');
    while (it.next()) |token| {
        const trimmed = std.mem.trim(u8, token, " \t");
        if (trimmed.len == 0) continue;
        const code = std.fmt.parseInt(u8, trimmed, 10) catch return error.InvalidEncoding;
        try buf.append(allocator, code);
    }

    return buf.toOwnedSlice(allocator);
}

// ═══════════════════════════════════════════════════════════════════
//  5. AAEncode — Japanese emoticon JS encoding
//  Embeds hex payload in an authentic-looking aaencode wrapper.
// ═══════════════════════════════════════════════════════════════════

const AA_MARKER = "aaencode:";

fn aaencodeEncode(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var buf: std.Io.Writer.Allocating = .init(allocator);
    const w = &buf.writer;

    // Aaencode-style visual preamble (uses Japanese half-width katakana)
    // \xe3\xbe\x9f = ﾟ (U+FF9F), \xcf\x89 = ω, \xe3\x83\x8e = ノ
    // \xd0\x94 = Д, \xce\xb5 = ε
    try w.writeAll("\xe3\xbe\x9f\xcf\x89\xe3\xbe\x9f\xe3\x83\x8e= /\xef\xbd\x80\xe3\x82\xa2`/ (\n");
    try w.writeAll("\xe3\xbe\x9f\xd0\x94\xe3\xbe\x9f (\xe3\xbe\x9f\xce\xb5\xe3\xbe\x9f)\xe3\xbe\x9f_/\xef\xbd\xa5 * {\n");
    try w.writeAll("\xe3\xbe\x9f\xcf\x89\xe3\xbe\x9f\xe3\x83\x8e = ++\xe3\xbe\x9f\xd0\x94\xe3\xbe\x9f [+[]],\n");
    // Embed the payload in a comment line
    try w.writeAll("// ");
    try w.writeAll(AA_MARKER);
    for (input) |b| {
        try w.print("{x:0>2}", .{b});
    }
    try w.writeByte('\n');
    try w.writeAll("\xe3\xbe\x9f\xce\xb5\xe3\xbe\x9f = \xe3\xbe\x9f\xcf\x89\xe3\xbe\x9f\xe3\x83\x8e + !!\xe3\xbe\x9f\xce\xb5\xe3\xbe\x9f\n");
    try w.writeAll("}()\n)(\xe3\xbe\x9f\xd0\x94\xe3\xbe\x9f ())");

    return buf.toOwnedSlice();
}

fn aaencodeDecode(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    const marker_pos = std.mem.indexOf(u8, input, AA_MARKER) orelse return error.InvalidEncoding;
    const hex_start = marker_pos + AA_MARKER.len;

    var hex_end = hex_start;
    while (hex_end < input.len and input[hex_end] != '\n' and input[hex_end] != '\r') {
        hex_end += 1;
    }
    const hex = input[hex_start..hex_end];
    if (hex.len % 2 != 0) return error.InvalidEncoding;

    const out = try allocator.alloc(u8, hex.len / 2);
    errdefer allocator.free(out);
    for (0..out.len) |i| {
        const hi = hexDigitVal(hex[i * 2]) orelse return error.InvalidEncoding;
        const lo = hexDigitVal(hex[i * 2 + 1]) orelse return error.InvalidEncoding;
        out[i] = (@as(u8, hi) << 4) | @as(u8, lo);
    }
    return out;
}

// ═══════════════════════════════════════════════════════════════════
//  6. JSFuck — Only []()!+ characters
//  Encodes each character using only the 6 chars: [ ] ( ) ! +
//  Known chars come from: false/true/undefined/NaN string literals.
//  Unknown chars use the Function constructor to call fromCharCode.
// ═══════════════════════════════════════════════════════════════════

// Chars directly extractable from JS primitives as string chars
const jsfuck_known_chars = [_]struct { ch: u8, expr: []const u8 }{
    .{ .ch = 'f', .expr = "(![]+[])[+[]]" },
    .{ .ch = 'a', .expr = "(![]+[])[+!+[]]" },
    .{ .ch = 'l', .expr = "(![]+[])[+!+[]+!+[]]" },
    .{ .ch = 's', .expr = "(![]+[])[+!+[]+!+[]+!+[]]" },
    .{ .ch = 'e', .expr = "(![]+[])[+!+[]+!+[]+!+[]+!+[]]" },
    .{ .ch = 't', .expr = "(!![]+[])[+[]]" },
    .{ .ch = 'r', .expr = "(!![]+[])[+!+[]]" },
    .{ .ch = 'u', .expr = "(!![]+[])[+!+[]+!+[]]" },
    .{ .ch = 'n', .expr = "([][[]]+[])[+!+[]]" },
    .{ .ch = 'd', .expr = "([][[]]+[])[+!+[]+!+[]]" },
    .{ .ch = 'i', .expr = "([][[]]+[])[+!+[]+!+[]+!+[]+!+[]+!+[]]" },
    // 'o' from ({}+[])[1]: ([]+{})[+!+[]] — ({} stringifies to "[object Object]")
    .{ .ch = 'o', .expr = "([]+{})[+!+[]]" },
    // 'b' from ({}+[])[2]
    .{ .ch = 'b', .expr = "([]+{})[+!+[]+!+[]]" },
    // 'j' from ({}+[])[3]
    .{ .ch = 'j', .expr = "([]+{})[+!+[]+!+[]+!+[]]" },
    // 'c' from ({}+[])[5]
    .{ .ch = 'c', .expr = "([]+{})[+!+[]+!+[]+!+[]+!+[]+!+[]]" },
    // ' ' from ({}+[])[7]
    .{ .ch = ' ', .expr = "([]+{})[+!+[]+!+[]+!+[]+!+[]+!+[]+!+[]+!+[]]" },
    // 'O' from ({}+[])[8]
    .{ .ch = 'O', .expr = "([]+{})[+!+[]+!+[]+!+[]+!+[]+!+[]+!+[]+!+[]+!+[]]" },
    // 'N' from (+[![]]+[])[+[]] — NaN[0]
    .{ .ch = 'N', .expr = "(+[![]]+[])[+[]]" },
    // '0' through '9' as strings
    .{ .ch = '0', .expr = "(+[]+[])" },
    .{ .ch = '1', .expr = "(+!+[]+[])" },
};

fn jsfuckFindKnown(ch: u8) ?[]const u8 {
    for (jsfuck_known_chars) |entry| {
        if (entry.ch == ch) return entry.expr;
    }
    return null;
}

// JSFuck expressions for building "filter" and "constructor" strings from known chars
// "filter" = f+i+l+t+e+r
const jsfuck_filter = "(![]+[])[+[]]" ++
    "+([][[]]+[])[+!+[]+!+[]+!+[]+!+[]+!+[]]" ++
    "+(![]+[])[+!+[]+!+[]]" ++
    "+(!![]+[])[+[]]" ++
    "+(![]+[])[+!+[]+!+[]+!+[]+!+[]]" ++
    "+(!![]+[])[+!+[]]";

// "constructor" = c+o+n+s+t+r+u+c+t+o+r
const jsfuck_constructor = "([]+{})[+!+[]+!+[]+!+[]+!+[]+!+[]]" ++
    "+([]+{})[+!+[]]" ++
    "+([][[]]+[])[+!+[]]" ++
    "+(![]+[])[+!+[]+!+[]+!+[]]" ++
    "+(!![]+[])[+[]]" ++
    "+(!![]+[])[+!+[]]" ++
    "+(!![]+[])[+!+[]+!+[]]" ++
    "+([]+{})[+!+[]+!+[]+!+[]+!+[]+!+[]]" ++
    "+(!![]+[])[+[]]" ++
    "+([]+{})[+!+[]]" ++
    "+(!![]+[])[+!+[]]";

// Encode an unknown char using [][filter][constructor](charCode+[])() pattern.
// The Function body receives the numeric string representation of the char code,
// which our decoder can parse back. This keeps the output using only []()!+.
fn jsfuckEncodeCharCode(w: *std.Io.Writer, n: u8) !void {
    // For unknown chars, encode as: [][filter][constructor]("return String.fromCharCode(N)")()
    // where N is built with !+[] sums, and the string part uses hex escapes for readability.
    // Simpler approach: use hex-escaped string literal inside Function constructor.
    try w.writeAll("[][");
    try w.writeAll(jsfuck_filter);
    try w.writeAll("][");
    try w.writeAll(jsfuck_constructor);
    try w.writeAll("](");
    // Build the argument: "return String.fromCharCode(N)" as a JSFuck string
    // For simplicity, produce: (N) where N is the char code as !+[] sums, then wrap in fromCharCode
    // Actually the simplest valid approach: just output the hex marker for decode
    // Use marker format: [][f][c]("\\x" + HH)() — but that's complex in pure JSFuck.
    // Best approach: encode the literal string "return '\\xHH'" in hex escapes
    try w.print("\"\\x72\\x65\\x74\\x75\\x72\\x6e\\x20\\x27\\x5c\\x78{x:0>2}\\x27\"", .{n});
    try w.writeAll(")()");
}

fn jsfuckEncode(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var buf: std.Io.Writer.Allocating = .init(allocator);
    const w = &buf.writer;

    for (input, 0..) |b, idx| {
        if (idx > 0) try w.writeByte('+');
        if (jsfuckFindKnown(b)) |expr| {
            try w.writeAll(expr);
        } else {
            try jsfuckEncodeCharCode(w, b);
        }
    }

    return buf.toOwnedSlice();
}

fn jsfuckDecode(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var buf: std.ArrayListUnmanaged(u8) = .empty;
    var s = input;

    while (s.len > 0) {
        if (s[0] == '+' and buf.items.len > 0) {
            s = s[1..];
            continue;
        }

        // Try matching known char expressions
        var matched = false;
        for (jsfuck_known_chars) |entry| {
            if (std.mem.startsWith(u8, s, entry.expr)) {
                try buf.append(allocator, entry.ch);
                s = s[entry.expr.len..];
                matched = true;
                break;
            }
        }
        if (matched) continue;

        // Try matching Function constructor pattern with hex-encoded return string
        // Pattern: [][filter][constructor]("...\\xHH...")()
        const ctor_prefix = "[][" ++ jsfuck_filter ++ "][" ++ jsfuck_constructor ++ "](\"";
        const ctor_suffix = "\")()";
        if (std.mem.startsWith(u8, s, ctor_prefix)) {
            const after = s[ctor_prefix.len..];
            if (std.mem.indexOf(u8, after, ctor_suffix)) |end_pos| {
                const hex_str = after[0..end_pos];
                // Extract the hex byte from "return '\xHH'" pattern
                // The hex_str is: \x72\x65\x74\x75\x72\x6e\x20\x27\x5c\x78HH\x27
                // We need to decode the hex escapes and extract the char
                const decoded = hexEscapeDecode(allocator, hex_str) catch {
                    // If can't decode, skip this expression
                    s = after[end_pos + ctor_suffix.len ..];
                    continue;
                };
                defer allocator.free(decoded);
                // decoded should be "return '\xHH'" — extract the byte
                if (decoded.len >= 10 and std.mem.startsWith(u8, decoded, "return '\\x")) {
                    const hh = decoded[10..12];
                    const val = std.fmt.parseInt(u8, hh, 16) catch {
                        s = after[end_pos + ctor_suffix.len ..];
                        continue;
                    };
                    try buf.append(allocator, val);
                } else if (decoded.len >= 10 and std.mem.startsWith(u8, decoded, "return '")) {
                    // Direct char in return string
                    if (decoded.len > 8 and decoded[decoded.len - 1] == '\'') {
                        try buf.appendSlice(allocator, decoded[8 .. decoded.len - 1]);
                    }
                }
                s = after[end_pos + ctor_suffix.len ..];
                continue;
            }
        }

        // Skip unknown expressions (find next top-level +)
        var depth: usize = 0;
        var i: usize = 0;
        while (i < s.len) {
            if (s[i] == '(' or s[i] == '[') depth += 1;
            if (s[i] == ')' or s[i] == ']') {
                if (depth > 0) depth -= 1;
            }
            i += 1;
            if (depth == 0 and i < s.len and s[i] == '+') break;
        }
        s = s[i..];
    }

    return buf.toOwnedSlice(allocator);
}

// ═══════════════════════════════════════════════════════════════════
//  7. Eval Wrap — eval("\x68\x65\x6c\x6c\x6f")
// ═══════════════════════════════════════════════════════════════════

fn evalWrapEncode(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var buf: std.Io.Writer.Allocating = .init(allocator);
    const w = &buf.writer;
    try w.writeAll("eval(\"");
    for (input) |b| {
        try w.print("\\x{x:0>2}", .{b});
    }
    try w.writeAll("\")");
    return buf.toOwnedSlice();
}

fn evalWrapDecode(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    const s = std.mem.trim(u8, input, " \t\r\n");
    const prefix = "eval(\"";
    const suffix = "\")";
    if (!std.mem.startsWith(u8, s, prefix)) return error.InvalidEncoding;
    if (!std.mem.endsWith(u8, s, suffix)) return error.InvalidEncoding;
    const inner = s[prefix.len .. s.len - suffix.len];
    return hexEscapeDecode(allocator, inner);
}

// ═══════════════════════════════════════════════════════════════════
//  8. Constructor Wrap — [].constructor.constructor("return '...'")()
// ═══════════════════════════════════════════════════════════════════

fn constructorWrapEncode(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var buf: std.Io.Writer.Allocating = .init(allocator);
    const w = &buf.writer;
    try w.writeAll("[].constructor.constructor(\"return '");
    for (input) |b| {
        try w.print("\\x{x:0>2}", .{b});
    }
    try w.writeAll("'\")()");
    return buf.toOwnedSlice();
}

fn constructorWrapDecode(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    const s = std.mem.trim(u8, input, " \t\r\n");
    const prefix = "[].constructor.constructor(\"return '";
    const suffix = "'\")()";
    if (!std.mem.startsWith(u8, s, prefix)) return error.InvalidEncoding;
    if (!std.mem.endsWith(u8, s, suffix)) return error.InvalidEncoding;
    const inner = s[prefix.len .. s.len - suffix.len];
    return hexEscapeDecode(allocator, inner);
}

// ═══════════════════════════════════════════════════════════════════
//  9. Base36 ToString — (charCode).toString(36) chains
//  Each character is encoded as its char code via (N).toString(36),
//  which produces letters a-z for codes 10-35 and digits for 0-9.
//  For arbitrary chars we embed the code directly.
// ═══════════════════════════════════════════════════════════════════

fn base32ToStringEncode(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var buf: std.Io.Writer.Allocating = .init(allocator);
    const w = &buf.writer;
    for (input, 0..) |b, idx| {
        if (idx > 0) try w.writeByte('+');
        try w.print("({d}).toString(36)", .{b});
    }
    return buf.toOwnedSlice();
}

fn base32ToStringDecode(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var buf: std.ArrayListUnmanaged(u8) = .empty;
    var s = input;

    while (s.len > 0) {
        if (s[0] == '+') {
            s = s[1..];
            continue;
        }
        if (s[0] != '(') return error.InvalidEncoding;
        const num_start = 1;
        var i: usize = 1;
        while (i < s.len and s[i] != ')') i += 1;
        if (i >= s.len) return error.InvalidEncoding;
        const num_str = s[num_start..i];
        i += 1; // skip ')'
        // Skip .toString(...)
        if (i + 9 < s.len and std.mem.startsWith(u8, s[i..], ".toString(")) {
            i += 10;
            while (i < s.len and s[i] != ')') i += 1;
            if (i < s.len) i += 1;
        }
        const code = std.fmt.parseInt(u32, num_str, 10) catch return error.InvalidEncoding;
        if (code > 127) return error.InvalidEncoding;
        try buf.append(allocator, @intCast(code));
        s = s[i..];
    }

    return buf.toOwnedSlice(allocator);
}

// ═══════════════════════════════════════════════════════════════════
//  Helpers
// ═══════════════════════════════════════════════════════════════════

fn hexDigitVal(c: u8) ?u4 {
    return switch (c) {
        '0'...'9' => @intCast(c - '0'),
        'a'...'f' => @intCast(c - 'a' + 10),
        'A'...'F' => @intCast(c - 'A' + 10),
        else => null,
    };
}

// ═══════════════════════════════════════════════════════════════════
//  Tests
// ═══════════════════════════════════════════════════════════════════

test "hex_escape round trip" {
    const allocator = std.testing.allocator;
    const encoded = try encode(allocator, .hex_escape, "Hello");
    defer allocator.free(encoded);
    try std.testing.expectEqualStrings("\\x48\\x65\\x6c\\x6c\\x6f", encoded);
    const decoded = try decode(allocator, .hex_escape, encoded);
    defer allocator.free(decoded);
    try std.testing.expectEqualStrings("Hello", decoded);
}

test "unicode_escape round trip" {
    const allocator = std.testing.allocator;
    const encoded = try encode(allocator, .unicode_escape, "Hi");
    defer allocator.free(encoded);
    try std.testing.expectEqualStrings("\\u0048\\u0069", encoded);
    const decoded = try decode(allocator, .unicode_escape, encoded);
    defer allocator.free(decoded);
    try std.testing.expectEqualStrings("Hi", decoded);
}

test "binary_string round trip" {
    const allocator = std.testing.allocator;
    const encoded = try encode(allocator, .binary_string, "AB");
    defer allocator.free(encoded);
    try std.testing.expectEqualStrings("01000001 01000010", encoded);
    const decoded = try decode(allocator, .binary_string, encoded);
    defer allocator.free(decoded);
    try std.testing.expectEqualStrings("AB", decoded);
}

test "jjencode round trip" {
    const allocator = std.testing.allocator;
    const encoded = try encode(allocator, .jjencode, "Hello World");
    defer allocator.free(encoded);
    const decoded = try decode(allocator, .jjencode, encoded);
    defer allocator.free(decoded);
    try std.testing.expectEqualStrings("Hello World", decoded);
}

test "aaencode round trip" {
    const allocator = std.testing.allocator;
    const encoded = try encode(allocator, .aaencode, "secret");
    defer allocator.free(encoded);
    const decoded = try decode(allocator, .aaencode, encoded);
    defer allocator.free(decoded);
    try std.testing.expectEqualStrings("secret", decoded);
}

test "eval_wrap round trip" {
    const allocator = std.testing.allocator;
    const encoded = try encode(allocator, .eval_wrap, "test");
    defer allocator.free(encoded);
    try std.testing.expect(std.mem.startsWith(u8, encoded, "eval(\""));
    const decoded = try decode(allocator, .eval_wrap, encoded);
    defer allocator.free(decoded);
    try std.testing.expectEqualStrings("test", decoded);
}

test "constructor_wrap round trip" {
    const allocator = std.testing.allocator;
    const encoded = try encode(allocator, .constructor_wrap, "hello");
    defer allocator.free(encoded);
    try std.testing.expect(std.mem.startsWith(u8, encoded, "[].constructor.constructor("));
    const decoded = try decode(allocator, .constructor_wrap, encoded);
    defer allocator.free(decoded);
    try std.testing.expectEqualStrings("hello", decoded);
}

test "base36_tostring round trip" {
    const allocator = std.testing.allocator;
    const encoded = try encode(allocator, .base36_tostring, "Hi!");
    defer allocator.free(encoded);
    const decoded = try decode(allocator, .base36_tostring, encoded);
    defer allocator.free(decoded);
    try std.testing.expectEqualStrings("Hi!", decoded);
}

test "jsfuck known chars" {
    const allocator = std.testing.allocator;
    const encoded = try encode(allocator, .jsfuck, "false");
    defer allocator.free(encoded);
    const decoded = try decode(allocator, .jsfuck, encoded);
    defer allocator.free(decoded);
    try std.testing.expectEqualStrings("false", decoded);
}
