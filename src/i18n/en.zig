// ═══════════════════════════════════════════════════════════════════
//  English (en) Translations — Fallback language
// ═══════════════════════════════════════════════════════════════════

const i18n = @import("i18n.zig");

pub const strings: i18n.Strings = .{
    // App
    .app_title = "VeilText",
    .app_subtitle = "Text Encryption Toolkit",
    .app_description = "Encrypt text into another text. Multi-algorithm nesting, puzzle splitting, AI generation and more.",

    // Navigation
    .nav_encrypt = "Encrypt",
    .nav_decrypt = "Decrypt",
    .nav_puzzle = "Puzzle",
    .nav_generate = "Generate",
    .nav_history = "History",
    .nav_settings = "Settings",

    // Encrypt page
    .encrypt_title = "Text Encryption",
    .encrypt_input_placeholder = "Enter text to encrypt...",
    .encrypt_key_placeholder = "Enter key (required for symmetric encryption)",
    .encrypt_btn = "Encrypt",
    .encrypt_result = "Encryption Result",
    .encrypt_pipeline = "Encryption Pipeline",
    .encrypt_add_step = "Add Step",

    // Decrypt page
    .decrypt_title = "Text Decryption",
    .decrypt_input_placeholder = "Paste ciphertext to decrypt...",
    .decrypt_key_placeholder = "Enter decryption key",
    .decrypt_btn = "Decrypt",
    .decrypt_ai_decode = "AI Decode",
    .decrypt_result = "Decryption Result",
    .decrypt_verify_ok = "Verification Passed",
    .decrypt_verify_fail = "Verification Failed",

    // Puzzle page
    .puzzle_title = "Puzzle Split",
    .puzzle_split = "Split",
    .puzzle_merge = "Merge",
    .puzzle_pieces = "Pieces",
    .puzzle_piece_n = "Piece",

    // Generate page
    .generate_title = "Plaintext Generation",
    .generate_template_placeholder = "Enter template, e.g.: sk-{date}-{game:genshin:character}",
    .generate_btn = "Generate",
    .generate_result = "Generation Result",
    .generate_then_encrypt = "Generate & Encrypt",

    // History
    .history_title = "Encryption History",
    .history_empty = "No history records",
    .history_clear = "Clear All",
    .history_delete = "Delete",

    // Settings
    .settings_title = "Settings",
    .settings_theme = "Theme",
    .settings_language = "Language",
    .settings_ai_config = "AI Configuration",
    .settings_api_key = "API Key",
    .settings_api_endpoint = "API Endpoint",

    // Common
    .copy = "Copy",
    .copied = "Copied",
    .paste = "Paste",
    .clear = "Clear",
    .export_text = "Export",
    .verify = "Verify",
    .loading = "Loading...",
    .error_text = "Error",
    .success = "Success",
    .cancel = "Cancel",
    .confirm = "Confirm",

    // Themes
    .theme_auto = "Follow System",
    .theme_light_jade = "Jade Light",
    .theme_dark_ocean = "Ocean Dark",
    .theme_sakura = "Sakura",
    .theme_midnight = "Midnight",
    .theme_amber = "Amber",

    // Algorithms
    .algo_base16 = "Base16 (Hex)",
    .algo_base32 = "Base32",
    .algo_base58 = "Base58",
    .algo_base64 = "Base64",
    .algo_base85 = "Base85",
    .algo_aes = "AES-256-GCM",
    .algo_chacha = "ChaCha20-Poly1305",
    .algo_xchacha = "XChaCha20-Poly1305",

    // Toast messages
    .toast_encrypt_success = "Encryption successful",
    .toast_decrypt_success = "Decryption successful",
    .toast_copy_success = "Copied to clipboard",
    .toast_error_no_input = "Please enter text",
    .toast_error_no_key = "Please enter a key",

    // Template variables / Chips
    .settings_template_vars = "Template Variables",
    .settings_template_desc = "Manage template chips on the Generate page. Click to edit, \xc3\x97 to remove.",
    .chip_add = "+ Add",
    .chip_reset = "Reset to Defaults",
    .chip_edit_label = "Edit Label",
    .chip_edit_value = "Edit Template Value",
    .chip_name_placeholder = "Label (e.g. my-var)",
    .chip_value_placeholder = "Template (e.g. {random:6})",
    .var_ref_title = "Available Variables",
    .var_ref_desc = "Click to insert into template. Custom chips can use these variables.",
    .template_data_title = "Built-in Template Data",
    .template_data_desc = "Edit the actual built-in values used during generation. Word lists use one item per line. Genshin birthdays use name=MMDD.",
    .template_data_games = "Games Word Bank",
    .template_data_tech = "Tech Word Bank",
    .template_data_finance = "Finance Word Bank",
    .template_data_general = "General Word Bank",
    .template_data_genshin_characters = "Genshin Characters",
    .template_data_genshin_birthdays = "Genshin Birthdays",

    // Puzzle enhancements
    .puzzle_encrypt_option = "Encrypt Pieces",
    .puzzle_encrypt_method = "Encryption Method",
    .puzzle_copy_piece = "Copy",
    .puzzle_input_placeholder = "Enter text to split / paste pieces to merge",

    // Common extra
    .save = "Save",
    .add = "Add",
    .edit = "Edit",
    .delete_text = "Delete",

    // Generate enhancements
    .generate_then_split = "Generate & Split",

    // AI page
    .nav_ai = "AI",
    .ai_title = "AI Assistant",
    .ai_placeholder = "Type a message...",
    .ai_send = "Send",
    .ai_test_connection = "Test Connection",
    .ai_provider = "Provider",
    .ai_model = "Model",
    .ai_mode_chat = "Chat",
    .ai_mode_encrypt = "Encrypt",
    .ai_mode_decrypt = "Decrypt",
    .ai_mode_puzzle = "Puzzle",
    .ai_mode_generate = "Generate",
    .ai_no_key = "Please configure API key in Settings",
    .ai_thinking = "Thinking...",
    .ai_connected = "Connected",
    .ai_connect_failed = "Connection Failed",
};
