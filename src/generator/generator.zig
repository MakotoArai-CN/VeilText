const std = @import("std");
const date_mod = @import("date.zig");
const random_mod = @import("random.zig");
const wordbank_mod = @import("wordbank.zig");
const news_mod = @import("news.zig");

// ═══════════════════════════════════════════════════════════════════
//  Template Generator
//
//  Syntax: plain text with {variable} placeholders.
//
//  Variables:
//    {date}                    — Today's date (YYYY-MM-DD)
//    {date:FORMAT}             — Date in specified format (compact, MMDD, etc.)
//    {random:N}                — N random decimal digits
//    {random:TYPE:N}           — N random chars of TYPE (hex, alnum, lower, upper, ascii)
//    {uuid}                    — UUID v4
//    {word:CATEGORY}           — Random word from category (games, tech, finance, general)
//    {game:genshin:character}  — Random Genshin character name
//    {game:genshin:birthday:NAME} — Birthday of NAME (e.g. funingna -> 1013)
//    {news:KEYWORD}            — News keyword (placeholder, requires HTTP)
//    {gold:price}              — Gold price (placeholder)
//    {literal:TEXT}            — Literal text (no processing)
// ═══════════════════════════════════════════════════════════════════

/// Parse a template and generate output using built-in defaults.
pub fn generate(allocator: std.mem.Allocator, template: []const u8) ![]u8 {
    return generateWithTemplateData(allocator, template, null);
}

/// Parse a template and generate output using optional runtime template data.
pub fn generateWithTemplateData(allocator: std.mem.Allocator, template: []const u8, template_data: ?*const wordbank_mod.TemplateData) ![]u8 {
    var result: std.Io.Writer.Allocating = .init(allocator);
    const writer = &result.writer;

    var i: usize = 0;
    while (i < template.len) {
        if (template[i] == '{') {
            // Find closing brace
            if (std.mem.indexOfScalarPos(u8, template, i + 1, '}')) |end| {
                const var_str = template[i + 1 .. end];
                const expanded = try expandVariable(allocator, var_str, template_data);
                defer allocator.free(expanded);
                try writer.writeAll(expanded);
                i = end + 1;
            } else {
                // No closing brace, treat as literal
                try writer.writeByte(template[i]);
                i += 1;
            }
        } else {
            try writer.writeByte(template[i]);
            i += 1;
        }
    }

    return result.toOwnedSlice();
}

/// Expand a single variable.
fn expandVariable(allocator: std.mem.Allocator, var_str: []const u8, template_data: ?*const wordbank_mod.TemplateData) ![]u8 {
    // Split by ':'
    var parts_buf: [8][]const u8 = undefined;
    var part_count: usize = 0;
    var it = std.mem.splitScalar(u8, var_str, ':');
    while (it.next()) |part| {
        if (part_count < 8) {
            parts_buf[part_count] = part;
            part_count += 1;
        }
    }
    const parts = parts_buf[0..part_count];

    if (parts.len == 0) return try allocator.dupe(u8, "");

    const cmd = parts[0];

    // {date} or {date:FORMAT}
    if (std.mem.eql(u8, cmd, "date")) {
        const fmt = if (parts.len > 1) date_mod.DateFormat.fromString(parts[1]) orelse .iso else .iso;
        return try date_mod.generate(allocator, fmt);
    }

    // {random:N} or {random:TYPE:N}
    if (std.mem.eql(u8, cmd, "random")) {
        if (parts.len == 2) {
            // {random:N} — decimal digits
            const n = std.fmt.parseInt(usize, parts[1], 10) catch 8;
            return try random_mod.generate(allocator, .decimal, n);
        } else if (parts.len >= 3) {
            // {random:TYPE:N}
            const rtype = random_mod.RandomType.fromString(parts[1]) orelse .decimal;
            const n = std.fmt.parseInt(usize, parts[2], 10) catch 8;
            return try random_mod.generate(allocator, rtype, n);
        }
        return try random_mod.generate(allocator, .decimal, 8);
    }

    // {uuid}
    if (std.mem.eql(u8, cmd, "uuid")) {
        return try random_mod.generate(allocator, .uuid, 0);
    }

    // {word:CATEGORY}
    if (std.mem.eql(u8, cmd, "word")) {
        if (parts.len > 1) {
            if (wordbank_mod.Category.fromString(parts[1])) |cat| {
                const word = if (template_data) |data| data.randomWord(cat) else wordbank_mod.randomWord(cat);
                return try allocator.dupe(u8, word);
            }
            // Check custom banks
            if (template_data) |data| {
                if (data.randomCustomWord(parts[1])) |word| {
                    return try allocator.dupe(u8, word);
                }
            }
            // Fallback to general
            const word = if (template_data) |data| data.randomWord(.general) else wordbank_mod.randomWord(.general);
            return try allocator.dupe(u8, word);
        }
        const word = if (template_data) |data| data.randomWord(.general) else wordbank_mod.randomWord(.general);
        return try allocator.dupe(u8, word);
    }

    // {game:genshin:character} or {game:genshin:birthday:NAME}
    if (std.mem.eql(u8, cmd, "game")) {
        if (parts.len >= 3 and std.mem.eql(u8, parts[1], "genshin")) {
            if (std.mem.eql(u8, parts[2], "character")) {
                const character = if (template_data) |data| data.randomGenshinCharacter() else wordbank_mod.randomGenshinCharacter();
                return try allocator.dupe(u8, character);
            }
            if (std.mem.eql(u8, parts[2], "birthday") and parts.len >= 4) {
                const birthday = if (template_data) |data| data.genshinBirthday(parts[3]) else wordbank_mod.genshinBirthday(parts[3]);
                if (birthday) |bd| {
                    return try allocator.dupe(u8, bd);
                }
                return try allocator.dupe(u8, "????");
            }
        }
        // Default: random game word
        const word = if (template_data) |data| data.randomWord(.games) else wordbank_mod.randomWord(.games);
        return try allocator.dupe(u8, word);
    }

    // {news:KEYWORD}
    if (std.mem.eql(u8, cmd, "news")) {
        const keyword = if (parts.len > 1) parts[1] else "latest";
        _ = keyword;
        return try news_mod.fetchKeywords(allocator, "");
    }

    // {gold:price}
    if (std.mem.eql(u8, cmd, "gold")) {
        return try news_mod.fetchRealtimeValue(allocator, .gold_price);
    }

    // {literal:TEXT}
    if (std.mem.eql(u8, cmd, "literal")) {
        if (parts.len > 1) {
            return try allocator.dupe(u8, parts[1]);
        }
        return try allocator.dupe(u8, "");
    }

    // Unknown variable — return as-is wrapped in braces
    return try std.fmt.allocPrint(allocator, "{{{s}}}", .{var_str});
}

// ═══════════════════════════════════════════════════════════════════
//  Tests
// ═══════════════════════════════════════════════════════════════════

test "generate plain text" {
    const allocator = std.testing.allocator;
    const result = try generate(allocator, "hello world");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("hello world", result);
}

test "generate with date" {
    const allocator = std.testing.allocator;
    const result = try generate(allocator, "sk-{date}");
    defer allocator.free(result);
    // Should start with "sk-" and contain a date
    try std.testing.expect(std.mem.startsWith(u8, result, "sk-"));
    try std.testing.expect(result.len >= 13); // sk- + YYYY-MM-DD
}

test "generate with random digits" {
    const allocator = std.testing.allocator;
    const result = try generate(allocator, "code-{random:6}");
    defer allocator.free(result);
    try std.testing.expect(std.mem.startsWith(u8, result, "code-"));
    try std.testing.expect(result.len == 11); // code- + 6 digits
}

test "generate with genshin character" {
    const allocator = std.testing.allocator;
    const result = try generate(allocator, "sk-{game:genshin:character}");
    defer allocator.free(result);
    try std.testing.expect(std.mem.startsWith(u8, result, "sk-"));
    try std.testing.expect(result.len > 3);
}

test "generate with genshin birthday" {
    const allocator = std.testing.allocator;
    const result = try generate(allocator, "sk-{date:MMDD}-{game:genshin:birthday:funingna}");
    defer allocator.free(result);
    try std.testing.expect(std.mem.startsWith(u8, result, "sk-"));
    // Should contain "1013" (funingna's birthday)
    try std.testing.expect(std.mem.indexOf(u8, result, "1013") != null);
}

test "generate complex template" {
    const allocator = std.testing.allocator;
    const result = try generate(allocator, "sk-{date:MMDD}-{game:genshin:character}-{random:4}");
    defer allocator.free(result);
    try std.testing.expect(std.mem.startsWith(u8, result, "sk-"));
    // Should have 3 dashes (sk- + date- + char- + random)
    var dashes: usize = 0;
    for (result) |c| {
        if (c == '-') dashes += 1;
    }
    try std.testing.expect(dashes >= 3);
}

test "generate with word bank" {
    const allocator = std.testing.allocator;
    const result = try generate(allocator, "key-{word:tech}");
    defer allocator.free(result);
    try std.testing.expect(std.mem.startsWith(u8, result, "key-"));
    try std.testing.expect(result.len > 4);
}

test "generate with uuid" {
    const allocator = std.testing.allocator;
    const result = try generate(allocator, "{uuid}");
    defer allocator.free(result);
    try std.testing.expect(result.len == 36);
}

test "generate with literal" {
    const allocator = std.testing.allocator;
    const result = try generate(allocator, "prefix-{literal:hello}-suffix");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("prefix-hello-suffix", result);
}

test "generate unknown variable" {
    const allocator = std.testing.allocator;
    const result = try generate(allocator, "test-{unknown}");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("test-{unknown}", result);
}
