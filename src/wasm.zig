const std = @import("std");
const base = @import("crypto/base.zig");
const hash = @import("crypto/hash.zig");
const jsob = @import("crypto/jsobfuscation.zig");
const bf = @import("crypto/brainfuck.zig");

const allocator = std.heap.page_allocator;

const Mode = enum(u32) {
    encode = 0,
    decode = 1,
};

const WasmError = error{
    InvalidInput,
    UnknownAlgorithm,
    InvalidMode,
};

var last_result: ?[]u8 = null;
var last_error: u32 = 0;

const supported_algorithms =
    \\0 base16
    \\1 base32
    \\2 base58
    \\3 base64
    \\4 base85
    \\20 sha256
    \\21 sha512
    \\22 blake3
    \\23 md5
    \\40 js_hex_escape
    \\41 js_unicode_escape
    \\42 js_binary_string
    \\43 js_jjencode
    \\44 js_aaencode
    \\45 js_jsfuck
    \\46 js_eval_wrap
    \\47 js_constructor_wrap
    \\48 js_base36_tostring
    \\60 bf_text
    \\61 bf_emoji
;

export fn veiltext_wasm_abi_version() u32 {
    return 1;
}

export fn veiltext_supported_algorithms_ptr() usize {
    return @intFromPtr(supported_algorithms.ptr);
}

export fn veiltext_supported_algorithms_len() usize {
    return supported_algorithms.len;
}

export fn veiltext_alloc(len: usize) usize {
    if (len == 0) return 0;
    const buf = allocator.alloc(u8, len) catch return 0;
    return @intFromPtr(buf.ptr);
}

export fn veiltext_free(ptr: usize, len: usize) void {
    if (ptr == 0 or len == 0) return;
    const buf = @as([*]u8, @ptrFromInt(ptr))[0..len];
    allocator.free(buf);
}

export fn veiltext_clear_result() void {
    clearResult();
    last_error = 0;
}

export fn veiltext_result_ptr() usize {
    if (last_result) |result| return @intFromPtr(result.ptr);
    return 0;
}

export fn veiltext_result_len() usize {
    if (last_result) |result| return result.len;
    return 0;
}

export fn veiltext_last_error() u32 {
    return last_error;
}

/// Transform input with an algorithm id from veiltext_supported_algorithms.
/// mode: 0 = encode, 1 = decode. Hash algorithms ignore mode.
export fn veiltext_transform(algorithm: u32, mode_raw: u32, ptr: usize, len: usize) u32 {
    const input = inputSlice(ptr, len) catch |err| return fail(errorCode(err));
    const mode: Mode = switch (mode_raw) {
        0 => .encode,
        1 => .decode,
        else => return fail(3),
    };
    const result = transform(algorithm, mode, input) catch |err| return fail(errorCode(err));
    clearResult();
    last_result = result;
    last_error = 0;
    return 1;
}

fn transform(algorithm: u32, mode: Mode, input: []const u8) ![]u8 {
    return switch (algorithm) {
        0 => transformBase(.base16, mode, input),
        1 => transformBase(.base32, mode, input),
        2 => transformBase(.base58, mode, input),
        3 => transformBase(.base64, mode, input),
        4 => transformBase(.base85, mode, input),
        20 => hash.hashHex(allocator, .sha256, input),
        21 => hash.hashHex(allocator, .sha512, input),
        22 => hash.hashHex(allocator, .blake3, input),
        23 => hash.hashHex(allocator, .md5, input),
        40 => transformJs(.hex_escape, mode, input),
        41 => transformJs(.unicode_escape, mode, input),
        42 => transformJs(.binary_string, mode, input),
        43 => transformJs(.jjencode, mode, input),
        44 => transformJs(.aaencode, mode, input),
        45 => transformJs(.jsfuck, mode, input),
        46 => transformJs(.eval_wrap, mode, input),
        47 => transformJs(.constructor_wrap, mode, input),
        48 => transformJs(.base36_tostring, mode, input),
        60 => switch (mode) {
            .encode => bf.encodeText(allocator, input),
            .decode => bf.decodeText(allocator, input),
        },
        61 => switch (mode) {
            .encode => bf.encodeEmoji(allocator, input),
            .decode => bf.decodeEmoji(allocator, input),
        },
        else => WasmError.UnknownAlgorithm,
    };
}

fn transformBase(encoding: base.BaseEncoding, mode: Mode, input: []const u8) ![]u8 {
    return switch (mode) {
        .encode => base.encode(allocator, encoding, input),
        .decode => base.decode(allocator, encoding, input),
    };
}

fn transformJs(algorithm: jsob.JsAlgorithm, mode: Mode, input: []const u8) ![]u8 {
    return switch (mode) {
        .encode => jsob.encode(allocator, algorithm, input),
        .decode => jsob.decode(allocator, algorithm, input),
    };
}

fn inputSlice(ptr: usize, len: usize) ![]const u8 {
    if (len == 0) return "";
    if (ptr == 0) return WasmError.InvalidInput;
    return @as([*]const u8, @ptrFromInt(ptr))[0..len];
}

fn clearResult() void {
    if (last_result) |result| {
        allocator.free(result);
        last_result = null;
    }
}

fn fail(code: u32) u32 {
    clearResult();
    last_error = code;
    return 0;
}

fn errorCode(err: anyerror) u32 {
    return switch (err) {
        WasmError.InvalidInput => 1,
        WasmError.UnknownAlgorithm => 2,
        WasmError.InvalidMode => 3,
        error.OutOfMemory => 5,
        else => 4,
    };
}

test "wasm transform base64" {
    const encoded = try transform(3, .encode, "Hello");
    defer allocator.free(encoded);
    try std.testing.expectEqualStrings("SGVsbG8=", encoded);

    const decoded = try transform(3, .decode, "SGVsbG8");
    defer allocator.free(decoded);
    try std.testing.expectEqualStrings("Hello", decoded);
}

test "wasm transform hash" {
    const hex = try transform(20, .encode, "hello");
    defer allocator.free(hex);
    try std.testing.expectEqualStrings("2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824", hex);
}
