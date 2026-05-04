const std = @import("std");
const compat = @import("../compat.zig");
const utils = @import("../utils.zig");

// ═══════════════════════════════════════════════════════════════════
//  Word Bank
// ═══════════════════════════════════════════════════════════════════

/// Built-in word bank categories.
pub const Category = enum {
    games,
    tech,
    finance,
    general,

    pub fn name(self: Category) []const u8 {
        return switch (self) {
            .games => "games",
            .tech => "tech",
            .finance => "finance",
            .general => "general",
        };
    }

    pub fn fromString(s: []const u8) ?Category {
        const map = .{
            .{ "games", Category.games },
            .{ "game", Category.games },
            .{ "tech", Category.tech },
            .{ "technology", Category.tech },
            .{ "finance", Category.finance },
            .{ "fin", Category.finance },
            .{ "general", Category.general },
            .{ "gen", Category.general },
        };
        inline for (map) |entry| {
            if (std.mem.eql(u8, s, entry[0])) return entry[1];
        }
        return null;
    }
};

pub const BirthdayPair = struct {
    name: []const u8,
    birthday: []const u8,
};

pub const BirthdayEntry = struct {
    name: []u8,
    birthday: []u8,
};

// ═══════════════════════════════════════════════════════════════════
//  Built-in Word Banks (embedded defaults)
// ═══════════════════════════════════════════════════════════════════

pub const default_genshin_characters = [_][]const u8{
    "funingna",   "funina",      "naxida",      "nahida",
    "zhongli",    "wendi",       "venti",       "leishen",
    "raiden",     "ganyu",       "hutao",       "keqing",
    "xiao",       "ayaka",       "yoimiya",     "yelan",
    "alhaitham",  "wanderer",    "nilou",       "shenhe",
    "yae",        "kokomi",      "eula",        "kazuha",
    "tighnari",   "cyno",        "dehya",       "baizhu",
    "lyney",      "lynette",     "freminet",    "neuvillette",
    "wriothesley","navia",       "chiori",      "arlecchino",
    "clorinde",   "sigewinne",   "emilie",      "mualani",
    "kinich",     "xilonen",     "chasca",      "mavuika",
};

pub const default_games_words = [_][]const u8{
    "yuanshen",    "genshin",      "funingna",    "funina",
    "naxida",      "nahida",       "zhongli",     "wendi",
    "venti",       "leishen",      "raiden",      "ganyu",
    "hutao",       "keqing",       "xiao",        "ayaka",
    "yoimiya",     "yelan",        "alhaitham",   "wanderer",
    "nilou",       "shenhe",       "yae",         "kokomi",
    "eula",        "kazuha",       "tighnari",    "cyno",
    "dehya",       "baizhu",       "lyney",       "lynette",
    "freminet",    "neuvillette",  "wriothesley", "navia",
    "chiori",      "arlecchino",   "clorinde",    "sigewinne",
    "emilie",      "mualani",      "kinich",      "xilonen",
    "chasca",      "mavuika",      "teyvat",      "mondstadt",
    "liyue",       "inazuma",      "sumeru",      "fontaine",
    "natlan",      "snezhnaya",    "celestia",    "primogem",
    "mora",        "resin",        "archon",      "vision",
    "gnosis",      "abyss",
};

pub const default_genshin_birthdays = [_]BirthdayPair{
    .{ .name = "funingna", .birthday = "1013" },
    .{ .name = "funina", .birthday = "1013" },
    .{ .name = "zhongli", .birthday = "1231" },
    .{ .name = "wendi", .birthday = "0616" },
    .{ .name = "venti", .birthday = "0616" },
    .{ .name = "ganyu", .birthday = "1202" },
    .{ .name = "hutao", .birthday = "0715" },
    .{ .name = "keqing", .birthday = "1120" },
    .{ .name = "xiao", .birthday = "0417" },
    .{ .name = "ayaka", .birthday = "0928" },
    .{ .name = "yoimiya", .birthday = "0621" },
    .{ .name = "raiden", .birthday = "0626" },
    .{ .name = "nahida", .birthday = "1027" },
    .{ .name = "naxida", .birthday = "1027" },
    .{ .name = "yelan", .birthday = "0420" },
    .{ .name = "kazuha", .birthday = "1029" },
    .{ .name = "eula", .birthday = "1025" },
    .{ .name = "shenhe", .birthday = "0310" },
    .{ .name = "kokomi", .birthday = "0222" },
    .{ .name = "yae", .birthday = "0627" },
    .{ .name = "nilou", .birthday = "1203" },
    .{ .name = "alhaitham", .birthday = "0211" },
    .{ .name = "neuvillette", .birthday = "1218" },
    .{ .name = "wriothesley", .birthday = "1109" },
    .{ .name = "navia", .birthday = "0816" },
    .{ .name = "arlecchino", .birthday = "0422" },
    .{ .name = "clorinde", .birthday = "0910" },
    .{ .name = "mavuika", .birthday = "0114" },
};

pub const default_tech_words = [_][]const u8{
    "kubernetes", "docker",        "terraform",  "ansible",
    "prometheus", "grafana",       "jenkins",    "gitlab",
    "nginx",      "redis",         "postgres",   "mongodb",
    "elasticsearch","kafka",       "rabbitmq",   "consul",
    "vault",      "istio",         "envoy",      "grpc",
    "graphql",    "restapi",       "websocket",  "oauth",
    "jwt",        "ssl",           "tls",        "https",
    "cicd",       "devops",        "sre",        "mlops",
    "microservice","serverless",   "lambda",     "cloudflare",
    "wasm",       "rust",          "golang",     "typescript",
    "python",     "swift",         "kotlin",     "zig",
};

pub const default_finance_words = [_][]const u8{
    "bitcoin",   "ethereum",  "solana",     "defi",
    "nft",       "dao",       "staking",    "yield",
    "liquidity", "swap",      "bridge",     "oracle",
    "bullish",   "bearish",   "hodl",       "whale",
    "altcoin",   "mainnet",   "testnet",    "airdrop",
    "ipo",       "nasdaq",    "sp500",      "dowjones",
    "forex",     "commodity", "futures",    "options",
    "dividend",  "portfolio", "hedge",      "arbitrage",
    "inflation", "deflation", "gdp",        "cpi",
    "fed",       "ecb",       "pboc",       "boj",
};

pub const default_general_words = [_][]const u8{
    "alpha",   "bravo",    "charlie", "delta",
    "echo",    "foxtrot",  "golf",    "hotel",
    "india",   "juliet",   "kilo",    "lima",
    "mike",    "november", "oscar",   "papa",
    "quebec",  "romeo",    "sierra",  "tango",
    "uniform", "victor",   "whiskey", "xray",
    "yankee",  "zulu",     "phoenix", "dragon",
    "storm",   "shadow",   "cipher",  "quantum",
    "nebula",  "aurora",   "zenith",  "vortex",
    "prism",   "apex",     "nova",    "pulse",
};

// ═══════════════════════════════════════════════════════════════════
//  Runtime Template Data
// ═══════════════════════════════════════════════════════════════════

pub const TemplateData = struct {
    allocator: std.mem.Allocator,
    games_words: std.ArrayListUnmanaged([]u8) = .empty,
    tech_words: std.ArrayListUnmanaged([]u8) = .empty,
    finance_words: std.ArrayListUnmanaged([]u8) = .empty,
    general_words: std.ArrayListUnmanaged([]u8) = .empty,
    genshin_characters: std.ArrayListUnmanaged([]u8) = .empty,
    genshin_birthdays: std.ArrayListUnmanaged(BirthdayEntry) = .empty,
    custom_bank_names: std.ArrayListUnmanaged([]u8) = .empty,
    custom_bank_words: std.ArrayListUnmanaged(std.ArrayListUnmanaged([]u8)) = .empty,

    pub fn initDefaults(allocator: std.mem.Allocator) !TemplateData {
        var data = TemplateData{ .allocator = allocator };
        errdefer data.deinit();
        try data.resetToDefaults();
        return data;
    }

    pub fn fromJson(allocator: std.mem.Allocator, json: []const u8) !TemplateData {
        var data = try TemplateData.initDefaults(allocator);
        errdefer data.deinit();

        const parsed = std.json.parseFromSlice(std.json.Value, allocator, json, .{}) catch return error.InvalidTemplateData;
        defer parsed.deinit();

        const root = switch (parsed.value) {
            .object => |obj| obj,
            else => return error.InvalidTemplateData,
        };

        try data.replaceWordList(root, "games_words", &data.games_words);
        try data.replaceWordList(root, "tech_words", &data.tech_words);
        try data.replaceWordList(root, "finance_words", &data.finance_words);
        try data.replaceWordList(root, "general_words", &data.general_words);
        try data.replaceWordList(root, "genshin_characters", &data.genshin_characters);
        try data.replaceBirthdayList(root, "genshin_birthdays");
        try data.replaceCustomBanks(root);

        return data;
    }

    pub fn deinit(self: *TemplateData) void {
        self.freeWordList(&self.games_words);
        self.freeWordList(&self.tech_words);
        self.freeWordList(&self.finance_words);
        self.freeWordList(&self.general_words);
        self.freeWordList(&self.genshin_characters);
        self.freeBirthdayList();
        self.freeCustomBanks();
    }

    pub fn resetToDefaults(self: *TemplateData) !void {
        self.deinit();
        self.games_words = .empty;
        self.tech_words = .empty;
        self.finance_words = .empty;
        self.general_words = .empty;
        self.genshin_characters = .empty;
        self.genshin_birthdays = .empty;
        self.custom_bank_names = .empty;
        self.custom_bank_words = .empty;

        try self.appendWords(&self.games_words, &default_games_words);
        try self.appendWords(&self.tech_words, &default_tech_words);
        try self.appendWords(&self.finance_words, &default_finance_words);
        try self.appendWords(&self.general_words, &default_general_words);
        try self.appendWords(&self.genshin_characters, &default_genshin_characters);
        try self.appendBirthdays(&default_genshin_birthdays);
    }

    pub fn toJson(self: *const TemplateData, allocator: std.mem.Allocator) ![]u8 {
        var buf: std.Io.Writer.Allocating = .init(allocator);
        const w = &buf.writer;

        try w.writeAll("{\"games_words\":");
        try writeWordArray(w, self.games_words.items);
        try w.writeAll(",\"tech_words\":");
        try writeWordArray(w, self.tech_words.items);
        try w.writeAll(",\"finance_words\":");
        try writeWordArray(w, self.finance_words.items);
        try w.writeAll(",\"general_words\":");
        try writeWordArray(w, self.general_words.items);
        try w.writeAll(",\"genshin_characters\":");
        try writeWordArray(w, self.genshin_characters.items);
        try w.writeAll(",\"genshin_birthdays\":[");
        for (self.genshin_birthdays.items, 0..) |entry, idx| {
            if (idx > 0) try w.writeByte(',');
            try w.writeAll("{\"name\":");
            try utils.writeJsonString(w, entry.name);
            try w.writeAll(",\"birthday\":");
            try utils.writeJsonString(w, entry.birthday);
            try w.writeByte('}');
        }
        try w.writeAll("],\"custom_banks\":{");
        for (self.custom_bank_names.items, 0..) |bank_name, bi| {
            if (bi > 0) try w.writeByte(',');
            try utils.writeJsonString(w, bank_name);
            try w.writeByte(':');
            if (bi < self.custom_bank_words.items.len) {
                try writeWordArray(w, self.custom_bank_words.items[bi].items);
            } else {
                try w.writeAll("[]");
            }
        }
        try w.writeAll("}}");

        return buf.toOwnedSlice();
    }

    pub fn randomWord(self: *const TemplateData, category: Category) []const u8 {
        const words = switch (category) {
            .games => self.games_words.items,
            .tech => self.tech_words.items,
            .finance => self.finance_words.items,
            .general => self.general_words.items,
        };
        if (words.len == 0) return defaultRandomWord(category);
        return words[randomIndex(words.len)];
    }

    pub fn genshinBirthday(self: *const TemplateData, character: []const u8) ?[]const u8 {
        for (self.genshin_birthdays.items) |entry| {
            if (std.mem.eql(u8, entry.name, character)) return entry.birthday;
        }
        return null;
    }

    pub fn randomGenshinCharacter(self: *const TemplateData) []const u8 {
        if (self.genshin_characters.items.len == 0) return defaultRandomGenshinCharacter();
        return self.genshin_characters.items[randomIndex(self.genshin_characters.items.len)];
    }

    pub fn randomCustomWord(self: *const TemplateData, bank_name: []const u8) ?[]const u8 {
        for (self.custom_bank_names.items, 0..) |name, i| {
            if (std.mem.eql(u8, name, bank_name)) {
                if (i < self.custom_bank_words.items.len) {
                    const words = self.custom_bank_words.items[i].items;
                    if (words.len > 0) return words[randomIndex(words.len)];
                }
                return null;
            }
        }
        return null;
    }

    fn appendWords(self: *TemplateData, list: *std.ArrayListUnmanaged([]u8), source: []const []const u8) !void {
        for (source) |word| {
            try list.append(self.allocator, try self.allocator.dupe(u8, word));
        }
    }

    fn appendBirthdays(self: *TemplateData, source: []const BirthdayPair) !void {
        for (source) |entry| {
            try self.genshin_birthdays.append(self.allocator, .{
                .name = try self.allocator.dupe(u8, entry.name),
                .birthday = try self.allocator.dupe(u8, entry.birthday),
            });
        }
    }

    fn freeWordList(self: *TemplateData, list: *std.ArrayListUnmanaged([]u8)) void {
        for (list.items) |word| self.allocator.free(word);
        list.deinit(self.allocator);
    }

    fn freeBirthdayList(self: *TemplateData) void {
        for (self.genshin_birthdays.items) |entry| {
            self.allocator.free(entry.name);
            self.allocator.free(entry.birthday);
        }
        self.genshin_birthdays.deinit(self.allocator);
    }

    fn freeCustomBanks(self: *TemplateData) void {
        for (self.custom_bank_names.items) |name| self.allocator.free(name);
        self.custom_bank_names.deinit(self.allocator);
        for (self.custom_bank_words.items) |*list| {
            for (list.items) |word| self.allocator.free(word);
            list.deinit(self.allocator);
        }
        self.custom_bank_words.deinit(self.allocator);
    }

    fn replaceCustomBanks(self: *TemplateData, root: std.json.ObjectMap) !void {
        const cb_val = root.get("custom_banks") orelse return;
        const cb_obj = switch (cb_val) {
            .object => |o| o,
            else => return,
        };
        self.freeCustomBanks();
        self.custom_bank_names = .empty;
        self.custom_bank_words = .empty;

        var it = cb_obj.iterator();
        while (it.next()) |entry| {
            const bank_name = entry.key_ptr.*;
            const words_val = entry.value_ptr.*;
            const words_arr = switch (words_val) {
                .array => |a| a.items,
                else => continue,
            };
            try self.custom_bank_names.append(self.allocator, try self.allocator.dupe(u8, bank_name));
            var word_list: std.ArrayListUnmanaged([]u8) = .empty;
            for (words_arr) |item| {
                const raw = switch (item) {
                    .string => |s| s,
                    else => continue,
                };
                const trimmed = std.mem.trim(u8, raw, " \r\n\t");
                if (trimmed.len == 0) continue;
                try word_list.append(self.allocator, try self.allocator.dupe(u8, trimmed));
            }
            try self.custom_bank_words.append(self.allocator, word_list);
        }
    }

    fn replaceWordList(self: *TemplateData, root: std.json.ObjectMap, key: []const u8, list: *std.ArrayListUnmanaged([]u8)) !void {
        const value = root.get(key) orelse return;
        const items = switch (value) {
            .array => |arr| arr.items,
            else => return error.InvalidTemplateData,
        };

        self.freeWordList(list);
        list.* = .empty;

        for (items) |item| {
            const raw = switch (item) {
                .string => |s| s,
                else => return error.InvalidTemplateData,
            };
            const trimmed = std.mem.trim(u8, raw, " \r\n\t");
            if (trimmed.len == 0) continue;
            try list.append(self.allocator, try self.allocator.dupe(u8, trimmed));
        }
    }

    fn replaceBirthdayList(self: *TemplateData, root: std.json.ObjectMap, key: []const u8) !void {
        const value = root.get(key) orelse return;
        const items = switch (value) {
            .array => |arr| arr.items,
            else => return error.InvalidTemplateData,
        };

        self.freeBirthdayList();
        self.genshin_birthdays = .empty;

        for (items) |item| {
            const obj = switch (item) {
                .object => |o| o,
                else => return error.InvalidTemplateData,
            };
            const raw_name = switch (obj.get("name") orelse return error.InvalidTemplateData) {
                .string => |s| s,
                else => return error.InvalidTemplateData,
            };
            const raw_birthday = switch (obj.get("birthday") orelse return error.InvalidTemplateData) {
                .string => |s| s,
                else => return error.InvalidTemplateData,
            };
            const name = std.mem.trim(u8, raw_name, " \r\n\t");
            const birthday = std.mem.trim(u8, raw_birthday, " \r\n\t");
            if (name.len == 0 or birthday.len == 0) continue;
            try self.genshin_birthdays.append(self.allocator, .{
                .name = try self.allocator.dupe(u8, name),
                .birthday = try self.allocator.dupe(u8, birthday),
            });
        }
    }
};

fn writeWordArray(writer: *std.Io.Writer, words: []const []const u8) !void {
    try writer.writeByte('[');
    for (words, 0..) |word, idx| {
        if (idx > 0) try writer.writeByte(',');
        try utils.writeJsonString(writer, word);
    }
    try writer.writeByte(']');
}

fn randomIndex(len: usize) usize {
    var buf: [8]u8 = undefined;
    compat.randomBytes(&buf);
    return @as(usize, @intCast(std.mem.readInt(u64, &buf, .little) % len));
}

fn defaultRandomWord(category: Category) []const u8 {
    const words: []const []const u8 = switch (category) {
        .games => &default_games_words,
        .tech => &default_tech_words,
        .finance => &default_finance_words,
        .general => &default_general_words,
    };
    return words[randomIndex(words.len)];
}

fn defaultRandomGenshinCharacter() []const u8 {
    return default_genshin_characters[randomIndex(default_genshin_characters.len)];
}

// ═══════════════════════════════════════════════════════════════════
//  Public Static API
// ═══════════════════════════════════════════════════════════════════

pub fn randomWord(category: Category) []const u8 {
    return defaultRandomWord(category);
}

pub fn genshinBirthday(character: []const u8) ?[]const u8 {
    for (&default_genshin_birthdays) |entry| {
        if (std.mem.eql(u8, entry.name, character)) return entry.birthday;
    }
    return null;
}

pub fn randomGenshinCharacter() []const u8 {
    return defaultRandomGenshinCharacter();
}

pub fn getWords(category: Category) []const []const u8 {
    return switch (category) {
        .games => &default_games_words,
        .tech => &default_tech_words,
        .finance => &default_finance_words,
        .general => &default_general_words,
    };
}

pub fn getCategories() []const Category {
    return &[_]Category{ .games, .tech, .finance, .general };
}

pub fn getGenshinCharacters() []const []const u8 {
    return &default_genshin_characters;
}

pub fn getGenshinBirthdays() []const BirthdayPair {
    return &default_genshin_birthdays;
}

// ═══════════════════════════════════════════════════════════════════
//  Tests
// ═══════════════════════════════════════════════════════════════════

test "randomWord returns a valid word" {
    const word = randomWord(.games);
    try std.testing.expect(word.len > 0);
}

test "randomWord tech" {
    const word = randomWord(.tech);
    try std.testing.expect(word.len > 0);
}

test "genshinBirthday known" {
    const bd = genshinBirthday("funingna");
    try std.testing.expect(bd != null);
    try std.testing.expectEqualStrings("1013", bd.?);
}

test "genshinBirthday unknown" {
    const bd = genshinBirthday("nonexistent");
    try std.testing.expect(bd == null);
}

test "randomGenshinCharacter" {
    const char = randomGenshinCharacter();
    try std.testing.expect(char.len > 0);
}

test "category fromString" {
    try std.testing.expect(Category.fromString("games") == .games);
    try std.testing.expect(Category.fromString("tech") == .tech);
    try std.testing.expect(Category.fromString("nope") == null);
}

test "template data round-trip" {
    const allocator = std.testing.allocator;
    var data = try TemplateData.initDefaults(allocator);
    defer data.deinit();

    const json = try data.toJson(allocator);
    defer allocator.free(json);

    var loaded = try TemplateData.fromJson(allocator, json);
    defer loaded.deinit();

    try std.testing.expect(loaded.tech_words.items.len > 0);
    try std.testing.expect(loaded.genshin_birthdays.items.len > 0);
}
