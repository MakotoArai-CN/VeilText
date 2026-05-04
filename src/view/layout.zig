const std = @import("std");
const config = @import("../config.zig");
const i18n_mod = @import("../i18n/i18n.zig");
const theme = @import("theme.zig");

pub fn renderApp(writer: *std.Io.Writer, lang: config.Language) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const aa = arena.allocator();

    const t = i18n_mod.getStrings(lang);
    const i18n_json = try i18n_mod.toJson(aa);
    defer aa.free(i18n_json);

    try writer.writeAll("<!doctype html><html><head><meta charset=\"utf-8\">");
    try writer.writeAll("<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">");
    try writer.writeAll("<title>VeilText</title>");
    try writer.writeAll("<script>!function(){var t=localStorage.getItem('vt-theme');");
    try writer.writeAll("if(t&&t!=='auto')document.documentElement.setAttribute('data-theme',t)}()</script>");
    try writer.writeAll("<style>");
    try writer.writeAll(theme.theme_css);
    try writer.writeAll(theme.base_css);
    try writer.writeAll("</style></head><body><div class=\"app\">");

    try renderSidebar(writer, t, lang);
    try writer.writeAll("<main class=\"main\">");
    try renderEncryptPage(writer, t);
    try renderDecryptPage(writer, t);
    try renderPuzzlePage(writer, t);
    try renderGeneratePage(writer, t);
    try renderAiPage(writer, t);
    try renderHistoryPage(writer, t);
    try renderSettingsPage(writer, t);
    try writer.writeAll("</main></div>");

    try writer.writeAll("<div class=\"toast-container\" id=\"toast-container\"></div>");

    // Modal overlay
    try writer.writeAll("<div id=\"modal-overlay\" class=\"modal-overlay\" style=\"display:none\">");
    try writer.writeAll("<div class=\"modal-card\">");
    try writer.writeAll("<h3 class=\"modal-title\" id=\"modal-title\"></h3>");
    try writer.writeAll("<div id=\"modal-body\"></div>");
    try writer.writeAll("<div class=\"modal-actions\">");
    try writer.writeAll("<button class=\"btn btn-secondary btn-sm\" onclick=\"closeModal()\">");
    try writer.writeAll(t.cancel);
    try writer.writeAll("</button><button class=\"btn btn-primary btn-sm\" id=\"modal-ok\">");
    try writer.writeAll(t.confirm);
    try writer.writeAll("</button></div></div></div>");

    try writer.writeAll("<script>var VT_LANG=\"");
    try writer.writeAll(lang.code());
    try writer.writeAll("\";var VT_I18N=");
    try writer.writeAll(i18n_json);
    try writer.writeAll(";");
    try writer.writeAll(app_js);
    try writer.writeAll("</script></body></html>");
}

fn renderSidebar(w: *std.Io.Writer, t: anytype, lang: config.Language) !void {
    try w.writeAll("<nav class=\"sidebar\"><div class=\"sidebar-logo\">VT</div>");
    try renderNavBtn(w, "encrypt", icon_lock, t.nav_encrypt, true);
    try renderNavBtn(w, "decrypt", icon_unlock, t.nav_decrypt, false);
    try renderNavBtn(w, "puzzle", icon_puzzle, t.nav_puzzle, false);
    try renderNavBtn(w, "generate", icon_dice, t.nav_generate, false);
    try renderNavBtn(w, "ai", icon_ai, t.nav_ai, false);
    try renderNavBtn(w, "history", icon_clock, t.nav_history, false);
    try renderNavBtn(w, "settings", icon_gear, t.nav_settings, false);
    try w.writeAll("<div class=\"nav-spacer\"></div>");
    try w.writeAll("<button class=\"nav-btn\" onclick=\"cycleTheme()\">");
    try w.writeAll(icon_sun);
    try w.writeAll("<span>Theme</span></button>");
    try w.writeAll("<button class=\"nav-btn\" onclick=\"cycleLang()\">");
    try w.writeAll(icon_globe);
    try w.writeAll("<span id=\"lang-label\">");
    try w.writeAll(lang.code());
    try w.writeAll("</span></button></nav>");
}

fn renderNavBtn(w: *std.Io.Writer, id: []const u8, icon: []const u8, label: []const u8, active: bool) !void {
    try w.writeAll("<button class=\"nav-btn");
    if (active) try w.writeAll(" active");
    try w.writeAll("\" onclick=\"showPage('");
    try w.writeAll(id);
    try w.writeAll("')\" data-nav=\"");
    try w.writeAll(id);
    try w.writeAll("\">");
    try w.writeAll(icon);
    try w.writeAll("<span>");
    try w.writeAll(label);
    try w.writeAll("</span></button>");
}

fn renderEncryptPage(w: *std.Io.Writer, t: anytype) !void {
    try w.writeAll("<div id=\"page-encrypt\" class=\"page active\"><div class=\"card\">");
    try w.writeAll("<div class=\"card-header\"><span class=\"card-badge\">ENCRYPT</span><h2 class=\"card-title\">");
    try w.writeAll(t.encrypt_title);
    try w.writeAll("</h2></div>");
    try w.writeAll("<textarea id=\"encrypt-input\" placeholder=\"");
    try w.writeAll(t.encrypt_input_placeholder);
    try w.writeAll("\"></textarea>");
    try w.writeAll("<div class=\"pipeline\" id=\"encrypt-pipeline\"></div>");
    try w.writeAll("<div class=\"toolbar\">");
    try renderAlgoSelect(w, "algo-select");
    try w.writeAll("<button class=\"btn btn-secondary btn-sm\" onclick=\"addStep()\">");
    try w.writeAll(t.encrypt_add_step);
    try w.writeAll("</button><div class=\"toolbar-spacer\"></div>");
    try w.writeAll("<input type=\"password\" class=\"text-input\" id=\"encrypt-key\" placeholder=\"");
    try w.writeAll(t.encrypt_key_placeholder);
    try w.writeAll("\" style=\"max-width:260px\"></div>");
    try w.writeAll("<div style=\"margin-top:16px\"><button class=\"btn btn-primary\" onclick=\"doEncrypt()\">");
    try w.writeAll(t.encrypt_btn);
    try w.writeAll("</button></div></div>");
    try w.writeAll("<div class=\"card\" id=\"encrypt-result-card\" style=\"display:none\">");
    try w.writeAll("<div class=\"card-header\"><span class=\"card-badge\">RESULT</span><h2 class=\"card-title\">");
    try w.writeAll(t.encrypt_result);
    try w.writeAll("</h2></div><div class=\"result-box\" id=\"encrypt-result\"></div>");
    try w.writeAll("<div class=\"toolbar\" style=\"margin-top:12px\">");
    try w.writeAll("<button class=\"btn btn-secondary btn-sm\" onclick=\"copyResult('encrypt-result')\">");
    try w.writeAll(t.copy);
    try w.writeAll("</button></div></div></div>");
}

fn renderDecryptPage(w: *std.Io.Writer, t: anytype) !void {
    try w.writeAll("<div id=\"page-decrypt\" class=\"page\"><div class=\"card\">");
    try w.writeAll("<div class=\"card-header\"><span class=\"card-badge\">DECRYPT</span><h2 class=\"card-title\">");
    try w.writeAll(t.decrypt_title);
    try w.writeAll("</h2></div>");
    try w.writeAll("<textarea id=\"decrypt-input\" placeholder=\"");
    try w.writeAll(t.decrypt_input_placeholder);
    try w.writeAll("\"></textarea>");
    try w.writeAll("<div class=\"pipeline\" id=\"decrypt-pipeline\"></div>");
    try w.writeAll("<div class=\"toolbar\">");
    try renderAlgoSelect(w, "dalgo-select");
    try w.writeAll("<button class=\"btn btn-secondary btn-sm\" onclick=\"addDStep()\">");
    try w.writeAll(t.encrypt_add_step);
    try w.writeAll("</button><div class=\"toolbar-spacer\"></div>");
    try w.writeAll("<input type=\"password\" class=\"text-input\" id=\"decrypt-key\" placeholder=\"");
    try w.writeAll(t.decrypt_key_placeholder);
    try w.writeAll("\" style=\"max-width:260px\"></div>");
    try w.writeAll("<input type=\"text\" class=\"text-input\" id=\"decrypt-hash\" placeholder=\"SHA-256 hash (optional)\" style=\"margin-top:8px;max-width:400px\">");
    try w.writeAll("<div class=\"decrypt-actions\" style=\"margin-top:16px\"><button class=\"btn btn-primary\" onclick=\"doDecrypt()\">");
    try w.writeAll(t.decrypt_btn);
    try w.writeAll("</button><button class=\"btn btn-secondary\" id=\"smart-decode-btn\" onclick=\"doSmartDecode()\">");
    try w.writeAll(t.decrypt_ai_decode);
    try w.writeAll("</button></div></div>");
    try w.writeAll("<div class=\"card\" id=\"decrypt-result-card\" style=\"display:none\">");
    try w.writeAll("<div class=\"card-header\"><span class=\"card-badge\">RESULT</span><h2 class=\"card-title\">");
    try w.writeAll(t.decrypt_result);
    try w.writeAll("</h2></div><div class=\"result-box\" id=\"decrypt-result\"></div>");
    try w.writeAll("<div id=\"decrypt-verify\" style=\"margin-top:8px;font-weight:700\"></div>");
    try w.writeAll("<div id=\"decrypt-ai-detail\" class=\"ai-decode-detail\" style=\"display:none\"></div>");
    try w.writeAll("<div class=\"toolbar\" style=\"margin-top:12px\">");
    try w.writeAll("<button class=\"btn btn-secondary btn-sm\" onclick=\"copyResult('decrypt-result')\">");
    try w.writeAll(t.copy);
    try w.writeAll("</button></div></div></div>");
}

fn renderAlgoSelect(w: *std.Io.Writer, id: []const u8) !void {
    try w.writeAll("<div class=\"custom-select\" id=\"");
    try w.writeAll(id);
    try w.writeAll("\" data-value=\"base64\">");
    try w.writeAll("<div class=\"custom-select-trigger\" onclick=\"toggleDD(this,event)\"><span>Base64</span><span class=\"arrow\">\xe2\x96\xbe</span></div>");
    try w.writeAll("<div class=\"custom-select-options\">");
    try w.writeAll("<div class=\"custom-select-option selected\" data-value=\"base64\" onclick=\"selOpt(this)\">Base64</div>");
    try w.writeAll("<div class=\"custom-select-option\" data-value=\"base32\" onclick=\"selOpt(this)\">Base32</div>");
    try w.writeAll("<div class=\"custom-select-option\" data-value=\"base16\" onclick=\"selOpt(this)\">Base16</div>");
    try w.writeAll("<div class=\"custom-select-option\" data-value=\"base58\" onclick=\"selOpt(this)\">Base58</div>");
    try w.writeAll("<div class=\"custom-select-option\" data-value=\"base85\" onclick=\"selOpt(this)\">Base85</div>");
    try w.writeAll("<div class=\"custom-select-option\" data-value=\"aes_256_gcm\" onclick=\"selOpt(this)\">AES-256-GCM</div>");
    try w.writeAll("<div class=\"custom-select-option\" data-value=\"chacha20_poly1305\" onclick=\"selOpt(this)\">ChaCha20-Poly1305</div>");
    try w.writeAll("<div class=\"custom-select-option\" data-value=\"xchacha20_poly1305\" onclick=\"selOpt(this)\">XChaCha20-Poly1305</div>");
    try w.writeAll("<div class=\"custom-select-option\" data-value=\"aes_256_cbc\" onclick=\"selOpt(this)\">AES-256-CBC (OpenSSL/CryptoJS)</div>");
    try w.writeAll("<div class=\"custom-select-separator\">\xe2\x94\x80\xe2\x94\x80 JS Obfuscation \xe2\x94\x80\xe2\x94\x80</div>");
    try w.writeAll("<div class=\"custom-select-option\" data-value=\"js_hex_escape\" onclick=\"selOpt(this)\">Hex Escape (\\xNN)</div>");
    try w.writeAll("<div class=\"custom-select-option\" data-value=\"js_unicode_escape\" onclick=\"selOpt(this)\">Unicode Escape (\\uNNNN)</div>");
    try w.writeAll("<div class=\"custom-select-option\" data-value=\"js_binary_string\" onclick=\"selOpt(this)\">Binary String</div>");
    try w.writeAll("<div class=\"custom-select-option\" data-value=\"js_jjencode\" onclick=\"selOpt(this)\">JJEncode</div>");
    try w.writeAll("<div class=\"custom-select-option\" data-value=\"js_aaencode\" onclick=\"selOpt(this)\">AAEncode</div>");
    try w.writeAll("<div class=\"custom-select-option\" data-value=\"js_jsfuck\" onclick=\"selOpt(this)\">JSFuck</div>");
    try w.writeAll("<div class=\"custom-select-option\" data-value=\"js_eval_wrap\" onclick=\"selOpt(this)\">Eval Wrap</div>");
    try w.writeAll("<div class=\"custom-select-option\" data-value=\"js_constructor_wrap\" onclick=\"selOpt(this)\">Constructor Wrap</div>");
    try w.writeAll("<div class=\"custom-select-option\" data-value=\"js_base36_tostring\" onclick=\"selOpt(this)\">Base36 ToString</div>");
    try w.writeAll("<div class=\"custom-select-separator\">\xe2\x94\x80\xe2\x94\x80 Brainfuck \xe2\x94\x80\xe2\x94\x80</div>");
    try w.writeAll("<div class=\"custom-select-option\" data-value=\"bf_text\" onclick=\"selOpt(this)\">Brainfuck</div>");
    try w.writeAll("<div class=\"custom-select-option\" data-value=\"bf_emoji\" onclick=\"selOpt(this)\">Brainfuck (Emoji)</div>");
    try w.writeAll("</div></div>");
}

fn renderPuzzleAlgoSelect(w: *std.Io.Writer) !void {
    try w.writeAll("<div class=\"custom-select\" id=\"puzzle-algo-select\" data-value=\"aes_256_gcm\">");
    try w.writeAll("<div class=\"custom-select-trigger\" onclick=\"toggleDD(this,event)\"><span>AES-256-GCM</span><span class=\"arrow\">\xe2\x96\xbe</span></div>");
    try w.writeAll("<div class=\"custom-select-options\">");
    try w.writeAll("<div class=\"custom-select-option selected\" data-value=\"aes_256_gcm\" onclick=\"selOpt(this)\">AES-256-GCM</div>");
    try w.writeAll("<div class=\"custom-select-option\" data-value=\"chacha20_poly1305\" onclick=\"selOpt(this)\">ChaCha20-Poly1305</div>");
    try w.writeAll("<div class=\"custom-select-option\" data-value=\"xchacha20_poly1305\" onclick=\"selOpt(this)\">XChaCha20-Poly1305</div>");
    try w.writeAll("<div class=\"custom-select-option\" data-value=\"aes_256_cbc\" onclick=\"selOpt(this)\">AES-256-CBC (OpenSSL/CryptoJS)</div>");
    try w.writeAll("<div class=\"custom-select-option\" data-value=\"base64\" onclick=\"selOpt(this)\">Base64</div>");
    try w.writeAll("<div class=\"custom-select-option\" data-value=\"base32\" onclick=\"selOpt(this)\">Base32</div>");
    try w.writeAll("<div class=\"custom-select-option\" data-value=\"base16\" onclick=\"selOpt(this)\">Base16</div>");
    try w.writeAll("<div class=\"custom-select-option\" data-value=\"base58\" onclick=\"selOpt(this)\">Base58</div>");
    try w.writeAll("<div class=\"custom-select-option\" data-value=\"base85\" onclick=\"selOpt(this)\">Base85</div>");
    try w.writeAll("</div></div>");
}

fn renderPuzzlePage(w: *std.Io.Writer, t: anytype) !void {
    try w.writeAll("<div id=\"page-puzzle\" class=\"page\"><div class=\"card\">");
    try w.writeAll("<div class=\"card-header\"><span class=\"card-badge\">PUZZLE</span><h2 class=\"card-title\">");
    try w.writeAll(t.puzzle_title);
    try w.writeAll("</h2></div>");
    try w.writeAll("<textarea id=\"puzzle-input\" placeholder=\"");
    try w.writeAll(t.puzzle_input_placeholder);
    try w.writeAll("\"></textarea>");
    try w.writeAll("<div class=\"toolbar\" style=\"margin-top:12px\">");
    try w.writeAll("<label style=\"font-size:13px;font-weight:600\">");
    try w.writeAll(t.puzzle_pieces);
    try w.writeAll(": </label><input type=\"number\" class=\"num-input\" id=\"puzzle-count\" value=\"3\" min=\"2\" max=\"10\">");
    try w.writeAll("<div class=\"toggle\" onclick=\"togglePuzzleEncrypt()\" style=\"margin-left:12px\">");
    try w.writeAll("<div class=\"toggle-track\" id=\"puzzle-encrypt-track\"><div class=\"toggle-knob\"></div></div>");
    try w.writeAll("<span class=\"toggle-label\">");
    try w.writeAll(t.puzzle_encrypt_option);
    try w.writeAll("</span></div>");
    try w.writeAll("<div class=\"toolbar-spacer\"></div>");
    try w.writeAll("<button class=\"btn btn-primary btn-sm\" onclick=\"doPuzzleSplit()\">");
    try w.writeAll(t.puzzle_split);
    try w.writeAll("</button><button class=\"btn btn-secondary btn-sm\" onclick=\"doPuzzleMerge()\">");
    try w.writeAll(t.puzzle_merge);
    try w.writeAll("</button></div>");
    // Encrypt options panel
    try w.writeAll("<div id=\"puzzle-encrypt-opts\" style=\"display:none;margin-top:10px;padding:12px;border-radius:12px;background:var(--surface-alt)\">");
    try w.writeAll("<div style=\"display:flex;gap:10px;align-items:center;flex-wrap:wrap\">");
    try w.writeAll("<label style=\"font-size:13px;font-weight:600\">");
    try w.writeAll(t.puzzle_encrypt_method);
    try w.writeAll(": </label>");
    try renderPuzzleAlgoSelect(w);
    try w.writeAll("<input type=\"password\" class=\"text-input\" id=\"puzzle-key\" placeholder=\"");
    try w.writeAll(t.encrypt_key_placeholder);
    try w.writeAll("\" style=\"flex:1;max-width:260px\">");
    try w.writeAll("</div></div>");
    try w.writeAll("</div>");
    try w.writeAll("<div class=\"card\" id=\"puzzle-result-card\" style=\"display:none\">");
    try w.writeAll("<div class=\"card-header\"><span class=\"card-badge\">PIECES</span><h2 class=\"card-title\">");
    try w.writeAll(t.puzzle_piece_n);
    try w.writeAll("</h2></div><div id=\"puzzle-pieces\"></div></div></div>");
}

fn renderGeneratePage(w: *std.Io.Writer, t: anytype) !void {
    try w.writeAll("<div id=\"page-generate\" class=\"page\"><div class=\"card\">");
    try w.writeAll("<div class=\"card-header\"><span class=\"card-badge\">GENERATE</span><h2 class=\"card-title\">");
    try w.writeAll(t.generate_title);
    try w.writeAll("</h2></div>");
    try w.writeAll("<textarea id=\"gen-template\" placeholder=\"");
    try w.writeAll(t.generate_template_placeholder);
    try w.writeAll("\" style=\"min-height:80px\"></textarea>");

    // Chips container
    try w.writeAll("<div class=\"chips-section\" style=\"margin-top:12px\">");
    try w.writeAll("<div class=\"chips-header\" style=\"display:flex;align-items:center;gap:8px;margin-bottom:8px\">");
    try w.writeAll("<span style=\"font-size:13px;font-weight:600;color:var(--text-muted)\">");
    try w.writeAll(t.settings_template_vars);
    try w.writeAll("</span>");
    try w.writeAll("<button class=\"btn btn-secondary\" style=\"font-size:11px;padding:2px 8px\" onclick=\"showAddChip()\">");
    try w.writeAll(t.chip_add);
    try w.writeAll("</button>");
    try w.writeAll("</div>");
    try w.writeAll("<div id=\"gen-chips\" class=\"chips-container\" style=\"display:flex;flex-wrap:wrap;gap:6px\"></div>");
    try w.writeAll("</div>");

    // Add custom chip dialog (hidden)
    try w.writeAll("<div id=\"chip-dialog\" style=\"display:none;margin-top:10px;padding:12px;border-radius:8px;background:var(--surface-alt)\">");
    try w.writeAll("<div style=\"display:flex;gap:8px;align-items:center\">");
    try w.writeAll("<input type=\"text\" class=\"text-input\" id=\"chip-name\" placeholder=\"");
    try w.writeAll(t.chip_name_placeholder);
    try w.writeAll("\" style=\"flex:1\">");
    try w.writeAll("<input type=\"text\" class=\"text-input\" id=\"chip-value\" placeholder=\"");
    try w.writeAll(t.chip_value_placeholder);
    try w.writeAll("\" style=\"flex:1\">");
    try w.writeAll("<button class=\"btn btn-primary btn-sm\" onclick=\"addCustomChip()\">");
    try w.writeAll(t.add);
    try w.writeAll("</button><button class=\"btn btn-secondary btn-sm\" onclick=\"hideAddChip()\">");
    try w.writeAll(t.cancel);
    try w.writeAll("</button></div></div>");

    // Variable reference (collapsible, grouped)
    try w.writeAll("<details class=\"var-ref\" style=\"margin-top:12px\">");
    try w.writeAll("<summary style=\"cursor:pointer;font-size:13px;font-weight:600;color:var(--text-muted);user-select:none\">");
    try w.writeAll(t.var_ref_title);
    try w.writeAll("</summary>");
    try w.writeAll("<p style=\"font-size:12px;color:var(--text-muted);margin:6px 0\">");
    try w.writeAll(t.var_ref_desc);
    try w.writeAll("</p>");
    // Group: Date
    try w.writeAll("<div style=\"margin-top:8px\"><div style=\"font-size:11px;font-weight:700;color:var(--brand);text-transform:uppercase;letter-spacing:.05em;margin-bottom:4px\">Date / Time</div>");
    try w.writeAll("<div class=\"var-ref-grid\">");
    try w.writeAll("<code onclick=\"insertTpl('{date}')\">{date}</code><span>YYYY-MM-DD (today)</span>");
    try w.writeAll("<code onclick=\"insertTpl('{date:MMDD}')\">{date:MMDD}</code><span>MMDD (e.g. 0416)</span>");
    try w.writeAll("<code onclick=\"insertTpl('{date:compact}')\">{date:compact}</code><span>YYYYMMDD</span>");
    try w.writeAll("<code onclick=\"insertTpl('{date:YYYY}')\">{date:YYYY}</code><span>Year only</span>");
    try w.writeAll("<code onclick=\"insertTpl('{date:HHmm}')\">{date:HHmm}</code><span>HHmm (24h time)</span>");
    try w.writeAll("</div></div>");
    // Group: Random
    try w.writeAll("<div style=\"margin-top:8px\"><div style=\"font-size:11px;font-weight:700;color:var(--brand);text-transform:uppercase;letter-spacing:.05em;margin-bottom:4px\">Random</div>");
    try w.writeAll("<div class=\"var-ref-grid\">");
    try w.writeAll("<code onclick=\"insertTpl('{random:6}')\">{random:N}</code><span>N decimal digits</span>");
    try w.writeAll("<code onclick=\"insertTpl('{random:hex:8}')\">{random:hex:N}</code><span>N hex characters</span>");
    try w.writeAll("<code onclick=\"insertTpl('{random:alnum:8}')\">{random:alnum:N}</code><span>N alphanumeric [a-z0-9]</span>");
    try w.writeAll("<code onclick=\"insertTpl('{random:lower:8}')\">{random:lower:N}</code><span>N lowercase letters</span>");
    try w.writeAll("<code onclick=\"insertTpl('{random:upper:8}')\">{random:upper:N}</code><span>N uppercase letters</span>");
    try w.writeAll("</div></div>");
    // Group: Identifier
    try w.writeAll("<div style=\"margin-top:8px\"><div style=\"font-size:11px;font-weight:700;color:var(--brand);text-transform:uppercase;letter-spacing:.05em;margin-bottom:4px\">Identifier</div>");
    try w.writeAll("<div class=\"var-ref-grid\">");
    try w.writeAll("<code onclick=\"insertTpl('{uuid}')\">{uuid}</code><span>UUID v4 (e.g. f47ac10b-...)</span>");
    try w.writeAll("</div></div>");
    // Group: Word banks
    try w.writeAll("<div style=\"margin-top:8px\"><div style=\"font-size:11px;font-weight:700;color:var(--brand);text-transform:uppercase;letter-spacing:.05em;margin-bottom:4px\">Word Banks</div>");
    try w.writeAll("<div class=\"var-ref-grid\">");
    try w.writeAll("<code onclick=\"insertTpl('{word:tech}')\">{word:tech}</code><span>Tech term (e.g. kubernetes)</span>");
    try w.writeAll("<code onclick=\"insertTpl('{word:games}')\">{word:games}</code><span>Game term</span>");
    try w.writeAll("<code onclick=\"insertTpl('{word:finance}')\">{word:finance}</code><span>Finance term</span>");
    try w.writeAll("<code onclick=\"insertTpl('{word:general}')\">{word:general}</code><span>General English word</span>");
    try w.writeAll("</div></div>");
    // Group: Game
    try w.writeAll("<div style=\"margin-top:8px\"><div style=\"font-size:11px;font-weight:700;color:var(--brand);text-transform:uppercase;letter-spacing:.05em;margin-bottom:4px\">Game</div>");
    try w.writeAll("<div class=\"var-ref-grid\">");
    try w.writeAll("<code onclick=\"insertTpl('{game:genshin:character}')\">{game:genshin:character}</code><span>Random Genshin character name</span>");
    try w.writeAll("<code onclick=\"insertTpl('{game:genshin:birthday:funingna}')\">{game:genshin:birthday:NAME}</code><span>Birthday of a character (e.g. funingna)</span>");
    try w.writeAll("</div></div>");
    // Group: Literal
    try w.writeAll("<div style=\"margin-top:8px\"><div style=\"font-size:11px;font-weight:700;color:var(--brand);text-transform:uppercase;letter-spacing:.05em;margin-bottom:4px\">Special</div>");
    try w.writeAll("<div class=\"var-ref-grid\">");
    try w.writeAll("<code onclick=\"insertTpl('{literal:hello}')\">{literal:TEXT}</code><span>Output TEXT as-is (no processing)</span>");
    try w.writeAll("</div></div>");
    // Puzzle pieces section (hidden until split is done)
    try w.writeAll("<div id=\"puzzle-ref-section\" style=\"display:none;margin-top:8px\">");
    try w.writeAll("<div style=\"font-size:11px;font-weight:700;color:var(--brand);text-transform:uppercase;letter-spacing:.05em;margin-bottom:4px\">Puzzle Pieces (last split)</div>");
    try w.writeAll("<div id=\"puzzle-ref-list\" class=\"var-ref-grid\"></div>");
    try w.writeAll("</div>");
    try w.writeAll("</details>");

    // Buttons
    try w.writeAll("<div style=\"margin-top:16px;display:flex;gap:8px;flex-wrap:wrap\">");
    try w.writeAll("<button class=\"btn btn-primary\" onclick=\"doGenerate()\">");
    try w.writeAll(t.generate_btn);
    try w.writeAll("</button><button class=\"btn btn-secondary\" onclick=\"doGenAndEncrypt()\">");
    try w.writeAll(t.generate_then_encrypt);
    try w.writeAll("</button><button class=\"btn btn-secondary\" onclick=\"doGenAndSplit()\">");
    try w.writeAll(t.generate_then_split);
    try w.writeAll("</button></div></div>");
    try w.writeAll("<div class=\"card\" id=\"gen-result-card\" style=\"display:none\">");
    try w.writeAll("<div class=\"card-header\"><span class=\"card-badge\">RESULT</span><h2 class=\"card-title\">");
    try w.writeAll(t.generate_result);
    try w.writeAll("</h2></div><div class=\"result-box\" id=\"gen-result\"></div>");
    try w.writeAll("<div class=\"toolbar\" style=\"margin-top:12px\">");
    try w.writeAll("<button class=\"btn btn-secondary btn-sm\" onclick=\"copyResult('gen-result')\">");
    try w.writeAll(t.copy);
    try w.writeAll("</button></div></div></div>");
}

fn renderAiPage(w: *std.Io.Writer, t: anytype) !void {
    try w.writeAll("<div id=\"page-ai\" class=\"page\"><div class=\"card\">");
    try w.writeAll("<div class=\"card-header\"><span class=\"card-badge\">AI</span><h2 class=\"card-title\">");
    try w.writeAll(t.ai_title);
    try w.writeAll("</h2></div>");

    // Provider label
    try w.writeAll("<div id=\"ai-provider-label\" class=\"ai-provider-label\">OpenAI</div>");

    // Mode selector
    try w.writeAll("<div class=\"ai-modes\">");
    try w.writeAll("<button class=\"ai-mode-btn active\" data-mode=\"chat\" onclick=\"setAiMode('chat')\">");
    try w.writeAll(t.ai_mode_chat);
    try w.writeAll("</button><button class=\"ai-mode-btn\" data-mode=\"encrypt\" onclick=\"setAiMode('encrypt')\">");
    try w.writeAll(t.ai_mode_encrypt);
    try w.writeAll("</button><button class=\"ai-mode-btn\" data-mode=\"decrypt\" onclick=\"setAiMode('decrypt')\">");
    try w.writeAll(t.ai_mode_decrypt);
    try w.writeAll("</button><button class=\"ai-mode-btn\" data-mode=\"puzzle\" onclick=\"setAiMode('puzzle')\">");
    try w.writeAll(t.ai_mode_puzzle);
    try w.writeAll("</button><button class=\"ai-mode-btn\" data-mode=\"generate\" onclick=\"setAiMode('generate')\">");
    try w.writeAll(t.ai_mode_generate);
    try w.writeAll("</button></div>");

    // Chat messages
    try w.writeAll("<div class=\"ai-chat-container\">");
    try w.writeAll("<div id=\"ai-messages\" class=\"ai-messages\">");
    try w.writeAll("</div>");
    // Input row
    try w.writeAll("<div class=\"ai-input-row\">");
    try w.writeAll("<textarea id=\"ai-input\" placeholder=\"");
    try w.writeAll(t.ai_placeholder);
    try w.writeAll("\" onkeydown=\"aiKeydown(event)\"></textarea>");
    try w.writeAll("<button class=\"btn btn-primary\" onclick=\"sendAiMsg()\" id=\"ai-send-btn\">");
    try w.writeAll(t.ai_send);
    try w.writeAll("</button></div></div></div></div>");
}

fn renderHistoryPage(w: *std.Io.Writer, t: anytype) !void {
    try w.writeAll("<div id=\"page-history\" class=\"page\"><div class=\"card\">");
    try w.writeAll("<div class=\"card-header\"><span class=\"card-badge\">HISTORY</span><h2 class=\"card-title\">");
    try w.writeAll(t.history_title);
    try w.writeAll("</h2><div class=\"toolbar-spacer\"></div>");
    try w.writeAll("<button class=\"btn btn-secondary btn-sm\" onclick=\"loadHistory()\">Refresh</button>");
    try w.writeAll("<button class=\"btn btn-secondary btn-sm\" style=\"color:var(--error);margin-left:6px\" onclick=\"clearHist()\">");
    try w.writeAll(t.history_clear);
    try w.writeAll("</button></div>");
    try w.writeAll("<div id=\"history-list\"><p style=\"color:var(--text-muted);font-size:14px\">");
    try w.writeAll(t.history_empty);
    try w.writeAll("</p></div></div></div>");
}

fn renderSettingsPage(w: *std.Io.Writer, t: anytype) !void {
    try w.writeAll("<div id=\"page-settings\" class=\"page\"><div class=\"card\">");
    try w.writeAll("<div class=\"card-header\"><span class=\"card-badge\">SETTINGS</span><h2 class=\"card-title\">");
    try w.writeAll(t.settings_title);
    try w.writeAll("</h2></div>");

    // Theme
    try w.writeAll("<div style=\"margin-bottom:20px\"><label style=\"font-weight:700;font-size:14px\">");
    try w.writeAll(t.settings_theme);
    try w.writeAll("</label><div class=\"grid-3\" style=\"margin-top:8px\">");
    try w.writeAll("<button class=\"btn btn-secondary btn-sm\" onclick=\"setTheme('auto')\">");
    try w.writeAll(t.theme_auto);
    try w.writeAll("</button><button class=\"btn btn-secondary btn-sm\" onclick=\"setTheme('light-jade')\">");
    try w.writeAll(t.theme_light_jade);
    try w.writeAll("</button><button class=\"btn btn-secondary btn-sm\" onclick=\"setTheme('dark-ocean')\">");
    try w.writeAll(t.theme_dark_ocean);
    try w.writeAll("</button><button class=\"btn btn-secondary btn-sm\" onclick=\"setTheme('sakura')\">");
    try w.writeAll(t.theme_sakura);
    try w.writeAll("</button><button class=\"btn btn-secondary btn-sm\" onclick=\"setTheme('midnight')\">");
    try w.writeAll(t.theme_midnight);
    try w.writeAll("</button><button class=\"btn btn-secondary btn-sm\" onclick=\"setTheme('amber')\">");
    try w.writeAll(t.theme_amber);
    try w.writeAll("</button></div></div>");

    // Language
    try w.writeAll("<div style=\"margin-bottom:20px\"><label style=\"font-weight:700;font-size:14px\">");
    try w.writeAll(t.settings_language);
    try w.writeAll("</label><div class=\"grid-3\" style=\"margin-top:8px\">");
    try w.writeAll("<button class=\"btn btn-secondary btn-sm\" onclick=\"setLang('zh')\">Chinese</button>");
    try w.writeAll("<button class=\"btn btn-secondary btn-sm\" onclick=\"setLang('ja')\">Japanese</button>");
    try w.writeAll("<button class=\"btn btn-secondary btn-sm\" onclick=\"setLang('en')\">English</button></div></div>");

    // AI Config — full
    try w.writeAll("<div style=\"margin-bottom:20px\"><label style=\"font-weight:700;font-size:14px\">");
    try w.writeAll(t.settings_ai_config);
    try w.writeAll("</label><div style=\"margin-top:8px;display:grid;gap:10px\">");
    // Provider selector
    try w.writeAll("<div><label style=\"font-size:12px;font-weight:600;color:var(--text-muted)\">");
    try w.writeAll(t.ai_provider);
    try w.writeAll("</label><div style=\"margin-top:4px\">");
    try w.writeAll("<div class=\"custom-select\" id=\"ai-provider-select\" data-value=\"openai\">");
    try w.writeAll("<div class=\"custom-select-trigger\" onclick=\"toggleDD(this,event)\"><span>OpenAI</span><span class=\"arrow\">\xe2\x96\xbe</span></div>");
    try w.writeAll("<div class=\"custom-select-options\">");
    try w.writeAll("<div class=\"custom-select-option selected\" data-value=\"openai\" onclick=\"selOpt(this)\">OpenAI</div>");
    try w.writeAll("<div class=\"custom-select-option\" data-value=\"claude\" onclick=\"selOpt(this)\">Claude</div>");
    try w.writeAll("</div></div></div></div>");
    // Endpoint
    try w.writeAll("<div><label style=\"font-size:12px;font-weight:600;color:var(--text-muted)\">");
    try w.writeAll(t.settings_api_endpoint);
    try w.writeAll("</label><input type=\"text\" class=\"text-input\" id=\"ai-endpoint\" placeholder=\"https://api.openai.com/v1\" style=\"margin-top:4px\"></div>");
    // API Key
    try w.writeAll("<div><label style=\"font-size:12px;font-weight:600;color:var(--text-muted)\">");
    try w.writeAll(t.settings_api_key);
    try w.writeAll("</label><input type=\"password\" class=\"text-input\" id=\"ai-key\" placeholder=\"sk-...\" style=\"margin-top:4px\"></div>");
    // Model
    try w.writeAll("<div><label style=\"font-size:12px;font-weight:600;color:var(--text-muted)\">");
    try w.writeAll(t.ai_model);
    try w.writeAll("</label><input type=\"text\" class=\"text-input\" id=\"ai-model\" placeholder=\"gpt-4o-mini\" style=\"margin-top:4px\"></div>");
    // Buttons
    try w.writeAll("<div style=\"display:flex;gap:8px\">");
    try w.writeAll("<button class=\"btn btn-primary btn-sm\" onclick=\"saveAi()\">");
    try w.writeAll(t.save);
    try w.writeAll("</button><button class=\"btn btn-secondary btn-sm\" onclick=\"testAiConnect()\">");
    try w.writeAll(t.ai_test_connection);
    try w.writeAll("</button></div></div></div>");

    // Template Variables
    try w.writeAll("<div style=\"margin-top:20px\"><label style=\"font-weight:700;font-size:14px\">");
    try w.writeAll(t.settings_template_vars);
    try w.writeAll("</label>");
    try w.writeAll("<p style=\"font-size:12px;color:var(--text-muted);margin:4px 0 8px\">");
    try w.writeAll(t.settings_template_desc);
    try w.writeAll("</p>");
    try w.writeAll("<div id=\"settings-chips\" class=\"chips-container\" style=\"display:flex;flex-wrap:wrap;gap:6px;min-height:32px\"></div>");
    try w.writeAll("<div style=\"margin-top:10px;display:flex;gap:8px\">");
    try w.writeAll("<button class=\"btn btn-secondary btn-sm\" onclick=\"showSettingsAddChip()\">");
    try w.writeAll(t.chip_add);
    try w.writeAll("</button><button class=\"btn btn-secondary btn-sm\" onclick=\"resetChips();renderSettingsChips()\">");
    try w.writeAll(t.chip_reset);
    try w.writeAll("</button></div>");
    try w.writeAll("<div id=\"settings-chip-dialog\" style=\"display:none;margin-top:10px;padding:12px;border-radius:8px;background:var(--surface-alt)\">");
    try w.writeAll("<div style=\"display:flex;gap:8px;align-items:center\">");
    try w.writeAll("<input type=\"text\" class=\"text-input\" id=\"settings-chip-name\" placeholder=\"");
    try w.writeAll(t.chip_name_placeholder);
    try w.writeAll("\" style=\"flex:1\">");
    try w.writeAll("<input type=\"text\" class=\"text-input\" id=\"settings-chip-value\" placeholder=\"");
    try w.writeAll(t.chip_value_placeholder);
    try w.writeAll("\" style=\"flex:1\">");
    try w.writeAll("<button class=\"btn btn-primary btn-sm\" onclick=\"addSettingsChip()\">");
    try w.writeAll(t.add);
    try w.writeAll("</button><button class=\"btn btn-secondary btn-sm\" onclick=\"hideSettingsAddChip()\">");
    try w.writeAll(t.cancel);
    try w.writeAll("</button></div></div>");

    // Built-in template data editor
    try w.writeAll("<div style=\"margin-top:24px\"><label style=\"font-weight:700;font-size:14px\">");
    try w.writeAll(t.template_data_title);
    try w.writeAll("</label>");
    try w.writeAll("<p style=\"font-size:12px;color:var(--text-muted);margin:4px 0 10px\">");
    try w.writeAll(t.template_data_desc);
    try w.writeAll("</p>");
    try w.writeAll("<div class=\"grid-2\">");
    try renderTemplateEditor(w, "template-data-games", t.template_data_games);
    try renderTemplateEditor(w, "template-data-tech", t.template_data_tech);
    try renderTemplateEditor(w, "template-data-finance", t.template_data_finance);
    try renderTemplateEditor(w, "template-data-general", t.template_data_general);
    try renderTemplateEditor(w, "template-data-genshin-characters", t.template_data_genshin_characters);
    try renderTemplateEditor(w, "template-data-genshin-birthdays", t.template_data_genshin_birthdays);
    try w.writeAll("</div>");
    // Custom word banks section
    try w.writeAll("<div style=\"margin-top:12px\"><div style=\"display:flex;align-items:center;gap:8px;margin-bottom:8px\">");
    try w.writeAll("<span style=\"font-size:12px;font-weight:700;color:var(--brand-deep)\">Custom Word Banks</span>");
    try w.writeAll("<button class=\"btn btn-secondary\" style=\"font-size:11px;padding:2px 8px\" onclick=\"addCustomBank()\">+ Add</button>");
    try w.writeAll("</div><div id=\"custom-banks-container\" class=\"grid-2\"></div></div>");
    try w.writeAll("<div style=\"margin-top:10px;display:flex;gap:8px\">");
    try w.writeAll("<button class=\"btn btn-primary btn-sm\" onclick=\"saveTemplateData()\">");
    try w.writeAll(t.save);
    try w.writeAll("</button><button class=\"btn btn-secondary btn-sm\" onclick=\"resetTemplateData()\">");
    try w.writeAll(t.chip_reset);
    try w.writeAll("</button></div></div>");
    try w.writeAll("</div></div></div>");
}

fn renderTemplateEditor(w: *std.Io.Writer, id: []const u8, title: []const u8) !void {
    try w.writeAll("<div style=\"padding:12px;border-radius:14px;background:var(--surface-alt);border:1px solid var(--border)\">");
    try w.writeAll("<div style=\"font-size:12px;font-weight:700;color:var(--brand-deep);margin-bottom:8px\">");
    try w.writeAll(title);
    try w.writeAll("</div>");
    try w.writeAll("<textarea id=\"");
    try w.writeAll(id);
    try w.writeAll("\" class=\"text-input\" style=\"min-height:150px\"></textarea></div>");
}

// SVG Icons
const icon_lock = "<svg width=\"22\" height=\"22\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><rect x=\"3\" y=\"11\" width=\"18\" height=\"11\" rx=\"2\"/><path d=\"M7 11V7a5 5 0 0110 0v4\"/></svg>";
const icon_unlock = "<svg width=\"22\" height=\"22\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><rect x=\"3\" y=\"11\" width=\"18\" height=\"11\" rx=\"2\"/><path d=\"M7 11V7a5 5 0 019.9-1\"/></svg>";
const icon_puzzle = "<svg width=\"22\" height=\"22\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><path d=\"M4 7h3a2 2 0 012 2 2 2 0 012-2h3V4a1 1 0 012 0v3h3a2 2 0 012 2 2 2 0 01-2 2h-3v3a1 1 0 01-2 0v-3H9a2 2 0 01-2-2 2 2 0 012-2\"/></svg>";
const icon_dice = "<svg width=\"22\" height=\"22\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><rect x=\"3\" y=\"3\" width=\"18\" height=\"18\" rx=\"3\"/><circle cx=\"8\" cy=\"8\" r=\"1\" fill=\"currentColor\"/><circle cx=\"16\" cy=\"8\" r=\"1\" fill=\"currentColor\"/><circle cx=\"12\" cy=\"12\" r=\"1\" fill=\"currentColor\"/><circle cx=\"8\" cy=\"16\" r=\"1\" fill=\"currentColor\"/><circle cx=\"16\" cy=\"16\" r=\"1\" fill=\"currentColor\"/></svg>";
const icon_clock = "<svg width=\"22\" height=\"22\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><circle cx=\"12\" cy=\"12\" r=\"10\"/><path d=\"M12 6v6l4 2\"/></svg>";
const icon_gear = "<svg width=\"22\" height=\"22\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><circle cx=\"12\" cy=\"12\" r=\"3\"/><path d=\"M19.4 15a1.65 1.65 0 00.33 1.82l.06.06a2 2 0 01-2.83 2.83l-.06-.06a1.65 1.65 0 00-1.82-.33 1.65 1.65 0 00-1 1.51V21a2 2 0 01-4 0v-.09A1.65 1.65 0 009 19.4a1.65 1.65 0 00-1.82.33l-.06.06a2 2 0 01-2.83-2.83l.06-.06A1.65 1.65 0 004.68 15a1.65 1.65 0 00-1.51-1H3a2 2 0 010-4h.09A1.65 1.65 0 004.6 9a1.65 1.65 0 00-.33-1.82l-.06-.06a2 2 0 012.83-2.83l.06.06A1.65 1.65 0 009 4.68a1.65 1.65 0 001-1.51V3a2 2 0 014 0v.09a1.65 1.65 0 001 1.51 1.65 1.65 0 001.82-.33l.06-.06a2 2 0 012.83 2.83l-.06.06A1.65 1.65 0 0019.4 9a1.65 1.65 0 001.51 1H21a2 2 0 010 4h-.09a1.65 1.65 0 00-1.51 1z\"/></svg>";
const icon_sun = "<svg width=\"22\" height=\"22\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><circle cx=\"12\" cy=\"12\" r=\"5\"/><path d=\"M12 1v2M12 21v2M4.22 4.22l1.42 1.42M18.36 18.36l1.42 1.42M1 12h2M21 12h2M4.22 19.78l1.42-1.42M18.36 5.64l1.42-1.42\"/></svg>";
const icon_globe = "<svg width=\"22\" height=\"22\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><circle cx=\"12\" cy=\"12\" r=\"10\"/><path d=\"M2 12h20M12 2a15.3 15.3 0 014 10 15.3 15.3 0 01-4 10 15.3 15.3 0 01-4-10 15.3 15.3 0 014-10z\"/></svg>";
const icon_ai = "<svg width=\"22\" height=\"22\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><circle cx=\"12\" cy=\"12\" r=\"10\"/><path d=\"M9 9h.01M15 9h.01M9 15s1 2 3 2 3-2 3-2\"/></svg>";

// ═══════════════════════════════════════════════════════════════════
//  Application JavaScript
// ═══════════════════════════════════════════════════════════════════

const app_js =
    \\var ePipeline=[],dPipeline=[];
    \\var themes=['auto','light-jade','dark-ocean','sakura','midnight','amber'];
    \\var tIdx=0;var langs=['zh','ja','en'];var lIdx=0;var puzzleEncrypt=false;
    \\var puzzlePieces=[];var puzzleReady=false;
    \\var aiMode='chat';var aiHistory=[];
    \\function $(id){return document.getElementById(id)}
    \\function showPage(p){
    \\  document.querySelectorAll('.page').forEach(function(e){e.classList.remove('active')});
    \\  document.querySelectorAll('.nav-btn[data-nav]').forEach(function(e){e.classList.remove('active')});
    \\  var el=$('page-'+p);if(el)el.classList.add('active');
    \\  var nb=document.querySelector('[data-nav="'+p+'"]');if(nb)nb.classList.add('active');
    \\  if(p==='history')loadHistory();
    \\  if(p==='ai'||p==='settings')loadAiSettings();
    \\  if(p==='settings')loadTemplateData();
    \\}
    \\function toast(msg,type){
    \\  var c=$('toast-container');var d=document.createElement('div');
    \\  d.className='toast'+(type?' toast-'+type:'');d.textContent=msg;
    \\  c.appendChild(d);setTimeout(function(){d.classList.add('show')},10);
    \\  setTimeout(function(){d.classList.remove('show');setTimeout(function(){if(d.parentNode)c.removeChild(d)},300)},2500);
    \\}
    \\// ── Custom dropdown (portal to body to escape stacking context) ──
    \\function eventInDDOptions(e){
    \\  var t=e&&e.target;
    \\  if(t&&t.nodeType===1){
    \\    if(t.classList&&t.classList.contains('vt-dd-portal'))return true;
    \\    if(t.closest&&t.closest('.vt-dd-portal'))return true;
    \\  }
    \\  if(e&&e.composedPath){
    \\    var p=e.composedPath();
    \\    for(var i=0;i<p.length;i++){
    \\      var n=p[i];
    \\      if(n&&n.classList&&n.classList.contains('vt-dd-portal'))return true;
    \\    }
    \\  }
    \\  return false;
    \\}
    \\function positionDD(trigger,opts){
    \\  var rect=trigger.getBoundingClientRect();
    \\  var vh=window.innerHeight||document.documentElement.clientHeight;
    \\  var vw=window.innerWidth||document.documentElement.clientWidth;
    \\  var gap=4,desiredMax=360,width=Math.max(160,rect.width);
    \\  var spaceBelow=vh-rect.bottom-gap;
    \\  var spaceAbove=rect.top-gap;
    \\  var openUp=spaceBelow<Math.min(desiredMax,220)&&spaceAbove>spaceBelow;
    \\  var space=openUp?spaceAbove:spaceBelow;
    \\  var maxH=Math.max(120,Math.min(desiredMax,space));
    \\  var left=Math.min(Math.max(8,rect.left),Math.max(8,vw-width-8));
    \\  opts.style.left=left+'px';opts.style.width=width+'px';
    \\  opts.style.maxHeight=maxH+'px';opts.style.bottom='';
    \\  opts.style.top=(openUp?Math.max(gap,rect.top-gap-maxH):Math.min(vh-gap-maxH,rect.bottom+gap))+'px';
    \\  opts.classList.toggle('open-up',openUp);
    \\  trigger.classList.toggle('open-up',openUp);
    \\}
    \\function toggleDD(trigger,e){
    \\  if(e){e.preventDefault();e.stopPropagation();}
    \\  var sel=trigger.parentElement;
    \\  var opts=sel.querySelector('.custom-select-options')||sel._ddOpts;
    \\  if(!opts)return;
    \\  var isOpen=opts.classList.contains('open');
    \\  closeAllDD();
    \\  if(!isOpen){
    \\    sel._ddOpts=opts;sel._ddTrigger=trigger;
    \\    opts.classList.add('vt-dd-portal');
    \\    document.body.appendChild(opts);
    \\    opts.onclick=function(ev){ev.stopPropagation()};
    \\    opts.onmousedown=function(ev){ev.stopPropagation()};
    \\    opts.onwheel=function(ev){ev.stopPropagation()};
    \\    opts.onscroll=function(ev){ev.stopPropagation()};
    \\    opts.ontouchstart=function(ev){ev.stopPropagation()};
    \\    opts.ontouchmove=function(ev){ev.stopPropagation()};
    \\    positionDD(trigger,opts);
    \\    opts.classList.add('open');trigger.classList.add('open');
    \\  }
    \\}
    \\function selOpt(opt){
    \\  var opts=opt.parentElement;var sel=null;
    \\  document.querySelectorAll('.custom-select').forEach(function(s){
    \\    if(s._ddOpts===opts||s.contains(opts))sel=s;
    \\  });
    \\  if(!sel)return;
    \\  var trigger=sel.querySelector('.custom-select-trigger')||sel._ddTrigger;
    \\  opts.querySelectorAll('.custom-select-option').forEach(function(o){o.classList.remove('selected')});
    \\  opt.classList.add('selected');trigger.querySelector('span').textContent=opt.textContent;
    \\  sel.setAttribute('data-value',opt.getAttribute('data-value'));
    \\  closeAllDD();
    \\}
    \\function closeAllDD(){
    \\  document.querySelectorAll('.custom-select-options.open').forEach(function(o){
    \\    o.classList.remove('open');
    \\    o.classList.remove('vt-dd-portal');
    \\    o.style.maxHeight='';o.style.top='';o.style.bottom='';o.style.left='';o.style.width='';
    \\    o.classList.remove('open-up');
    \\    o.onclick=null;o.onmousedown=null;o.onwheel=null;o.onscroll=null;
    \\    o.ontouchstart=null;o.ontouchmove=null;
    \\    document.querySelectorAll('.custom-select').forEach(function(s){
    \\      if(s._ddOpts===o){s.appendChild(o);delete s._ddOpts;
    \\        var t=s._ddTrigger||s.querySelector('.custom-select-trigger');
    \\        if(t){t.classList.remove('open');t.classList.remove('open-up')}delete s._ddTrigger}
    \\    });
    \\  });
    \\  document.querySelectorAll('.custom-select-trigger.open').forEach(function(t){t.classList.remove('open');t.classList.remove('open-up')});
    \\}
    \\function getSelVal(id){return $(id).getAttribute('data-value')}
    \\document.addEventListener('mousedown',function(e){
    \\  if(e.target.closest&&e.target.closest('.custom-select'))return;
    \\  if(eventInDDOptions(e))return;
    \\  closeAllDD();
    \\});
    \\// Reposition (not close) when the scroll happens outside the open dropdown.
    \\window.addEventListener('scroll',function(e){
    \\  if(eventInDDOptions(e))return;
    \\  document.querySelectorAll('.custom-select').forEach(function(s){
    \\    if(s._ddOpts&&s._ddTrigger)positionDD(s._ddTrigger,s._ddOpts);
    \\  });
    \\},true);
    \\window.addEventListener('resize',function(){
    \\  document.querySelectorAll('.custom-select').forEach(function(s){
    \\    if(s._ddOpts&&s._ddTrigger)positionDD(s._ddTrigger,s._ddOpts);
    \\  });
    \\});
    \\document.addEventListener('keydown',function(e){
    \\  if(e.key==='Escape')closeAllDD();
    \\});
    \\// ── Modal ──
    \\var _modalCb=null;
    \\function showModal(title,fields,onOk){
    \\  $('modal-title').textContent=title;var body=$('modal-body');body.innerHTML='';
    \\  for(var i=0;i<fields.length;i++){var f=fields[i];
    \\    var div=document.createElement('div');div.className='modal-field';
    \\    var lbl=document.createElement('label');lbl.textContent=f.label;div.appendChild(lbl);
    \\    var inp=document.createElement('input');inp.type='text';inp.className='text-input';
    \\    inp.id='modal-field-'+i;inp.value=f.value||'';inp.placeholder=f.placeholder||'';
    \\    if(f.readonly){inp.readOnly=true;inp.style.opacity='.65';inp.style.cursor='default';inp.style.backgroundColor='var(--surface-alt)'}
    \\    div.appendChild(inp);body.appendChild(div);
    \\  }
    \\  _modalCb=onOk;$('modal-ok').onclick=function(){
    \\    var vals=[];for(var j=0;j<fields.length;j++)vals.push($('modal-field-'+j).value);
    \\    var cb=_modalCb;closeModal();if(cb)cb(vals);
    \\  };$('modal-overlay').style.display='';
    \\  setTimeout(function(){
    \\    var first=null;for(var k=0;k<fields.length;k++){if(!fields[k].readonly){first=$('modal-field-'+k);break}}
    \\    if(first)first.focus();
    \\  },50);
    \\}
    \\function closeModal(){$('modal-overlay').style.display='none';_modalCb=null}
    \\document.addEventListener('click',function(e){if(e.target&&e.target.id==='modal-overlay')closeModal()});
    \\// ── Encrypt/Decrypt pipeline ──
    \\function addStep(){
    \\  var a=getSelVal('algo-select');ePipeline.push(a);renderPipeline('encrypt-pipeline',ePipeline);
    \\}
    \\function addDStep(){
    \\  var a=getSelVal('dalgo-select');dPipeline.push(a);renderPipeline('decrypt-pipeline',dPipeline);
    \\}
    \\function renderPipeline(id,arr){
    \\  var el=$(id);el.innerHTML='';
    \\  for(var i=0;i<arr.length;i++){
    \\    var s=document.createElement('span');s.className='pipeline-step';
    \\    s.textContent=arr[i];
    \\    var x=document.createElement('span');x.className='remove';x.textContent='\u00d7';
    \\    x.onclick=(function(idx,a){return function(){a.splice(idx,1);renderPipeline(id,a)}})(i,arr);
    \\    s.appendChild(x);el.appendChild(s);
    \\    if(i<arr.length-1){var ar=document.createElement('span');ar.className='pipeline-arrow';ar.textContent='\u2192';el.appendChild(ar)}
    \\  }
    \\}
    \\function needsKey(steps){
    \\  for(var i=0;i<steps.length;i++){
    \\    var s=steps[i];if(s.indexOf('aes')>=0||s.indexOf('chacha')>=0||s.indexOf('xchacha')>=0||s==='aes_256_cbc')return true;
    \\  }return false;
    \\}
    \\function buildSteps(arr,key){
    \\  var steps=[];
    \\  for(var i=0;i<arr.length;i++){
    \\    var o={type:arr[i]};if(needsKey([arr[i]]))o.key=key;steps.push(o);
    \\  }return steps;
    \\}
    \\function doEncrypt(){
    \\  var txt=$('encrypt-input').value;if(!txt){toast('Please enter text','error');return}
    \\  var key=$('encrypt-key').value;
    \\  var steps=ePipeline.length>0?ePipeline:['base64'];
    \\  if(needsKey(steps)&&!key){toast('Key required for this algorithm','error');return}
    \\  var body={text:txt,pipeline:buildSteps(steps,key)};
    \\  fetch('/api/encrypt',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)})
    \\  .then(function(r){return r.json()}).then(function(d){
    \\    if(d.error){toast(d.error,'error');return}
    \\    $('encrypt-result').textContent=d.ciphertext||d.result||'';
    \\    $('encrypt-result-card').style.display='';toast('Encrypted!','success');
    \\  }).catch(function(e){toast('Error: '+e.message,'error')});
    \\}
    \\function doDecrypt(){
    \\  var txt=$('decrypt-input').value;if(!txt){toast('Please enter ciphertext','error');return}
    \\  var key=$('decrypt-key').value;var hash=$('decrypt-hash').value;
    \\  var steps=dPipeline.length>0?dPipeline:['base64'];
    \\  if(needsKey(steps)&&!key){toast('Key required','error');return}
    \\  var body={text:txt,pipeline:buildSteps(steps,key)};
    \\  if(hash)body.expected_hash=hash;
    \\  fetch('/api/decrypt',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)})
    \\  .then(function(r){return r.json()}).then(function(d){
    \\    if(d.error){toast(d.error,'error');return}
    \\    $('decrypt-result').textContent=d.plaintext||d.result||'';
    \\    $('decrypt-result-card').style.display='';
    \\    $('decrypt-ai-detail').style.display='none';
    \\    var v=$('decrypt-verify');
    \\    if(d.hash_match===true){v.textContent='\u2713 Hash verified';v.style.color='var(--success)'}
    \\    else if(d.hash_match===false){v.textContent='\u2717 Hash mismatch';v.style.color='var(--error)'}
    \\    else{v.textContent=''}
    \\    toast('Decrypted!','success');
    \\  }).catch(function(e){toast('Error: '+e.message,'error')});
    \\}
    \\function doSmartDecode(){
    \\  var txt=$('decrypt-input').value;if(!txt){toast('Please enter ciphertext','error');return}
    \\  var key=$('decrypt-key').value;
    \\  var steps=dPipeline.length>0?dPipeline:[];
    \\  if(needsKey(steps)&&!key){toast('Key required','error');return}
    \\  var btn=$('smart-decode-btn');var old=btn?btn.textContent:'';
    \\  if(btn){btn.disabled=true;btn.textContent='AI...'}
    \\  var body={text:txt,key:key,pipeline:buildSteps(steps,key),max_depth:8};
    \\  fetch('/api/decode-smart',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)})
    \\  .then(function(r){return r.json()}).then(function(d){
    \\    if(d.error){toast(d.error,'error');return}
    \\    $('decrypt-result').textContent=d.plaintext||d.result||'';
    \\    $('decrypt-result-card').style.display='';
    \\    $('decrypt-verify').textContent='';
    \\    var detail=$('decrypt-ai-detail');
    \\    var stepsText=(d.steps&&d.steps.length)?d.steps.join(' \u2192 '):'none';
    \\    detail.textContent='AI path: '+(d.pipeline_desc||stepsText)+' | attempts: '+(d.attempts||0)+(d.still_encoded?' | still looks encoded/encrypted':'');
    \\    detail.style.display='';
    \\    toast('AI decoded','success');
    \\  }).catch(function(e){toast('Error: '+e.message,'error')})
    \\  .finally(function(){if(btn){btn.disabled=false;btn.textContent=old}});
    \\}
    \\// ── Puzzle ──
    \\function togglePuzzleEncrypt(){
    \\  puzzleEncrypt=!puzzleEncrypt;var track=$('puzzle-encrypt-track');
    \\  if(puzzleEncrypt)track.classList.add('on');else track.classList.remove('on');
    \\  $('puzzle-encrypt-opts').style.display=puzzleEncrypt?'':'none';
    \\}
    \\function copyText(text,btn){
    \\  if(navigator.clipboard){navigator.clipboard.writeText(text).then(function(){
    \\    btn.textContent='\u2713';btn.classList.add('copied');
    \\    setTimeout(function(){btn.textContent='Copy';btn.classList.remove('copied')},1500);
    \\  })}else{var a=document.createElement('textarea');a.value=text;document.body.appendChild(a);a.select();
    \\    document.execCommand('copy');document.body.removeChild(a);
    \\    btn.textContent='\u2713';btn.classList.add('copied');
    \\    setTimeout(function(){btn.textContent='Copy';btn.classList.remove('copied')},1500);}
    \\}
    \\function doPuzzleSplit(){
    \\  var txt=$('puzzle-input').value;if(!txt){toast('Enter text to split','error');return}
    \\  var n=parseInt($('puzzle-count').value)||3;
    \\  fetch('/api/puzzle/split',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({text:txt,pieces:n})})
    \\  .then(function(r){return r.json()}).then(function(d){
    \\    if(d.error){toast(d.error,'error');return}
    \\    var ps=d.pieces||[];
    \\    if(puzzleEncrypt){
    \\      var algo=getSelVal('puzzle-algo-select');var key=$('puzzle-key').value;
    \\      if(needsKey([algo])&&!key){toast('Key required for encryption','error');return}
    \\      var promises=[];
    \\      for(var i=0;i<ps.length;i++){
    \\        promises.push(fetch('/api/encrypt',{method:'POST',headers:{'Content-Type':'application/json'},
    \\          body:JSON.stringify({text:ps[i],pipeline:[{type:algo,key:key||undefined}]})}).then(function(r){return r.json()}));
    \\      }
    \\      Promise.all(promises).then(function(results){
    \\        var enc=[];for(var j=0;j<results.length;j++){
    \\          if(results[j].error){toast(results[j].error,'error');return}
    \\          enc.push(results[j].ciphertext||results[j].result);
    \\        }renderPuzzlePieces(enc);
    \\      });
    \\    }else{renderPuzzlePieces(ps)}
    \\  }).catch(function(e){toast('Error: '+e.message,'error')});
    \\}
    \\function renderPuzzlePieces(ps){
    \\  var c=$('puzzle-pieces');c.innerHTML='';
    \\  for(var i=0;i<ps.length;i++){
    \\    var card=document.createElement('div');card.className='piece-card';
    \\    var hd=document.createElement('div');hd.className='piece-header';
    \\    var lb=document.createElement('span');lb.className='piece-label';lb.textContent='Piece '+(i+1);
    \\    var btn=document.createElement('button');btn.className='piece-copy';btn.textContent='Copy';
    \\    (function(text,b){btn.onclick=function(){copyText(text,b)}})(ps[i],btn);
    \\    hd.appendChild(lb);hd.appendChild(btn);
    \\    var bd=document.createElement('div');bd.style.wordBreak='break-all';bd.textContent=ps[i];
    \\    card.appendChild(hd);card.appendChild(bd);c.appendChild(card);
    \\  }
    \\  $('puzzle-result-card').style.display='';toast('Split into '+ps.length+' pieces','success');
    \\  // Store for generate page reference
    \\  puzzlePieces=ps;puzzleReady=true;updatePuzzleRef();
    \\}
    \\function updatePuzzleRef(){
    \\  var el=$('puzzle-ref-section');if(!el)return;
    \\  if(!puzzleReady||puzzlePieces.length===0){el.style.display='none';return}
    \\  el.style.display='';
    \\  var list=$('puzzle-ref-list');list.innerHTML='';
    \\  for(var i=0;i<puzzlePieces.length;i++){
    \\    var preview=puzzlePieces[i].length>32?puzzlePieces[i].substring(0,32)+'...':puzzlePieces[i];
    \\    var code=document.createElement('code');code.textContent=preview;
    \\    code.title=puzzlePieces[i];code.style.cursor='pointer';
    \\    code.onclick=(function(v){return function(){insertTpl(v)}})(puzzlePieces[i]);
    \\    var span=document.createElement('span');span.textContent='Piece '+(i+1);
    \\    list.appendChild(code);list.appendChild(span);
    \\  }
    \\}
    \\function doPuzzleMerge(){
    \\  var txt=$('puzzle-input').value;if(!txt){toast('Paste pieces (one per line)','error');return}
    \\  var pieces=txt.split('\n').map(function(l){
    \\    var s=l.trim();return s.replace(/^Piece\s*\d+:\s*/i,'');
    \\  }).filter(function(l){return l.length>0});
    \\  fetch('/api/puzzle/merge',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({pieces:pieces})})
    \\  .then(function(r){return r.json()}).then(function(d){
    \\    if(d.error){toast(d.error,'error');return}
    \\    $('puzzle-input').value=d.text||d.data||d.result||'';toast('Merged!','success');
    \\  }).catch(function(e){toast('Error: '+e.message,'error')});
    \\}
    \\// ── Generate ──
    \\function doGenerate(){
    \\  var tpl=$('gen-template').value;if(!tpl){toast('Enter a template','error');return}
    \\  fetch('/api/generate',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({template:tpl})})
    \\  .then(function(r){return r.json()}).then(function(d){
    \\    if(d.error){toast(d.error,'error');return}
    \\    $('gen-result').textContent=d.text||d.result||'';$('gen-result-card').style.display='';toast('Generated!','success');
    \\  }).catch(function(e){toast('Error: '+e.message,'error')});
    \\}
    \\function doGenAndEncrypt(){
    \\  var tpl=$('gen-template').value;if(!tpl){toast('Enter a template','error');return}
    \\  fetch('/api/generate',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({template:tpl})})
    \\  .then(function(r){return r.json()}).then(function(d){
    \\    if(d.error){toast(d.error,'error');return}
    \\    $('encrypt-input').value=d.text||d.result||'';showPage('encrypt');toast('Template filled, now encrypt!','success');
    \\  }).catch(function(e){toast('Error: '+e.message,'error')});
    \\}
    \\function doGenAndSplit(){
    \\  var tpl=$('gen-template').value;if(!tpl){toast('Enter a template','error');return}
    \\  fetch('/api/generate',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({template:tpl})})
    \\  .then(function(r){return r.json()}).then(function(d){
    \\    if(d.error){toast(d.error,'error');return}
    \\    var result=d.text||d.result||'';
    \\    $('puzzle-input').value=result;
    \\    showPage('puzzle');toast('Generated! Now split into pieces.','success');
    \\  }).catch(function(e){toast('Error: '+e.message,'error')});
    \\}
    \\function insertTpl(t){var el=$('gen-template');el.value+=t;el.focus()}
    \\// ── Chips ──
    \\var defaultChips=[
    \\  {name:'{date}',value:'{date}',desc:'Today\'s date as YYYY-MM-DD (e.g. 2026-04-16)'},
    \\  {name:'{date:MMDD}',value:'{date:MMDD}',desc:'Month-day as MMDD (e.g. 0416)'},
    \\  {name:'{date:compact}',value:'{date:compact}',desc:'Compact date as YYYYMMDD (e.g. 20260416)'},
    \\  {name:'{random:4}',value:'{random:4}',desc:'4 random decimal digits (0000-9999)'},
    \\  {name:'{random:hex:8}',value:'{random:hex:8}',desc:'8 random hex characters (e.g. a3f12c9b)'},
    \\  {name:'{uuid}',value:'{uuid}',desc:'UUID v4 (e.g. f47ac10b-58cc-4372-a567-0e02b2c3d479)'},
    \\  {name:'{word:tech}',value:'{word:tech}',desc:'Random tech term (e.g. kubernetes, docker, grpc)'},
    \\  {name:'{word:games}',value:'{word:games}',desc:'Random gaming term'},
    \\  {name:'{game:genshin:character}',value:'{game:genshin:character}',desc:'Random Genshin Impact character name'},
    \\  {name:'{game:genshin:birthday:funingna}',value:'{game:genshin:birthday:funingna}',desc:'Birthday of a Genshin character (MMDD format). Replace funingna with character name.'}
    \\];
    \\var genChips=JSON.parse(localStorage.getItem('vt-chips')||'null')||defaultChips.slice();
    \\function saveChips(){localStorage.setItem('vt-chips',JSON.stringify(genChips))}
    \\function renderChips(){
    \\  var c=$('gen-chips');if(!c)return;c.innerHTML='';
    \\  for(var i=0;i<genChips.length;i++){
    \\    var chip=document.createElement('span');
    \\    chip.className='chip';chip.setAttribute('data-idx',i);
    \\    chip.title=genChips[i].desc||genChips[i].name+' \u2192 '+genChips[i].value;
    \\    var label=document.createElement('span');label.className='chip-label';
    \\    label.textContent=genChips[i].name!=genChips[i].value?genChips[i].name+' \u2192 '+genChips[i].value:genChips[i].name;
    \\    label.onclick=(function(v){return function(){insertTpl(v)}})(genChips[i].value);
    \\    var edit=document.createElement('span');edit.className='chip-edit';edit.textContent='\u270e';
    \\    edit.onclick=(function(idx){return function(){editChip(idx)}})(i);
    \\    var x=document.createElement('span');x.className='chip-x';x.textContent='\u00d7';
    \\    x.onclick=(function(idx){return function(){removeChip(idx)}})(i);
    \\    chip.appendChild(label);chip.appendChild(edit);chip.appendChild(x);c.appendChild(chip);
    \\  }
    \\}
    \\function removeChip(idx){genChips.splice(idx,1);saveChips();renderChips();renderSettingsChips()}
    \\function showAddChip(){$('chip-dialog').style.display='';$('chip-name').value='';$('chip-value').value='';$('chip-name').focus()}
    \\function hideAddChip(){$('chip-dialog').style.display='none'}
    \\function addCustomChip(){
    \\  var n=$('chip-name').value.trim();var v=$('chip-value').value.trim();
    \\  if(!n||!v){toast('Name and value required','error');return}
    \\  genChips.push({name:n,value:v});saveChips();renderChips();renderSettingsChips();hideAddChip();toast('Chip added','success');
    \\}
    \\function editChip(idx){
    \\  var ch=genChips[idx];
    \\  var fields=[];
    \\  if(ch.desc)fields.push({label:'Description',value:ch.desc,placeholder:'',readonly:true});
    \\  fields.push({label:'Label',value:ch.name,placeholder:'Label name'});
    \\  fields.push({label:'Template Value',value:ch.value,placeholder:'Template value'});
    \\  showModal('Edit Chip',fields,function(vals){
    \\    var off=ch.desc?1:0;
    \\    var n=vals[off];var v=vals[off+1];
    \\    if(!n||!v){toast('Name and value required','error');return}
    \\    genChips[idx]={name:n,value:v,desc:ch.desc};saveChips();renderChips();renderSettingsChips();toast('Chip updated','success');
    \\  });
    \\}
    \\function resetChips(){genChips=defaultChips.slice();saveChips();renderChips();renderSettingsChips();toast('Chips reset to defaults','success')}
    \\function renderSettingsChips(){
    \\  var c=$('settings-chips');if(!c)return;c.innerHTML='';
    \\  for(var i=0;i<genChips.length;i++){
    \\    var chip=document.createElement('span');
    \\    chip.className='chip';chip.setAttribute('data-idx',i);
    \\    chip.title=genChips[i].name+' \u2192 '+genChips[i].value;
    \\    var label=document.createElement('span');label.className='chip-label';
    \\    label.textContent=genChips[i].name!=genChips[i].value?genChips[i].name+' \u2192 '+genChips[i].value:genChips[i].name;
    \\    label.onclick=(function(idx){return function(){editChip(idx);renderSettingsChips()}})(i);
    \\    var edit=document.createElement('span');edit.className='chip-edit';edit.textContent='\u270e';
    \\    edit.onclick=(function(idx){return function(){editChip(idx);renderSettingsChips()}})(i);
    \\    var x=document.createElement('span');x.className='chip-x';x.textContent='\u00d7';
    \\    x.onclick=(function(idx){return function(){removeChip(idx);renderSettingsChips()}})(i);
    \\    chip.appendChild(label);chip.appendChild(edit);chip.appendChild(x);c.appendChild(chip);
    \\  }
    \\}
    \\function showSettingsAddChip(){$('settings-chip-dialog').style.display='';$('settings-chip-name').value='';$('settings-chip-value').value='';$('settings-chip-name').focus()}
    \\function hideSettingsAddChip(){$('settings-chip-dialog').style.display='none'}
    \\function addSettingsChip(){
    \\  var n=$('settings-chip-name').value.trim();var v=$('settings-chip-value').value.trim();
    \\  if(!n||!v){toast('Name and value required','error');return}
    \\  genChips.push({name:n,value:v});saveChips();renderChips();renderSettingsChips();hideSettingsAddChip();toast('Chip added','success');
    \\}
    \\// ── Built-in template data ──
    \\function setLines(id,items){if($(id))$(id).value=(items||[]).join('\n')}
    \\function getLines(id){
    \\  if(!$(id))return [];
    \\  return $(id).value.split(/\r?\n/).map(function(v){return v.trim()}).filter(function(v){return v.length>0});
    \\}
    \\function setBirthdayLines(id,items){
    \\  if(!$(id))return;
    \\  $(id).value=(items||[]).map(function(entry){return entry.name+'='+entry.birthday}).join('\n');
    \\}
    \\function getBirthdayLines(id){
    \\  var lines=getLines(id);var out=[];
    \\  for(var i=0;i<lines.length;i++){
    \\    var parts=lines[i].split('=');
    \\    if(parts.length!==2||!parts[0].trim()||!parts[1].trim()){toast('Birthday lines must use name=MMDD','error');return null}
    \\    out.push({name:parts[0].trim(),birthday:parts[1].trim()});
    \\  }
    \\  return out;
    \\}
    \\function loadTemplateData(){
    \\  if(!$('template-data-games'))return;
    \\  fetch('/api/template-data').then(function(r){return r.json()}).then(function(d){
    \\    if(!d.ok||!d.data)return;
    \\    setLines('template-data-games',d.data.games_words);
    \\    setLines('template-data-tech',d.data.tech_words);
    \\    setLines('template-data-finance',d.data.finance_words);
    \\    setLines('template-data-general',d.data.general_words);
    \\    setLines('template-data-genshin-characters',d.data.genshin_characters);
    \\    setBirthdayLines('template-data-genshin-birthdays',d.data.genshin_birthdays);
    \\    renderCustomBanks(d.data.custom_banks||{});
    \\  }).catch(function(){});
    \\}
    \\var _customBanks={};
    \\function renderCustomBanks(banks){
    \\  _customBanks=banks||{};var c=$('custom-banks-container');if(!c)return;c.innerHTML='';
    \\  var keys=Object.keys(_customBanks);
    \\  for(var i=0;i<keys.length;i++){
    \\    var k=keys[i];var div=document.createElement('div');
    \\    div.style.cssText='padding:12px;border-radius:14px;background:var(--surface-alt);border:1px solid var(--border)';
    \\    div.innerHTML='<div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:8px">'+
    \\      '<span style="font-size:12px;font-weight:700;color:var(--brand-deep)">{word:'+k+'}</span>'+
    \\      '<button class="hist-btn hist-btn-danger" style="font-size:10px;padding:2px 8px" onclick="removeCustomBank(\''+k+'\')">Remove</button>'+
    \\      '</div><textarea id="custom-bank-'+k+'" class="text-input" style="min-height:100px">'+(_customBanks[k]||[]).join('\n')+'</textarea>';
    \\    c.appendChild(div);
    \\  }
    \\}
    \\function addCustomBank(){
    \\  showModal('Add Custom Word Bank',[{label:'Bank Name (used as {word:NAME})',value:'',placeholder:'e.g. anime'}],function(vals){
    \\    var name=vals[0].trim().toLowerCase().replace(/[^a-z0-9_]/g,'');
    \\    if(!name){toast('Invalid bank name','error');return}
    \\    if(_customBanks[name]){toast('Bank already exists','error');return}
    \\    _customBanks[name]=[];renderCustomBanks(_customBanks);toast('Bank added. Add words then save.','success');
    \\  });
    \\}
    \\function removeCustomBank(name){
    \\  delete _customBanks[name];renderCustomBanks(_customBanks);toast('Bank removed. Save to confirm.','success');
    \\}
    \\function getCustomBanksData(){
    \\  var keys=Object.keys(_customBanks);var out={};
    \\  for(var i=0;i<keys.length;i++){
    \\    var el=$('custom-bank-'+keys[i]);
    \\    out[keys[i]]=el?el.value.split(/\r?\n/).map(function(v){return v.trim()}).filter(function(v){return v.length>0}):(_customBanks[keys[i]]||[]);
    \\  }
    \\  return out;
    \\}
    \\function saveTemplateData(){
    \\  var birthdays=getBirthdayLines('template-data-genshin-birthdays');if(!birthdays)return;
    \\  var body={
    \\    games_words:getLines('template-data-games'),
    \\    tech_words:getLines('template-data-tech'),
    \\    finance_words:getLines('template-data-finance'),
    \\    general_words:getLines('template-data-general'),
    \\    genshin_characters:getLines('template-data-genshin-characters'),
    \\    genshin_birthdays:birthdays,
    \\    custom_banks:getCustomBanksData()
    \\  };
    \\  fetch('/api/template-data',{method:'PUT',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)})
    \\  .then(function(r){return r.json()}).then(function(d){
    \\    if(!d.ok){toast(d.error||'Save failed','error');return}
    \\    toast('Template data saved','success');
    \\  }).catch(function(e){toast('Error: '+e.message,'error')});
    \\}
    \\function resetTemplateData(){
    \\  fetch('/api/template-data',{method:'DELETE'}).then(function(r){return r.json()}).then(function(d){
    \\    if(!d.ok){toast(d.error||'Reset failed','error');return}
    \\    loadTemplateData();toast('Template data reset','success');
    \\  }).catch(function(e){toast('Error: '+e.message,'error')});
    \\}
    \\// ── Misc ──
    \\function copyResult(id){
    \\  var t=$(id).textContent;
    \\  if(navigator.clipboard){navigator.clipboard.writeText(t).then(function(){toast('Copied!','success')})}
    \\  else{var a=document.createElement('textarea');a.value=t;document.body.appendChild(a);a.select();document.execCommand('copy');document.body.removeChild(a);toast('Copied!','success')}
    \\}
    \\function loadHistory(){
    \\  fetch('/api/history').then(function(r){return r.json()}).then(function(d){
    \\    var el=$('history-list');
    \\    if(!d.records||d.records.length===0){el.innerHTML='<p style="color:var(--text-muted);font-size:14px">No history yet</p>';return}
    \\    el.innerHTML='';
    \\    for(var i=0;i<d.records.length;i++){
    \\      var r=d.records[i];var div=document.createElement('div');div.className='hist-item';
    \\      var ct=r.ciphertext_preview||'';
    \\      div.innerHTML='<div class="hist-row">'+
    \\        '<div class="hist-main">'+
    \\        '<div class="hist-meta"><strong>'+r.operation+'</strong>'+
    \\        '<span class="hist-time">'+r.timestamp+'</span>'+
    \\        '<span class="hist-pipe">'+(r.pipeline_desc||'')+'</span></div>'+
    \\        '<code class="hist-code">'+ct+'</code>'+
    \\        '</div>'+
    \\        '<div class="hist-actions">'+
    \\        '<button class="hist-btn" onclick="(function(b){copyText(b.closest(\'.hist-item\').querySelector(\'code\').textContent,b)})(this)">Copy</button>'+
    \\        '<button class="hist-btn hist-btn-danger" onclick="deleteHist(\''+r.id+'\')">Delete</button>'+
    \\        '</div></div>';
    \\      el.appendChild(div);
    \\    }
    \\  }).catch(function(){});
    \\}
    \\function deleteHist(id){
    \\  fetch('/api/history/'+id,{method:'DELETE'}).then(function(){loadHistory();toast('Deleted','success')}).catch(function(){});
    \\}
    \\function clearHist(){
    \\  if(!confirm('Clear all history?'))return;
    \\  fetch('/api/history',{method:'DELETE'}).then(function(){loadHistory();toast('Cleared','success')}).catch(function(){});
    \\}
    \\function setTheme(t){
    \\  localStorage.setItem('vt-theme',t);
    \\  if(t==='auto'){document.documentElement.removeAttribute('data-theme')}
    \\  else{document.documentElement.setAttribute('data-theme',t)}
    \\  toast('Theme: '+t,'success');
    \\}
    \\function cycleTheme(){tIdx=(tIdx+1)%themes.length;setTheme(themes[tIdx])}
    \\function setLang(l){window.location.href='/?lang='+l}
    \\function cycleLang(){
    \\  lIdx=(lIdx+1)%langs.length;setLang(langs[lIdx]);
    \\}
    \\// ── AI Settings ──
    \\var aiCfg={provider:'openai',endpoint:'',key:'',model:''};
    \\function loadAiSettings(){
    \\  var saved=localStorage.getItem('vt-ai-cfg');
    \\  if(saved){try{aiCfg=JSON.parse(saved)}catch(e){}}
    \\  var provSel=$('ai-provider-select');
    \\  if(provSel){
    \\    provSel.setAttribute('data-value',aiCfg.provider||'openai');
    \\    var opts=provSel.querySelectorAll('.custom-select-option');
    \\    opts.forEach(function(o){
    \\      o.classList.remove('selected');
    \\      if(o.getAttribute('data-value')===(aiCfg.provider||'openai'))o.classList.add('selected');
    \\    });
    \\    var trig=provSel.querySelector('.custom-select-trigger span');
    \\    if(trig)trig.textContent=aiCfg.provider==='claude'?'Claude':'OpenAI';
    \\  }
    \\  if($('ai-endpoint'))$('ai-endpoint').value=aiCfg.endpoint||'';
    \\  if($('ai-key'))$('ai-key').value=aiCfg.key||'';
    \\  if($('ai-model'))$('ai-model').value=aiCfg.model||'';
    \\  updateAiProviderLabel();
    \\  var msgs=$('ai-messages');
    \\  if(msgs&&msgs.children.length===0){
    \\    var welcome=aiCfg.key?
    \\      (aiCfg.provider==='claude'?'Claude':'OpenAI')+(aiCfg.model?' \u00b7 '+aiCfg.model:'')+' ready. How can I help?':
    \\      VT_I18N[VT_LANG].ai_no_key;
    \\    appendAiMsg(welcome,'system');
    \\  }
    \\}
    \\function saveAi(){
    \\  var provider=getSelVal('ai-provider-select')||'openai';
    \\  var ep=$('ai-endpoint')?$('ai-endpoint').value:'';
    \\  var k=$('ai-key')?$('ai-key').value:'';
    \\  var model=$('ai-model')?$('ai-model').value:'';
    \\  aiCfg={provider:provider,endpoint:ep,key:k,model:model};
    \\  localStorage.setItem('vt-ai-cfg',JSON.stringify(aiCfg));
    \\  fetch('/api/settings',{method:'PUT',headers:{'Content-Type':'application/json'},
    \\    body:JSON.stringify({ai_provider:provider,ai_endpoint:ep,ai_key:k,ai_model:model})})
    \\  .then(function(){toast('AI config saved','success');updateAiProviderLabel()})
    \\  .catch(function(e){toast('Error: '+e,'error')});
    \\}
    \\function updateAiProviderLabel(){
    \\  var lbl=$('ai-provider-label');
    \\  if(lbl)lbl.textContent=(aiCfg.provider==='claude'?'Claude':'OpenAI')+(aiCfg.model?' \u00b7 '+aiCfg.model:'');
    \\}
    \\function testAiConnect(){
    \\  var provider=getSelVal('ai-provider-select')||'openai';
    \\  var ep=$('ai-endpoint')?$('ai-endpoint').value:'';
    \\  var k=$('ai-key')?$('ai-key').value:'';
    \\  var model=$('ai-model')?$('ai-model').value:'';
    \\  if(!k){toast('API key required','error');return}
    \\  toast('Testing connection...','info');
    \\  fetch('/api/ai/test',{method:'POST',headers:{'Content-Type':'application/json'},
    \\    body:JSON.stringify({provider:provider,endpoint:ep,key:k,model:model})})
    \\  .then(function(r){return r.json()}).then(function(d){
    \\    if(d.ok){toast('Connected! Latency: '+d.latency_ms+'ms','success')}
    \\    else{toast('Failed: '+(d.error||'unknown error'),'error')}
    \\  }).catch(function(e){toast('Error: '+e.message,'error')});
    \\}
    \\// ── AI Chat ──
    \\var aiModeSystemPrompts={
    \\  chat:'General assistant mode. Use tools when web info, time, system info, encryption, decryption, generation, or puzzle operations are needed.',
    \\  encrypt:'Focus on encryption tasks. Use the encrypt tool when the user wants a real encrypted output.',
    \\  decrypt:'Focus on decryption tasks. Use the decrypt tool when the user wants a real decrypted output.',
    \\  puzzle:'Focus on puzzle splitting or merging. Use puzzle_split and puzzle_merge when the user asks for actual pieces or merged text.',
    \\  generate:'Focus on template generation. Use the generate tool when the user wants a generated output.'
    \\};
    \\function setAiMode(mode){
    \\  aiMode=mode;
    \\  document.querySelectorAll('.ai-mode-btn').forEach(function(b){
    \\    b.classList.toggle('active',b.getAttribute('data-mode')===mode);
    \\  });
    \\}
    \\function aiKeydown(e){
    \\  if(e.key==='Enter'&&!e.shiftKey){e.preventDefault();sendAiMsg()}
    \\}
    \\function parseMd(t){
    \\  var esc=function(s){return s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;')};
    \\  var blocks=[];var lines=t.split('\n');var i=0;
    \\  while(i<lines.length){
    \\    var ln=lines[i];
    \\    if(ln.match(/^```/)){
    \\      var lang=ln.slice(3).trim();var code=[];i++;
    \\      while(i<lines.length&&!lines[i].match(/^```/)){code.push(lines[i]);i++}
    \\      i++;blocks.push('<pre><code>'+esc(code.join('\n'))+'</code></pre>');continue;
    \\    }
    \\    if(ln.match(/^### /)){blocks.push('<h5>'+esc(ln.slice(4))+'</h5>');i++;continue}
    \\    if(ln.match(/^## /)){blocks.push('<h4>'+esc(ln.slice(3))+'</h4>');i++;continue}
    \\    if(ln.match(/^# /)){blocks.push('<h3>'+esc(ln.slice(2))+'</h3>');i++;continue}
    \\    if(ln.match(/^[-*] /)){
    \\      var items=[];
    \\      while(i<lines.length&&lines[i].match(/^[-*] /)){items.push('<li>'+inlineMd(esc(lines[i].slice(2)))+'</li>');i++}
    \\      blocks.push('<ul>'+items.join('')+'</ul>');continue;
    \\    }
    \\    if(ln.match(/^\d+\. /)){
    \\      var items=[];
    \\      while(i<lines.length&&lines[i].match(/^\d+\. /)){items.push('<li>'+inlineMd(esc(lines[i].replace(/^\d+\. /,'')))+'</li>');i++}
    \\      blocks.push('<ol>'+items.join('')+'</ol>');continue;
    \\    }
    \\    if(ln.trim()===''){blocks.push('<br>');i++;continue}
    \\    blocks.push('<p>'+inlineMd(esc(ln))+'</p>');i++;
    \\  }
    \\  return blocks.join('');
    \\}
    \\function inlineMd(s){
    \\  s=s.replace(/`([^`]+)`/g,'<code>$1</code>');
    \\  s=s.replace(/\*\*([^*]+)\*\*/g,'<strong>$1</strong>');
    \\  s=s.replace(/\*([^*]+)\*/g,'<em>$1</em>');
    \\  return s;
    \\}
    \\function appendAiMsg(text,role){
    \\  var msgs=$('ai-messages');if(!msgs)return;
    \\  var div=document.createElement('div');
    \\  div.className='ai-msg ai-msg-'+(role==='user'?'user':role==='system'?'system':'ai');
    \\  if(role==='ai'){div.innerHTML=parseMd(text)}
    \\  else{div.textContent=text}
    \\  msgs.appendChild(div);msgs.scrollTop=msgs.scrollHeight;
    \\  return div;
    \\}
    \\function sendAiMsg(){
    \\  var inp=$('ai-input');var msg=inp.value.trim();if(!msg)return;
    \\  var saved=localStorage.getItem('vt-ai-cfg');
    \\  if(saved){try{aiCfg=JSON.parse(saved)}catch(e){}}
    \\  if(!aiCfg.key){appendAiMsg(VT_I18N[VT_LANG].ai_no_key,'system');inp.value='';return}
    \\  appendAiMsg(msg,'user');inp.value='';
    \\  var thinking=appendAiMsg(VT_I18N[VT_LANG].ai_thinking,'system');
    \\  var systemPrompt=aiModeSystemPrompts[aiMode]||aiModeSystemPrompts.chat;
    \\  fetch('/api/ai/chat',{method:'POST',headers:{'Content-Type':'application/json'},
    \\    body:JSON.stringify({message:msg,system_prompt:systemPrompt,provider:aiCfg.provider,
    \\      endpoint:aiCfg.endpoint,key:aiCfg.key,model:aiCfg.model})})
    \\  .then(function(r){return r.json()}).then(function(d){
    \\    if(thinking&&thinking.parentNode)thinking.parentNode.removeChild(thinking);
    \\    if(!d.ok||d.error){appendAiMsg('Error: '+(d.error||'unknown'),'system');return}
    \\    var reply=d.reply||'';
    \\    appendAiMsg(reply,'ai');
    \\    if(d.actions&&d.actions.length){applyAiActions(d.actions)}else{handleAiAction(reply)}
    \\  }).catch(function(e){
    \\    if(thinking&&thinking.parentNode)thinking.parentNode.removeChild(thinking);
    \\    appendAiMsg('Error: '+e.message,'system');
    \\  });
    \\}
    \\function setSinglePipeline(target,algorithm){
    \\  if(target==='encrypt'){ePipeline=[];if(algorithm)ePipeline.push(algorithm);renderPipeline('encrypt-pipeline',ePipeline)}
    \\  else if(target==='decrypt'){dPipeline=[];if(algorithm)dPipeline.push(algorithm);renderPipeline('decrypt-pipeline',dPipeline)}
    \\}
    \\function applyAiActions(actions){
    \\  for(var i=0;i<actions.length;i++){
    \\    var a=actions[i];if(!a||!a.type)continue;
    \\    if(a.type==='fill_encrypt'){
    \\      $('encrypt-input').value=a.text||'';$('encrypt-key').value=a.key||'';
    \\      setSinglePipeline('encrypt',a.algorithm||'base64');
    \\      if(a.result){$('encrypt-result').textContent=a.result;$('encrypt-result-card').style.display=''}
    \\      showPage('encrypt');toast('AI prepared encrypt result','info');
    \\    }else if(a.type==='fill_decrypt'){
    \\      $('decrypt-input').value=a.text||'';$('decrypt-key').value=a.key||'';
    \\      setSinglePipeline('decrypt',a.algorithm||'base64');
    \\      if(a.result){$('decrypt-result').textContent=a.result;$('decrypt-result-card').style.display='';$('decrypt-verify').textContent=''}
    \\      showPage('decrypt');toast('AI prepared decrypt result','info');
    \\    }else if(a.type==='fill_generate'){
    \\      $('gen-template').value=a.template||'';
    \\      if(a.result){$('gen-result').textContent=a.result;$('gen-result-card').style.display=''}
    \\      showPage('generate');toast('AI prepared generated text','info');
    \\    }else if(a.type==='fill_puzzle_split'){
    \\      $('puzzle-input').value=a.text||'';if(a.pieces_count)$('puzzle-count').value=a.pieces_count;
    \\      showPage('puzzle');if(a.pieces&&a.pieces.length)renderPuzzlePieces(a.pieces);toast('AI prepared puzzle split','info');
    \\    }else if(a.type==='fill_puzzle_merge'){
    \\      $('puzzle-input').value=a.result||'';
    \\      showPage('puzzle');toast('AI prepared puzzle merge','info');
    \\    }
    \\  }
    \\}
    \\function handleAiAction(reply){
    \\  if(reply.startsWith('ENCRYPT:')){
    \\    var parts=reply.slice(8).split('|');
    \\    if(parts.length>=1){$('encrypt-input').value=parts[0];if(parts[2])$('encrypt-key').value=parts[2];showPage('encrypt');toast('AI filled encrypt form','info')}
    \\  }else if(reply.startsWith('DECRYPT:')){
    \\    var parts=reply.slice(8).split('|');
    \\    if(parts.length>=1){$('decrypt-input').value=parts[0];if(parts[2])$('decrypt-key').value=parts[2];showPage('decrypt');toast('AI filled decrypt form','info')}
    \\  }else if(reply.startsWith('GENERATE:')){
    \\    var tpl=reply.slice(9);
    \\    $('gen-template').value=tpl;showPage('generate');toast('AI set template','info');
    \\  }else if(reply.startsWith('PUZZLE_SPLIT:')){
    \\    var parts=reply.slice(13).split('|');
    \\    $('puzzle-input').value=parts[0]||'';if(parts[1])$('puzzle-count').value=parseInt(parts[1])||3;
    \\    showPage('puzzle');toast('AI set puzzle input','info');
    \\  }
    \\}
    \\// ── Init ──
    \\(function(){
    \\  var idx=langs.indexOf(VT_LANG);if(idx>=0)lIdx=idx;
    \\  var t=localStorage.getItem('vt-theme');if(t){var ti=themes.indexOf(t);if(ti>=0)tIdx=ti}
    \\  renderChips();renderSettingsChips();
    \\  var saved=localStorage.getItem('vt-ai-cfg');
    \\  if(saved){try{aiCfg=JSON.parse(saved);updateAiProviderLabel()}catch(e){}}
    \\})();
;
