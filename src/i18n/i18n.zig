const std = @import("std");
const config = @import("../config.zig");

const zh = @import("zh.zig");
const ja = @import("ja.zig");
const en = @import("en.zig");

// ═══════════════════════════════════════════════════════════════════
//  i18n System
//
//  Compile-time translation lookup. All three languages are embedded.
//  Runtime language selection based on Accept-Language or user setting.
// ═══════════════════════════════════════════════════════════════════

pub const Strings = struct {
    // App
    app_title: []const u8,
    app_subtitle: []const u8,
    app_description: []const u8,

    // Navigation
    nav_encrypt: []const u8,
    nav_decrypt: []const u8,
    nav_puzzle: []const u8,
    nav_generate: []const u8,
    nav_history: []const u8,
    nav_settings: []const u8,

    // Encrypt page
    encrypt_title: []const u8,
    encrypt_input_placeholder: []const u8,
    encrypt_key_placeholder: []const u8,
    encrypt_btn: []const u8,
    encrypt_result: []const u8,
    encrypt_pipeline: []const u8,
    encrypt_add_step: []const u8,

    // Decrypt page
    decrypt_title: []const u8,
    decrypt_input_placeholder: []const u8,
    decrypt_key_placeholder: []const u8,
    decrypt_btn: []const u8,
    decrypt_ai_decode: []const u8,
    decrypt_result: []const u8,
    decrypt_verify_ok: []const u8,
    decrypt_verify_fail: []const u8,

    // Puzzle page
    puzzle_title: []const u8,
    puzzle_split: []const u8,
    puzzle_merge: []const u8,
    puzzle_pieces: []const u8,
    puzzle_piece_n: []const u8,

    // Generate page
    generate_title: []const u8,
    generate_template_placeholder: []const u8,
    generate_btn: []const u8,
    generate_result: []const u8,
    generate_then_encrypt: []const u8,

    // History
    history_title: []const u8,
    history_empty: []const u8,
    history_clear: []const u8,
    history_delete: []const u8,

    // Settings
    settings_title: []const u8,
    settings_theme: []const u8,
    settings_language: []const u8,
    settings_ai_config: []const u8,
    settings_api_key: []const u8,
    settings_api_endpoint: []const u8,

    // Common
    copy: []const u8,
    copied: []const u8,
    paste: []const u8,
    clear: []const u8,
    export_text: []const u8,
    verify: []const u8,
    loading: []const u8,
    error_text: []const u8,
    success: []const u8,
    cancel: []const u8,
    confirm: []const u8,

    // Themes
    theme_auto: []const u8,
    theme_light_jade: []const u8,
    theme_dark_ocean: []const u8,
    theme_sakura: []const u8,
    theme_midnight: []const u8,
    theme_amber: []const u8,

    // Algorithms
    algo_base16: []const u8,
    algo_base32: []const u8,
    algo_base58: []const u8,
    algo_base64: []const u8,
    algo_base85: []const u8,
    algo_aes: []const u8,
    algo_chacha: []const u8,
    algo_xchacha: []const u8,

    // Toast messages
    toast_encrypt_success: []const u8,
    toast_decrypt_success: []const u8,
    toast_copy_success: []const u8,
    toast_error_no_input: []const u8,
    toast_error_no_key: []const u8,

    // Template variables / Chips
    settings_template_vars: []const u8,
    settings_template_desc: []const u8,
    chip_add: []const u8,
    chip_reset: []const u8,
    chip_edit_label: []const u8,
    chip_edit_value: []const u8,
    chip_name_placeholder: []const u8,
    chip_value_placeholder: []const u8,
    var_ref_title: []const u8,
    var_ref_desc: []const u8,
    template_data_title: []const u8,
    template_data_desc: []const u8,
    template_data_games: []const u8,
    template_data_tech: []const u8,
    template_data_finance: []const u8,
    template_data_general: []const u8,
    template_data_genshin_characters: []const u8,
    template_data_genshin_birthdays: []const u8,

    // Puzzle enhancements
    puzzle_encrypt_option: []const u8,
    puzzle_encrypt_method: []const u8,
    puzzle_copy_piece: []const u8,
    puzzle_input_placeholder: []const u8,

    // Common extra
    save: []const u8,
    add: []const u8,
    edit: []const u8,
    delete_text: []const u8,

    // Generate enhancements
    generate_then_split: []const u8,

    // AI page
    nav_ai: []const u8,
    ai_title: []const u8,
    ai_placeholder: []const u8,
    ai_send: []const u8,
    ai_test_connection: []const u8,
    ai_provider: []const u8,
    ai_model: []const u8,
    ai_mode_chat: []const u8,
    ai_mode_encrypt: []const u8,
    ai_mode_decrypt: []const u8,
    ai_mode_puzzle: []const u8,
    ai_mode_generate: []const u8,
    ai_no_key: []const u8,
    ai_thinking: []const u8,
    ai_connected: []const u8,
    ai_connect_failed: []const u8,
};

/// Get the string table for a language.
pub fn getStrings(lang: config.Language) Strings {
    return switch (lang) {
        .zh => zh.strings,
        .ja => ja.strings,
        .en => en.strings,
    };
}

/// Get a specific string by field name for a language.
pub fn get(lang: config.Language, comptime key: std.meta.FieldEnum(Strings)) []const u8 {
    const strings = getStrings(lang);
    return @field(strings, @tagName(key));
}

/// Build a JSON object of all i18n strings for client-side use.
pub fn toJson(allocator: std.mem.Allocator) ![]u8 {
    var buf: std.Io.Writer.Allocating = .init(allocator);
    const w = &buf.writer;

    try w.writeAll("{");

    inline for (.{ .{ "zh", config.Language.zh }, .{ "ja", config.Language.ja }, .{ "en", config.Language.en } }, 0..) |pair, lang_idx| {
        if (lang_idx > 0) try w.writeByte(',');
        try w.writeByte('"');
        try w.writeAll(pair[0]);
        try w.writeAll("\":{");

        const strings = getStrings(pair[1]);
        var field_idx: usize = 0;
        inline for (std.meta.fields(Strings)) |field| {
            if (field_idx > 0) try w.writeByte(',');
            try w.writeByte('"');
            try w.writeAll(field.name);
            try w.writeAll("\":\"");
            const val = @field(strings, field.name);
            for (val) |c| {
                switch (c) {
                    '"' => try w.writeAll("\\\""),
                    '\\' => try w.writeAll("\\\\"),
                    '\n' => try w.writeAll("\\n"),
                    else => try w.writeByte(c),
                }
            }
            try w.writeByte('"');
            field_idx += 1;
        }
        try w.writeByte('}');
    }

    try w.writeAll("}");
    return buf.toOwnedSlice();
}

// ═══════════════════════════════════════════════════════════════════
//  Tests
// ═══════════════════════════════════════════════════════════════════

test "get English string" {
    const s = get(.en, .nav_encrypt);
    try std.testing.expectEqualStrings("Encrypt", s);
}

test "get Chinese string" {
    const s = get(.zh, .nav_encrypt);
    try std.testing.expect(s.len > 0);
}

test "get Japanese string" {
    const s = get(.ja, .nav_encrypt);
    try std.testing.expect(s.len > 0);
}

test "toJson produces valid JSON" {
    const allocator = std.testing.allocator;
    const json = try toJson(allocator);
    defer allocator.free(json);

    try std.testing.expect(json[0] == '{');
    try std.testing.expect(json[json.len - 1] == '}');
    try std.testing.expect(std.mem.indexOf(u8, json, "\"zh\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"ja\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"en\"") != null);
}
