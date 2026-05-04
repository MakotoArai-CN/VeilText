pub const config = @import("config.zig");
pub const compat = @import("compat.zig");
pub const utils = @import("utils.zig");
pub const server = @import("server.zig");
pub const terminal = @import("terminal.zig");
pub const output = @import("output.zig");

// Crypto modules
pub const crypto_base = @import("crypto/base.zig");
pub const crypto_symmetric = @import("crypto/symmetric.zig");
pub const crypto_asymmetric = @import("crypto/asymmetric.zig");
pub const crypto_hash = @import("crypto/hash.zig");
pub const crypto_kdf = @import("crypto/kdf.zig");
pub const crypto_engine = @import("crypto/engine.zig");
pub const crypto_jsobfuscation = @import("crypto/jsobfuscation.zig");
pub const crypto_brainfuck = @import("crypto/brainfuck.zig");
pub const crypto_openssl_compat = @import("crypto/openssl_compat.zig");
pub const crypto_puzzle = @import("crypto/puzzle.zig");
pub const crypto_record = @import("crypto/record.zig");

// Generator modules
pub const gen_date = @import("generator/date.zig");
pub const gen_random = @import("generator/random.zig");
pub const gen_wordbank = @import("generator/wordbank.zig");
pub const gen_news = @import("generator/news.zig");
pub const gen_ai = @import("generator/ai.zig");
pub const generator = @import("generator/generator.zig");

// Storage modules
pub const db = @import("storage/db.zig");
pub const history = @import("storage/history.zig");

// i18n modules
pub const i18n = @import("i18n/i18n.zig");

// View modules
pub const view_layout = @import("view/layout.zig");
pub const view_theme = @import("view/theme.zig");

test {
    @import("std").testing.refAllDecls(@This());
}
