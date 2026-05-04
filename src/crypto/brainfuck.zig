const std = @import("std");

// ═══════════════════════════════════════════════════════════════════
//  Brainfuck Interpreter + Encoder
//
//  Native Zig implementation: VM, optimizing compiler, text encoder
//  (plaintext -> BF code that prints the plaintext when executed),
//  and an emoji codec that maps the 8 BF instructions to 8 emojis.
//
//  The emoji variant lets BF code travel through media that strip
//  ASCII punctuation, and makes the format opaque without our decoder.
// ═══════════════════════════════════════════════════════════════════

const MEMORY_SIZE: usize = 30000;
const MAX_STEPS: u64 = 50_000_000;

pub const BfError = error{
    UnmatchedBracket,
    StepLimitExceeded,
};

pub const Op = enum(u8) {
    move_ptr,     // > or < combined, arg = signed displacement
    add_val,      // + or - combined, arg = signed delta
    output,       // .
    input,        // ,
    jump_zero,    // [ - if cell == 0, ip = jump
    jump_nonzero, // ] - if cell != 0, ip = jump
    set_zero,     // [-] / [+] optimized to a direct clear
};

pub const Inst = struct {
    op: Op,
    arg: i32 = 0,
    jump: usize = 0,
};

pub const Program = struct {
    insts: []Inst,

    pub fn deinit(self: Program, allocator: std.mem.Allocator) void {
        allocator.free(self.insts);
    }
};

// ─── Compiler ──────────────────────────────────────────────────────

pub fn compile(allocator: std.mem.Allocator, source: []const u8) !Program {
    var insts: std.ArrayListUnmanaged(Inst) = .empty;
    errdefer insts.deinit(allocator);

    var jump_stack: std.ArrayListUnmanaged(usize) = .empty;
    defer jump_stack.deinit(allocator);

    var i: usize = 0;
    while (i < source.len) : (i += 1) {
        const c = source[i];
        switch (c) {
            '>', '<' => {
                var count: i32 = 0;
                while (i < source.len and (source[i] == '>' or source[i] == '<')) : (i += 1) {
                    count += if (source[i] == '>') @as(i32, 1) else @as(i32, -1);
                }
                i -= 1;
                if (count != 0) {
                    try insts.append(allocator, .{ .op = .move_ptr, .arg = count });
                }
            },
            '+', '-' => {
                var count: i32 = 0;
                while (i < source.len and (source[i] == '+' or source[i] == '-')) : (i += 1) {
                    count += if (source[i] == '+') @as(i32, 1) else @as(i32, -1);
                }
                i -= 1;
                if (count != 0) {
                    try insts.append(allocator, .{ .op = .add_val, .arg = count });
                }
            },
            '.' => try insts.append(allocator, .{ .op = .output }),
            ',' => try insts.append(allocator, .{ .op = .input }),
            '[' => {
                if (i + 2 < source.len and (source[i + 1] == '-' or source[i + 1] == '+') and source[i + 2] == ']') {
                    try insts.append(allocator, .{ .op = .set_zero });
                    i += 2;
                } else {
                    try jump_stack.append(allocator, insts.items.len);
                    try insts.append(allocator, .{ .op = .jump_zero });
                }
            },
            ']' => {
                if (jump_stack.items.len == 0) return BfError.UnmatchedBracket;
                const open_idx = jump_stack.items[jump_stack.items.len - 1];
                jump_stack.items.len -= 1;
                const close_idx = insts.items.len;
                insts.items[open_idx].jump = close_idx;
                try insts.append(allocator, .{ .op = .jump_nonzero, .jump = open_idx });
            },
            else => {}, // ignore comments and whitespace
        }
    }

    if (jump_stack.items.len > 0) return BfError.UnmatchedBracket;

    return .{ .insts = try insts.toOwnedSlice(allocator) };
}

// ─── VM execution ──────────────────────────────────────────────────

pub fn run(allocator: std.mem.Allocator, source: []const u8, input: []const u8) ![]u8 {
    const prog = try compile(allocator, source);
    defer prog.deinit(allocator);

    var memory = [_]u8{0} ** MEMORY_SIZE;
    var ptr: usize = 0;
    var input_pos: usize = 0;

    var output: std.ArrayListUnmanaged(u8) = .empty;
    errdefer output.deinit(allocator);

    var steps: u64 = 0;
    var ip: usize = 0;

    while (ip < prog.insts.len) {
        steps += 1;
        if (steps > MAX_STEPS) return BfError.StepLimitExceeded;

        const inst = prog.insts[ip];
        switch (inst.op) {
            .move_ptr => {
                const new_ptr = @as(i64, @intCast(ptr)) + @as(i64, inst.arg);
                ptr = @intCast(@mod(new_ptr, @as(i64, MEMORY_SIZE)));
            },
            .add_val => {
                const v = @as(i32, memory[ptr]) + inst.arg;
                memory[ptr] = @intCast(@mod(v, @as(i32, 256)));
            },
            .output => try output.append(allocator, memory[ptr]),
            .input => {
                if (input_pos < input.len) {
                    memory[ptr] = input[input_pos];
                    input_pos += 1;
                } else {
                    memory[ptr] = 0;
                }
            },
            .jump_zero => if (memory[ptr] == 0) {
                ip = inst.jump;
            },
            .jump_nonzero => if (memory[ptr] != 0) {
                ip = inst.jump;
            },
            .set_zero => memory[ptr] = 0,
        }

        ip += 1;
    }

    return output.toOwnedSlice(allocator);
}

// ─── Encoder: plaintext -> BF code that outputs it ─────────────────

pub fn encode(allocator: std.mem.Allocator, plaintext: []const u8) ![]u8 {
    var buf: std.ArrayListUnmanaged(u8) = .empty;
    errdefer buf.deinit(allocator);

    var current: u8 = 0;
    for (plaintext) |target| {
        const target_i: i32 = target;
        const current_i: i32 = current;
        const diff: i32 = target_i - current_i;

        if (diff == 0) {
            try buf.append(allocator, '.');
        } else if (diff > 0 and diff <= 30) {
            try appendChar(&buf, allocator, '+', @intCast(diff));
            try buf.append(allocator, '.');
        } else if (diff < 0 and -diff <= 30) {
            try appendChar(&buf, allocator, '-', @intCast(-diff));
            try buf.append(allocator, '.');
        } else {
            try buf.appendSlice(allocator, "[-]");
            try writeOptimalValue(&buf, allocator, target);
            try buf.append(allocator, '.');
        }

        current = target;
    }

    return buf.toOwnedSlice(allocator);
}

fn appendChar(buf: *std.ArrayListUnmanaged(u8), allocator: std.mem.Allocator, c: u8, n: usize) !void {
    var i: usize = 0;
    while (i < n) : (i += 1) try buf.append(allocator, c);
}

/// Build target value from zero, choosing the shortest of:
///   N pluses (linear)            cost: N
///   >a[<b>-]<diff (multiply)     cost: a + b + 6 + |diff|
fn writeOptimalValue(buf: *std.ArrayListUnmanaged(u8), allocator: std.mem.Allocator, target: u8) !void {
    const value: i32 = target;
    if (value == 0) return;

    var best_len: usize = @intCast(value);
    var best_a: i32 = 0;
    var best_b: i32 = 0;
    var best_diff: i32 = 0;

    var a: i32 = 2;
    while (a <= 16) : (a += 1) {
        var b: i32 = 2;
        while (b <= 16) : (b += 1) {
            const product = a * b;
            const diff = value - product;
            if (diff < -15 or diff > 15) continue;

            const abs_diff: usize = @intCast(if (diff >= 0) diff else -diff);
            const code_len: usize = @as(usize, @intCast(a)) + @as(usize, @intCast(b)) + 6 + abs_diff;
            if (code_len < best_len) {
                best_len = code_len;
                best_a = a;
                best_b = b;
                best_diff = diff;
            }
        }
    }

    if (best_a == 0) {
        try appendChar(buf, allocator, '+', @intCast(value));
        return;
    }

    try buf.append(allocator, '>');
    try appendChar(buf, allocator, '+', @intCast(best_a));
    try buf.appendSlice(allocator, "[<");
    try appendChar(buf, allocator, '+', @intCast(best_b));
    try buf.appendSlice(allocator, ">-]<");
    if (best_diff > 0) {
        try appendChar(buf, allocator, '+', @intCast(best_diff));
    } else if (best_diff < 0) {
        try appendChar(buf, allocator, '-', @intCast(-best_diff));
    }
}

// ─── Emoji codec ───────────────────────────────────────────────────
// Each BF instruction maps to a unique emoji. The mapping is fixed
// so anyone with our decoder can recover the BF — but the output
// is opaque to anyone who doesn't know the table or have a runtime.

pub const emoji_inc_ptr = "\u{1F449}"; // 👉
pub const emoji_dec_ptr = "\u{1F448}"; // 👈
pub const emoji_inc_val = "\u{2795}"; // ➕
pub const emoji_dec_val = "\u{2796}"; // ➖
pub const emoji_output = "\u{1F4AC}"; // 💬
pub const emoji_input = "\u{1F4E5}"; // 📥
pub const emoji_loop_open = "\u{1F501}"; // 🔁
pub const emoji_loop_close = "\u{1F51A}"; // 🔚

const EmojiPair = struct { emoji: []const u8, bf: u8 };
const emoji_table = [_]EmojiPair{
    .{ .emoji = emoji_inc_ptr, .bf = '>' },
    .{ .emoji = emoji_dec_ptr, .bf = '<' },
    .{ .emoji = emoji_inc_val, .bf = '+' },
    .{ .emoji = emoji_dec_val, .bf = '-' },
    .{ .emoji = emoji_output, .bf = '.' },
    .{ .emoji = emoji_input, .bf = ',' },
    .{ .emoji = emoji_loop_open, .bf = '[' },
    .{ .emoji = emoji_loop_close, .bf = ']' },
};

pub fn bfToEmoji(allocator: std.mem.Allocator, bf: []const u8) ![]u8 {
    var buf: std.ArrayListUnmanaged(u8) = .empty;
    errdefer buf.deinit(allocator);
    for (bf) |c| {
        const emoji: ?[]const u8 = switch (c) {
            '>' => emoji_inc_ptr,
            '<' => emoji_dec_ptr,
            '+' => emoji_inc_val,
            '-' => emoji_dec_val,
            '.' => emoji_output,
            ',' => emoji_input,
            '[' => emoji_loop_open,
            ']' => emoji_loop_close,
            else => null,
        };
        if (emoji) |e| try buf.appendSlice(allocator, e);
    }
    return buf.toOwnedSlice(allocator);
}

pub fn emojiToBf(allocator: std.mem.Allocator, text: []const u8) ![]u8 {
    var buf: std.ArrayListUnmanaged(u8) = .empty;
    errdefer buf.deinit(allocator);

    var i: usize = 0;
    while (i < text.len) {
        var matched = false;
        for (emoji_table) |entry| {
            if (i + entry.emoji.len <= text.len and
                std.mem.eql(u8, text[i .. i + entry.emoji.len], entry.emoji))
            {
                try buf.append(allocator, entry.bf);
                i += entry.emoji.len;
                matched = true;
                break;
            }
        }
        if (!matched) i += 1;
    }

    return buf.toOwnedSlice(allocator);
}

// ─── Engine adapters (used by crypto/engine.zig) ───────────────────

/// Encode plaintext to ASCII Brainfuck source.
pub fn encodeText(allocator: std.mem.Allocator, plaintext: []const u8) ![]u8 {
    return encode(allocator, plaintext);
}

/// Execute Brainfuck source and return its output (= plaintext).
pub fn decodeText(allocator: std.mem.Allocator, bf_source: []const u8) ![]u8 {
    return run(allocator, bf_source, "");
}

/// Encode plaintext to emoji-Brainfuck.
pub fn encodeEmoji(allocator: std.mem.Allocator, plaintext: []const u8) ![]u8 {
    const bf = try encode(allocator, plaintext);
    defer allocator.free(bf);
    return bfToEmoji(allocator, bf);
}

/// Decode emoji-Brainfuck back to plaintext (translate, then execute).
pub fn decodeEmoji(allocator: std.mem.Allocator, emoji_source: []const u8) ![]u8 {
    const bf = try emojiToBf(allocator, emoji_source);
    defer allocator.free(bf);
    return run(allocator, bf, "");
}

/// Quick check: does the input look like ASCII Brainfuck?
/// Returns true when it contains BF instruction characters and at
/// least one bracket (loops are required to print non-trivial text).
pub fn looksLikeBfText(input: []const u8) bool {
    if (input.len < 4) return false;
    var bf_chars: usize = 0;
    var has_bracket = false;
    var has_dot = false;
    for (input) |c| {
        switch (c) {
            '>', '<', '+', '-', '.', ',', '[', ']' => {
                bf_chars += 1;
                if (c == '[' or c == ']') has_bracket = true;
                if (c == '.') has_dot = true;
            },
            ' ', '\n', '\r', '\t' => {},
            else => return false,
        }
    }
    return has_bracket and has_dot and bf_chars >= 4;
}

/// Quick check: does the input contain BF emojis?
pub fn looksLikeBfEmoji(input: []const u8) bool {
    if (input.len < 4) return false;
    var i: usize = 0;
    var hits: usize = 0;
    while (i < input.len) {
        var matched = false;
        for (emoji_table) |entry| {
            if (i + entry.emoji.len <= input.len and
                std.mem.eql(u8, input[i .. i + entry.emoji.len], entry.emoji))
            {
                hits += 1;
                i += entry.emoji.len;
                matched = true;
                break;
            }
        }
        if (!matched) i += 1;
    }
    return hits >= 4;
}

// ─── Tests ─────────────────────────────────────────────────────────

test "compile + run hello world" {
    const allocator = std.testing.allocator;
    // Classic minimal Hello World — BF chars only, output ends with newline
    const src = "++++++++[>++++[>++>+++>+++>+<<<<-]>+>+>->>+[<]<-]>>.>---.+++++++..+++.>>.<-.<.+++.------.--------.>>+.>++.";
    const out = try run(allocator, src, "");
    defer allocator.free(out);
    try std.testing.expectEqualStrings("Hello World!\n", out);
}

test "encode + run roundtrip" {
    const allocator = std.testing.allocator;
    const cases = [_][]const u8{
        "A",
        "Hi!",
        "Hello, World!",
        "VeilText",
        "abc 123 XYZ",
    };
    for (cases) |plain| {
        const bf = try encode(allocator, plain);
        defer allocator.free(bf);
        const out = try run(allocator, bf, "");
        defer allocator.free(out);
        try std.testing.expectEqualStrings(plain, out);
    }
}

test "emoji roundtrip" {
    const allocator = std.testing.allocator;
    const plain = "Hello, BF!";
    const emoji = try encodeEmoji(allocator, plain);
    defer allocator.free(emoji);
    try std.testing.expect(emoji.len > 0);
    // Should contain at least one of our emojis
    try std.testing.expect(std.mem.indexOf(u8, emoji, emoji_inc_val) != null);

    const out = try decodeEmoji(allocator, emoji);
    defer allocator.free(out);
    try std.testing.expectEqualStrings(plain, out);
}

test "decodeText runs an arbitrary program" {
    const allocator = std.testing.allocator;
    // ++++++++++ = cell 0 = 10, [>+++++++<-] = cell 1 = 70, >. outputs 'F'
    const src = "++++++++++[>+++++++<-]>.";
    const out = try decodeText(allocator, src);
    defer allocator.free(out);
    try std.testing.expectEqualStrings("F", out);
}

test "unmatched bracket fails" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(BfError.UnmatchedBracket, compile(allocator, "[[]"));
}

test "looksLikeBfText / looksLikeBfEmoji detection" {
    try std.testing.expect(looksLikeBfText("++++++++[>+.<-]"));
    try std.testing.expect(!looksLikeBfText("Hello, World"));
    try std.testing.expect(!looksLikeBfText("abcdef"));

    const allocator = std.testing.allocator;
    const emoji = try encodeEmoji(allocator, "Hi");
    defer allocator.free(emoji);
    try std.testing.expect(looksLikeBfEmoji(emoji));
    try std.testing.expect(!looksLikeBfEmoji("nothing here"));
}
