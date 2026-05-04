const std = @import("std");

// ═══════════════════════════════════════════════════════════════════
//  Application Constants
// ═══════════════════════════════════════════════════════════════════

/// Application name.
pub const app_name = "VeilText";

/// Application version.
pub const app_version = "0.1.0";

/// Default HTTP listen port.
pub const default_port: u16 = 7478;

/// Default bind address.
pub const default_bind: []const u8 = "127.0.0.1";

/// Max concurrent connections.
pub const default_concurrency: usize = 256;

/// Data directory for persistent storage.
pub const data_dir = ".veiltext-data";

/// Database file name.
pub const db_file = ".veiltext.db";

/// Maximum upload file size in MB (0 = unlimited).
pub const max_file_size_mb: u64 = 256;

/// History records max count (0 = unlimited).
pub const max_history_records: u32 = 1000;

// ═══════════════════════════════════════════════════════════════════
//  Crypto Defaults
// ═══════════════════════════════════════════════════════════════════

/// Default PBKDF2 iteration count.
pub const pbkdf2_iterations: u32 = 200_000;

/// Default Argon2 memory cost in KiB.
pub const argon2_memory_kib: u32 = 65536;

/// Default Argon2 time cost (iterations).
pub const argon2_time_cost: u32 = 3;

/// Default Argon2 parallelism.
pub const argon2_parallelism: u32 = 4;

// ═══════════════════════════════════════════════════════════════════
//  AI / External API Defaults
// ═══════════════════════════════════════════════════════════════════

/// Default OpenAI-compatible API endpoint.
pub const default_openai_endpoint = "https://api.openai.com/v1";

/// Default Claude API endpoint.
pub const default_claude_endpoint = "https://api.anthropic.com/v1";

/// HTTP request timeout in milliseconds.
pub const http_timeout_ms: u64 = 30_000;

// ═══════════════════════════════════════════════════════════════════
//  Supported Languages
// ═══════════════════════════════════════════════════════════════════

pub const Language = enum {
    zh,
    ja,
    en,

    pub fn code(self: Language) []const u8 {
        return switch (self) {
            .zh => "zh",
            .ja => "ja",
            .en => "en",
        };
    }

    pub fn displayName(self: Language) []const u8 {
        return switch (self) {
            .zh => "\xe4\xb8\xad\xe6\x96\x87",
            .ja => "\xe6\x97\xa5\xe6\x9c\xac\xe8\xaa\x9e",
            .en => "English",
        };
    }

    pub fn fromAcceptLanguage(header: []const u8) Language {
        // Simple parsing: check for "zh", "ja" prefixes
        var it = std.mem.splitScalar(u8, header, ',');
        while (it.next()) |part| {
            const trimmed = std.mem.trim(u8, part, " ");
            // Strip quality factor
            const lang = if (std.mem.indexOfScalar(u8, trimmed, ';')) |idx|
                trimmed[0..idx]
            else
                trimmed;
            const lower = std.mem.trim(u8, lang, " ");
            if (lower.len >= 2) {
                if (std.mem.startsWith(u8, lower, "zh")) return .zh;
                if (std.mem.startsWith(u8, lower, "ja")) return .ja;
                if (std.mem.startsWith(u8, lower, "en")) return .en;
            }
        }
        return .en; // Default fallback
    }
};

// ═══════════════════════════════════════════════════════════════════
//  Themes
// ═══════════════════════════════════════════════════════════════════

pub const Theme = enum {
    auto,
    light_jade,
    dark_ocean,
    sakura,
    midnight,
    amber,

    pub fn cssName(self: Theme) []const u8 {
        return switch (self) {
            .auto => "auto",
            .light_jade => "light-jade",
            .dark_ocean => "dark-ocean",
            .sakura => "sakura",
            .midnight => "midnight",
            .amber => "amber",
        };
    }
};

// ═══════════════════════════════════════════════════════════════════
//  Runtime Configuration (CLI overridable)
// ═══════════════════════════════════════════════════════════════════

pub const Runtime = struct {
    port: u16 = default_port,
    bind_host: []const u8 = default_bind,
    concurrency_limit: usize = default_concurrency,
    data_dir: []const u8 = data_dir,
    db_file: []const u8 = db_file,

    // AI API settings
    openai_endpoint: []const u8 = default_openai_endpoint,
    openai_api_key: []const u8 = "",
    claude_endpoint: []const u8 = default_claude_endpoint,
    claude_api_key: []const u8 = "",

    pub fn maxBytes(self: Runtime) u64 {
        _ = self;
        return if (max_file_size_mb > 0) max_file_size_mb * 1024 * 1024 else 0;
    }
};
