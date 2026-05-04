// ═══════════════════════════════════════════════════════════════════
//  CSS Theme System — 6 themes + auto mode
//  All themes use CSS Custom Properties (variables)
// ═══════════════════════════════════════════════════════════════════

pub const theme_css =
    // ── Light Jade (default light) ──
    \\:root,[data-theme="light-jade"]{
    \\--bg:#f0faf8;--bg-2:#dff5f0;--surface:#ffffffdd;--surface-strong:#ffffffef;
    \\--border:#b9ece6;--border-strong:#8ad9d0;--text:#163337;--text-muted:#63797c;
    \\--brand:#36c1b7;--brand-deep:#148f88;--brand-glow:rgba(54,193,183,.15);
    \\--accent:#ff8db2;--shadow:0 20px 60px rgba(22,51,55,.08);
    \\--success:#22c55e;--error:#ef4444;--warn:#f59e0b;
    \\--code-bg:#102426;--code-text:#d8fffb;--input-bg:#fff;--input-border:rgba(54,193,183,.22);--surface-alt:#e8f5f2}
    // ── Dark Ocean (default dark) ──
    \\[data-theme="dark-ocean"]{
    \\--bg:#0d1b1e;--bg-2:#112328;--surface:#1a2e33dd;--surface-strong:#1e363cef;
    \\--border:#2a4f4a;--border-strong:#3a6d65;--text:#d0eae8;--text-muted:#8aa5a8;
    \\--brand:#4dd9cf;--brand-deep:#36c1b7;--brand-glow:rgba(77,217,207,.12);
    \\--accent:#ff8db2;--shadow:0 20px 60px rgba(0,0,0,.25);
    \\--success:#34d399;--error:#f87171;--warn:#fbbf24;
    \\--code-bg:#0a1416;--code-text:#d8fffb;--input-bg:#162a2e;--input-border:rgba(54,193,183,.18);--surface-alt:#1e363c}
    // ── Sakura ──
    \\[data-theme="sakura"]{
    \\--bg:#fef5f8;--bg-2:#fce8ef;--surface:#ffffffdd;--surface-strong:#ffffffef;
    \\--border:#f5c6d4;--border-strong:#eda5ba;--text:#3d1f2b;--text-muted:#8c6275;
    \\--brand:#e8729a;--brand-deep:#d4507e;--brand-glow:rgba(232,114,154,.15);
    \\--accent:#7cb5ec;--shadow:0 20px 60px rgba(61,31,43,.08);
    \\--success:#22c55e;--error:#ef4444;--warn:#f59e0b;
    \\--code-bg:#2a1520;--code-text:#fce8ef;--input-bg:#fff;--input-border:rgba(232,114,154,.22);--surface-alt:#fce8ef}
    // ── Midnight (OLED) ──
    \\[data-theme="midnight"]{
    \\--bg:#000000;--bg-2:#0a0a0a;--surface:#111111dd;--surface-strong:#1a1a1aef;
    \\--border:#2a2a2a;--border-strong:#3a3a3a;--text:#e0e0e0;--text-muted:#888;
    \\--brand:#7c8fff;--brand-deep:#5b6ef0;--brand-glow:rgba(124,143,255,.12);
    \\--accent:#ff8db2;--shadow:0 20px 60px rgba(0,0,0,.5);
    \\--success:#34d399;--error:#f87171;--warn:#fbbf24;
    \\--code-bg:#050505;--code-text:#c8c8ff;--input-bg:#111;--input-border:rgba(124,143,255,.18);--surface-alt:#1a1a1a}
    // ── Amber ──
    \\[data-theme="amber"]{
    \\--bg:#faf5ee;--bg-2:#f2e8d5;--surface:#ffffffdd;--surface-strong:#ffffffef;
    \\--border:#e0cfa8;--border-strong:#c9b078;--text:#3b2f1a;--text-muted:#8a7550;
    \\--brand:#d49a2a;--brand-deep:#b07d15;--brand-glow:rgba(212,154,42,.15);
    \\--accent:#5b9bd5;--shadow:0 20px 60px rgba(59,47,26,.08);
    \\--success:#22c55e;--error:#ef4444;--warn:#f59e0b;
    \\--code-bg:#2a2010;--code-text:#f2e8d5;--input-bg:#fff;--input-border:rgba(212,154,42,.22);--surface-alt:#f2e8d5}
    // ── Auto (prefers-color-scheme) ──
    \\@media(prefers-color-scheme:dark){:root:not([data-theme]){
    \\--bg:#0d1b1e;--bg-2:#112328;--surface:#1a2e33dd;--surface-strong:#1e363cef;
    \\--border:#2a4f4a;--border-strong:#3a6d65;--text:#d0eae8;--text-muted:#8aa5a8;
    \\--brand:#4dd9cf;--brand-deep:#36c1b7;--brand-glow:rgba(77,217,207,.12);
    \\--accent:#ff8db2;--shadow:0 20px 60px rgba(0,0,0,.25);
    \\--success:#34d399;--error:#f87171;--warn:#fbbf24;
    \\--code-bg:#0a1416;--code-text:#d8fffb;--input-bg:#162a2e;--input-border:rgba(54,193,183,.18);--surface-alt:#1e363c}}
;

pub const base_css =
    \\*{box-sizing:border-box;margin:0;padding:0}
    \\html,body{height:100%}
    \\body{font-family:"Inter","SF Pro","PingFang SC","Hiragino Sans GB","Noto Sans SC","Noto Sans JP","Microsoft YaHei",system-ui,sans-serif;
    \\color:var(--text);background:var(--bg);transition:background .3s,color .3s}
    \\a{color:var(--brand-deep);text-decoration:none}a:hover{text-decoration:underline}
    \\code,pre{font-family:"JetBrains Mono","Cascadia Code","Consolas",monospace}
    // ── Layout ──
    \\.app{display:flex;height:100vh;overflow:hidden}
    \\.sidebar{width:72px;min-width:72px;display:flex;flex-direction:column;align-items:center;
    \\padding:20px 0;gap:6px;background:var(--surface);border-right:1px solid var(--border);
    \\transition:background .3s,border-color .3s;z-index:10}
    \\.sidebar-logo{font-size:20px;font-weight:800;color:var(--brand);margin-bottom:16px;letter-spacing:-.02em}
    \\.nav-btn{display:flex;flex-direction:column;align-items:center;gap:4px;padding:10px 6px;
    \\border:none;border-radius:14px;background:transparent;color:var(--text-muted);font-size:10px;
    \\font-weight:600;cursor:pointer;transition:all .2s;width:60px;letter-spacing:.02em}
    \\.nav-btn:hover{background:var(--brand-glow);color:var(--brand)}
    \\.nav-btn.active{background:var(--brand-glow);color:var(--brand-deep)}
    \\.nav-btn svg{width:22px;height:22px}
    \\.nav-spacer{flex:1}
    // ── Main Content ──
    \\.main{flex:1;overflow-y:auto;padding:clamp(20px,3vw,40px);scroll-behavior:smooth}
    \\.page{display:none;animation:pageIn .3s ease}.page.active{display:block}
    \\@keyframes pageIn{from{opacity:0;transform:translateY(12px)}to{opacity:1;transform:translateY(0)}}
    // ── Cards ──
    \\.card{background:var(--surface);border:1px solid var(--border);border-radius:20px;
    \\padding:clamp(18px,2.5vw,28px);box-shadow:var(--shadow);backdrop-filter:blur(12px);
    \\transition:background .3s,border-color .3s,box-shadow .3s}
    \\.card+.card{margin-top:20px}
    \\.card-header{display:flex;align-items:center;gap:12px;margin-bottom:16px}
    \\.card-title{font-size:clamp(18px,2vw,24px);font-weight:700;letter-spacing:-.02em}
    \\.card-badge{display:inline-flex;align-items:center;gap:6px;padding:5px 12px;
    \\border-radius:999px;background:var(--brand-glow);color:var(--brand-deep);
    \\font-size:11px;font-weight:700;letter-spacing:.08em;text-transform:uppercase}
    // ── Inputs ──
    \\textarea,.text-input{width:100%;border:1px solid var(--input-border);border-radius:14px;
    \\background:var(--input-bg);color:var(--text);padding:14px 16px;font-size:14px;
    \\line-height:1.6;resize:vertical;transition:border-color .2s,box-shadow .2s;font-family:inherit}
    \\textarea:focus,.text-input:focus{outline:none;border-color:var(--brand);
    \\box-shadow:0 0 0 4px var(--brand-glow)}
    \\textarea{min-height:120px}
    \\.text-input{min-height:48px}
    // ── Buttons ──
    \\.btn{display:inline-flex;align-items:center;justify-content:center;gap:8px;
    \\padding:12px 24px;border:none;border-radius:14px;font-size:14px;font-weight:700;
    \\cursor:pointer;transition:all .2s;letter-spacing:.01em}
    \\.btn-primary{background:linear-gradient(135deg,var(--brand-deep),var(--brand));
    \\color:#fff;box-shadow:0 8px 24px rgba(20,143,136,.2)}
    \\.btn-primary:hover{filter:brightness(1.05);transform:translateY(-1px);
    \\box-shadow:0 12px 32px rgba(20,143,136,.25)}
    \\.btn-primary:active{transform:translateY(0)}
    \\.btn-secondary{background:var(--brand-glow);color:var(--brand-deep);border:1px solid var(--input-border)}
    \\.btn-secondary:hover{background:var(--brand);color:#fff}
    \\.btn-sm{padding:8px 16px;font-size:12px;border-radius:10px}
    \\.btn-icon{width:40px;height:40px;padding:0;border-radius:12px;
    \\background:var(--brand-glow);color:var(--brand-deep);border:1px solid var(--input-border)}
    \\.btn-icon:hover{background:var(--brand);color:#fff}
    \\.btn:disabled{opacity:.5;cursor:not-allowed;transform:none!important}
    // ── Pipeline Steps ──
    \\.pipeline{display:flex;flex-wrap:wrap;gap:8px;align-items:center;margin:16px 0}
    \\.pipeline-step{display:inline-flex;align-items:center;gap:6px;padding:8px 14px;
    \\border-radius:12px;background:var(--surface-strong);border:1px solid var(--border);
    \\font-size:13px;font-weight:600;cursor:grab;transition:all .2s;user-select:none}
    \\.pipeline-step:hover{border-color:var(--brand);box-shadow:0 4px 12px var(--brand-glow)}
    \\.pipeline-step.active{border-color:var(--brand);background:var(--brand-glow);animation:stepPulse .6s ease}
    \\.pipeline-step .remove{cursor:pointer;opacity:.5;font-size:16px;line-height:1}
    \\.pipeline-step .remove:hover{opacity:1;color:var(--error)}
    \\.pipeline-arrow{color:var(--text-muted);font-size:16px}
    \\@keyframes stepPulse{0%{transform:scale(1)}50%{transform:scale(1.05)}100%{transform:scale(1)}}
    // ── Result Box ──
    \\.result-box{position:relative;padding:18px;border-radius:16px;background:var(--code-bg);
    \\color:var(--code-text);font-family:"JetBrains Mono",monospace;font-size:13px;
    \\line-height:1.7;word-break:break-all;white-space:pre-wrap;min-height:60px;
    \\animation:fadeUp .35s ease}
    \\@keyframes fadeUp{from{opacity:0;transform:translateY(8px)}to{opacity:1;transform:translateY(0)}}
    \\.copy-btn{position:absolute;top:10px;right:10px;padding:6px 14px;border-radius:10px;
    \\background:rgba(54,193,183,.12);border:1px solid rgba(54,193,183,.2);
    \\color:var(--brand);font-size:11px;font-weight:700;cursor:pointer;transition:all .2s}
    \\.copy-btn:hover{background:rgba(54,193,183,.24)}
    \\.copy-btn.copied{background:rgba(34,197,94,.15);border-color:rgba(34,197,94,.3);color:var(--success)}
    // ── Toast ──
    \\.toast-container{position:fixed;top:20px;right:20px;z-index:9999;display:flex;
    \\flex-direction:column;gap:10px;pointer-events:none}
    \\.toast{pointer-events:auto;padding:14px 20px;border-radius:14px;font-size:13px;
    \\font-weight:600;box-shadow:0 8px 32px rgba(0,0,0,.12);backdrop-filter:blur(12px);
    \\animation:toastIn .3s ease forwards;max-width:360px}
    \\.toast-success{background:rgba(34,197,94,.12);border:1px solid rgba(34,197,94,.25);color:var(--success)}
    \\.toast-error{background:rgba(239,68,68,.1);border:1px solid rgba(239,68,68,.25);color:var(--error)}
    \\.toast-info{background:var(--brand-glow);border:1px solid rgba(54,193,183,.25);color:var(--brand-deep)}
    \\.toast-out{animation:toastOut .3s ease forwards}
    \\@keyframes toastIn{from{opacity:0;transform:translateX(40px) scale(.95)}to{opacity:1;transform:translateX(0) scale(1)}}
    \\@keyframes toastOut{from{opacity:1}to{opacity:0;transform:translateX(40px) scale(.95)}}
    // ── Toolbar ──
    \\.toolbar{display:flex;align-items:center;gap:8px;flex-wrap:wrap}
    \\.toolbar-spacer{flex:1}
    \\.decrypt-actions{display:flex;align-items:center;gap:10px;flex-wrap:wrap}
    \\.ai-decode-detail{margin-top:10px;padding:10px 12px;border-radius:12px;background:var(--surface-alt);
    \\border:1px solid var(--border);color:var(--text-muted);font-size:12px;line-height:1.5}
    // ── Grid ──
    \\.grid-2{display:grid;grid-template-columns:repeat(2,1fr);gap:12px}
    \\.grid-3{display:grid;grid-template-columns:repeat(3,1fr);gap:12px}
    // ── History ──
    \\.history-item{display:grid;grid-template-columns:1fr auto;gap:12px;padding:14px 18px;
    \\border-radius:14px;background:var(--surface-strong);border:1px solid var(--border);
    \\transition:all .2s}.history-item:hover{border-color:var(--brand)}
    \\.history-meta{display:flex;gap:12px;align-items:center;font-size:12px;color:var(--text-muted)}
    \\.history-badge{padding:3px 8px;border-radius:8px;font-size:11px;font-weight:700;
    \\background:var(--brand-glow);color:var(--brand-deep)}
    // ── Select / Dropdown ──
    \\.select{padding:10px 14px;border:1px solid var(--input-border);border-radius:12px;
    \\background:var(--input-bg);color:var(--text);font-size:13px;font-weight:600;cursor:pointer;
    \\transition:border-color .2s}.select:focus{outline:none;border-color:var(--brand)}
    // ── Number input ──
    \\.num-input{width:80px;padding:10px;border:1px solid var(--input-border);border-radius:12px;
    \\background:var(--input-bg);color:var(--text);font-size:14px;text-align:center;font-weight:700}
    // ── Chips ──
    \\.chip{display:inline-flex;align-items:center;gap:4px;padding:5px 10px;border-radius:20px;
    \\background:var(--brand-glow);border:1px solid rgba(54,193,183,.25);font-size:12px;
    \\font-weight:600;color:var(--brand-deep);cursor:default;transition:all .2s;user-select:none}
    \\.chip:hover{border-color:var(--brand);background:rgba(54,193,183,.2)}
    \\.chip-label{cursor:pointer}.chip-label:hover{text-decoration:underline}
    \\.chip-edit{cursor:pointer;font-size:11px;opacity:.5;transition:opacity .2s}
    \\.chip-edit:hover{opacity:1}
    \\.chip-x{cursor:pointer;font-size:14px;font-weight:700;color:var(--error);opacity:.4;
    \\transition:opacity .2s;margin-left:2px}.chip-x:hover{opacity:1}
    \\.chips-container{min-height:32px}
    // ── Custom Select ──
    \\.custom-select{position:relative;display:inline-block;min-width:160px}
    \\.custom-select-trigger{display:flex;align-items:center;justify-content:space-between;gap:8px;
    \\padding:10px 14px;border:1px solid var(--input-border);border-radius:12px;
    \\background:var(--input-bg);color:var(--text);font-size:13px;font-weight:600;cursor:pointer;
    \\transition:border-color .2s;user-select:none}
    \\.custom-select-trigger:hover{border-color:var(--brand)}
    \\.custom-select-trigger.open{border-color:var(--brand);border-radius:12px 12px 0 0}
    \\.custom-select-trigger.open.open-up{border-radius:0 0 12px 12px}
    \\.custom-select-trigger .arrow{font-size:10px;color:var(--text-muted);transition:transform .2s}
    \\.custom-select-trigger.open .arrow{transform:rotate(180deg)}
    \\.custom-select-options{display:none;position:fixed;
    \\background:var(--surface-strong);border:1px solid var(--brand);
    \\border-radius:0 0 12px 12px;max-height:240px;overflow-y:auto;z-index:99999;
    \\box-shadow:0 8px 24px rgba(0,0,0,.18)}
    \\.custom-select-options.open{display:block}
    \\.custom-select-options.open-up{border-radius:12px 12px 0 0}
    \\.custom-select-option{padding:10px 14px;font-size:13px;font-weight:500;cursor:pointer;
    \\transition:background .15s,color .15s}
    \\.custom-select-option:hover{background:var(--brand-glow);color:var(--brand-deep)}
    \\.custom-select-option.selected{color:var(--brand-deep);font-weight:700;background:var(--brand-glow)}
    \\.custom-select-option:last-child{border-radius:0 0 12px 12px}
    \\.custom-select-separator{padding:6px 14px;font-size:11px;font-weight:700;color:var(--text-muted);
    \\background:var(--surface-alt);border-top:1px solid var(--input-border);
    \\border-bottom:1px solid var(--input-border);user-select:none;pointer-events:none;letter-spacing:.05em}
    // ── History entry ──
    \\.hist-item{padding:14px 16px;border-radius:14px;background:var(--surface-strong);
    \\border:1px solid var(--border);margin-bottom:8px;transition:border-color .2s}
    \\.hist-item:hover{border-color:var(--brand)}
    \\.hist-row{display:flex;align-items:flex-start;justify-content:space-between;gap:12px}
    \\.hist-main{flex:1;min-width:0}
    \\.hist-meta{display:flex;flex-wrap:wrap;align-items:center;gap:8px;font-size:12px;margin-bottom:6px}
    \\.hist-meta strong{font-size:13px;color:var(--brand-deep)}
    \\.hist-time{color:var(--text-muted)}
    \\.hist-pipe{color:var(--text-muted);font-size:12px}
    \\.hist-actions{display:flex;flex-direction:column;gap:6px;flex-shrink:0}
    \\.hist-btn{padding:5px 14px;border-radius:8px;font-size:11px;font-weight:700;cursor:pointer;
    \\border:1px solid var(--input-border);background:var(--input-bg);color:var(--text);
    \\transition:all .15s;min-width:64px;text-align:center}
    \\.hist-btn:hover{border-color:var(--brand);color:var(--brand);background:var(--brand-glow)}
    \\.hist-btn-danger{color:var(--error)}
    \\.hist-btn-danger:hover{border-color:var(--error);color:var(--error);background:rgba(239,68,68,.08)}
    \\.hist-code{display:block;padding:8px 10px;border-radius:8px;background:var(--code-bg);
    \\color:var(--code-text);font-family:"JetBrains Mono",monospace;font-size:12px;line-height:1.55;
    \\word-break:break-all;white-space:pre-wrap;max-height:160px;overflow:auto}
    // ── Modal ──
    \\.modal-overlay{position:fixed;top:0;left:0;width:100%;height:100%;
    \\background:rgba(0,0,0,.45);backdrop-filter:blur(4px);z-index:9000;
    \\display:flex;align-items:center;justify-content:center;animation:modalFadeIn .2s ease}
    \\.modal-card{background:var(--surface-strong);border:1px solid var(--border);
    \\border-radius:20px;padding:28px;min-width:380px;max-width:520px;width:90%;
    \\box-shadow:0 24px 64px rgba(0,0,0,.2);animation:modalSlideIn .25s ease}
    \\.modal-title{font-size:18px;font-weight:700;margin-bottom:16px;color:var(--text)}
    \\.modal-field{margin-bottom:12px}
    \\.modal-field label{display:block;font-size:12px;font-weight:600;color:var(--text-muted);margin-bottom:4px}
    \\.modal-actions{display:flex;justify-content:flex-end;gap:8px;margin-top:20px}
    \\@keyframes modalFadeIn{from{opacity:0}to{opacity:1}}
    \\@keyframes modalSlideIn{from{opacity:0;transform:scale(.95) translateY(-10px)}to{opacity:1;transform:scale(1) translateY(0)}}
    // ── Variable reference ──
    \\.var-ref-grid{display:grid;grid-template-columns:auto 1fr;gap:4px 16px;font-size:12px;
    \\padding:10px 12px;border-radius:10px;background:var(--surface-alt);margin-top:6px}
    \\.var-ref-grid code{cursor:pointer;color:var(--brand-deep);font-weight:600;font-family:'SF Mono',Monaco,Consolas,monospace;
    \\padding:2px 6px;border-radius:4px;transition:background .15s}
    \\.var-ref-grid code:hover{background:var(--brand-glow)}
    \\.var-ref-grid span{color:var(--text-muted);line-height:1.8}
    // ── Puzzle piece copy ──
    \\.piece-card{position:relative;padding:14px 18px;border-radius:14px;background:var(--code-bg);
    \\color:var(--code-text);font-family:"JetBrains Mono",monospace;font-size:13px;line-height:1.6;
    \\word-break:break-all;margin-bottom:8px}
    \\.piece-header{display:flex;align-items:center;justify-content:space-between;margin-bottom:6px}
    \\.piece-label{font-weight:700;font-size:12px;color:var(--brand)}
    \\.piece-copy{padding:4px 12px;border-radius:8px;background:rgba(54,193,183,.12);
    \\border:1px solid rgba(54,193,183,.2);color:var(--brand);font-size:11px;font-weight:700;
    \\cursor:pointer;transition:all .2s}
    \\.piece-copy:hover{background:rgba(54,193,183,.24)}
    \\.piece-copy.copied{background:rgba(34,197,94,.15);border-color:rgba(34,197,94,.3);color:var(--success)}
    // ── Toggle switch ──
    \\.toggle{display:flex;align-items:center;gap:8px;cursor:pointer;user-select:none}
    \\.toggle-track{width:36px;height:20px;border-radius:10px;background:var(--border);
    \\position:relative;transition:background .2s}
    \\.toggle-track.on{background:var(--brand)}
    \\.toggle-knob{width:16px;height:16px;border-radius:50%;background:#fff;position:absolute;
    \\top:2px;left:2px;transition:transform .2s;box-shadow:0 1px 3px rgba(0,0,0,.2)}
    \\.toggle-track.on .toggle-knob{transform:translateX(16px)}
    \\.toggle-label{font-size:13px;font-weight:600}
    // ── AI Chat ──
    \\.ai-chat-container{display:flex;flex-direction:column;height:calc(100vh - 320px);min-height:260px;max-height:520px}
    \\.ai-messages{flex:1;overflow-y:auto;padding:16px;display:flex;flex-direction:column;gap:12px;
    \\background:var(--surface-alt);border-radius:16px;margin-bottom:12px}
    \\.ai-msg{max-width:85%;padding:12px 16px;border-radius:16px;font-size:14px;line-height:1.6}
    \\.ai-msg-user{align-self:flex-end;background:linear-gradient(135deg,var(--brand-deep),var(--brand));
    \\color:#fff;border-bottom-right-radius:4px}
    \\.ai-msg-ai{align-self:flex-start;background:var(--surface-strong);border:1px solid var(--border);
    \\color:var(--text);border-bottom-left-radius:4px}
    \\.ai-msg-ai h3,.ai-msg-ai h4,.ai-msg-ai h5{margin:8px 0 4px;font-weight:700}
    \\.ai-msg-ai h3{font-size:15px}.ai-msg-ai h4{font-size:14px}.ai-msg-ai h5{font-size:13px}
    \\.ai-msg-ai ul,.ai-msg-ai ol{margin:4px 0;padding-left:20px}
    \\.ai-msg-ai li{margin:2px 0}
    \\.ai-msg-ai code{background:rgba(0,0,0,.1);padding:1px 5px;border-radius:4px;font-family:"JetBrains Mono",monospace;font-size:12px}
    \\.ai-msg-ai pre{white-space:pre-wrap;word-break:break-all;font-family:"JetBrains Mono",monospace;
    \\font-size:12px;margin:6px 0;padding:10px;background:rgba(0,0,0,.12);border-radius:8px;overflow-x:auto}
    \\.ai-msg-ai pre code{background:none;padding:0;border-radius:0}
    \\.ai-msg-system{align-self:center;background:var(--brand-glow);color:var(--text-muted);
    \\font-size:12px;padding:6px 12px;border-radius:20px;border:1px solid var(--input-border)}
    \\.ai-msg pre{white-space:pre-wrap;word-break:break-all;font-family:"JetBrains Mono",monospace;
    \\font-size:12px;margin-top:6px;padding:8px;background:rgba(0,0,0,.12);border-radius:8px}
    \\.ai-input-row{display:flex;gap:8px;align-items:flex-end}
    \\.ai-input-row textarea{flex:1;min-height:48px;max-height:120px;resize:none}
    \\.ai-modes{display:flex;flex-wrap:wrap;gap:6px;margin-bottom:10px}
    \\.ai-mode-btn{padding:6px 14px;border-radius:20px;font-size:12px;font-weight:600;cursor:pointer;
    \\border:1px solid var(--input-border);background:var(--input-bg);color:var(--text-muted);transition:all .2s}
    \\.ai-mode-btn.active{background:var(--brand-glow);color:var(--brand-deep);border-color:var(--brand)}
    \\.ai-mode-btn:hover{background:var(--brand-glow);color:var(--brand-deep)}
    \\.ai-provider-label{font-size:12px;color:var(--text-muted);font-weight:600;padding:4px 8px;
    \\background:var(--brand-glow);border-radius:8px;display:inline-block;margin-bottom:8px}
    // ── Responsive ──
    \\@media(max-width:768px){.sidebar{width:60px;min-width:60px}.nav-btn{width:50px;font-size:9px}
    \\.nav-btn svg{width:20px;height:20px}.grid-2,.grid-3{grid-template-columns:1fr}
    \\.modal-card{min-width:auto;padding:20px}}
    \\@media(max-width:480px){.sidebar{width:52px;min-width:52px;padding:12px 0}
    \\.main{padding:14px}.card{border-radius:16px;padding:14px}}
;
