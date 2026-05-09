# CLAUDE.md

This file gives coding-agent guidance for working in this repository.

## Project Overview

VeilText is a self-hosted text encryption, encoding, smart-decoding, puzzle, template generation, and AI-assistant toolkit written in Zig 0.16.0.

The native app is a Zig HTTP server with embedded HTML/CSS/JS. There is no npm frontend pipeline. The project also builds a standalone `wasm32-freestanding` compute module from `src/wasm.zig`.

## Build Commands

```bash
zig build test
zig build run

zig build --release=fast
zig build --release=small

zig build wasm --release=small
zig build dist --release=fast
zig build dist --release=small
```

On Windows, `AccessDenied` while writing `zig-out/bin/veiltext.exe` usually means an existing `veiltext.exe` process is still running.

## Architecture

- `src/bin/main.zig` — CLI entry point and runtime config parsing.
- `src/server.zig` — HTTP server, routes, API handlers, AI tool loop.
- `src/wasm.zig` — wasm ABI for pure compute transforms.
- `src/root.zig` — root module used by the native binary and tests.
- `src/crypto/` — pipeline engine, base codecs, symmetric crypto, OpenSSL/CryptoJS CBC, hashes, JS obfuscation formats, Brainfuck, puzzle, random source wrapper.
- `src/generator/` — template engine, dates, random values, word banks, AI provider calls, realtime values.
- `src/storage/` — local append-style KV store and history.
- `src/i18n/` — Chinese, Japanese, English UI strings.
- `src/view/` — embedded HTML/CSS/JS.

## Key Patterns

- Frontend code is embedded in Zig string literals in `src/view/layout.zig` and `src/view/theme.zig`.
- Normal Zig strings containing non-ASCII UI text should use `\xNN` escapes. Raw multiline JavaScript/CSS strings should stay ASCII unless there is a specific reason.
- Each HTTP request uses an arena allocator and releases it after the response.
- Long-lived mutable state lives in `ServerState`; changes guarded by `state_mutex` where needed.
- Pipeline encryption uses `crypto/engine.zig`. Decryption passes the original pipeline and the engine reverses it.
- Symmetric encryption payloads are Base64-wrapped for transport.
- Smart decode is feature-based, implemented in `crypto/engine.zig`, and should remain deterministic and bounded.
- wasm must not import server, filesystem, network, threads, AI HTTP, or persistent storage.

## API Surface

Native HTTP routes:

```text
POST   /api/encrypt
POST   /api/decrypt
POST   /api/decode-smart
POST   /api/puzzle/split
POST   /api/puzzle/merge
POST   /api/generate
GET    /api/history       (admin audit token required)
DELETE /api/history       (admin audit token required)
DELETE /api/history/:id   (admin audit token required)
GET    /api/settings
PUT    /api/settings
GET    /api/template-data
PUT    /api/template-data
DELETE /api/template-data
POST   /api/ai/chat
POST   /api/ai/test
```

Full user-facing API docs:

- `docs/API.md`
- `docs/API.zh.md`

## Pipeline Algorithm IDs

```text
base16, base32, base58, base64, base85
aes_256_gcm, chacha20_poly1305, xchacha20_poly1305, aes_256_cbc
sha256, sha512, blake3, md5
js_hex_escape, js_unicode_escape, js_binary_string, js_jjencode, js_aaencode
js_jsfuck, js_eval_wrap, js_constructor_wrap, js_base36_tostring
bf_text, bf_emoji
```

Hash steps are irreversible. The codebase has additional tested modules such as X25519, Ed25519, PBKDF2, and HKDF, but they are not currently Web UI pipeline steps.

## WASM

Build output:

```text
zig-out/bin/Wasm/veiltext-core.wasm
```

Documented ABI:

- `docs/WASM.md`
- `docs/WASM.zh.md`

The current wasm ABI exposes Base codecs, hashes, JS codecs, and Brainfuck codecs. It does not expose AES/ChaCha/OpenSSL CBC yet because those need a key-aware ABI and random nonce/salt handling.

## Documentation

- `README.md`, `README.zh.md`, `README.ja.md` are the main entry points.
- `docs/API*.md` documents HTTP APIs.
- `docs/WASM*.md` documents wasm ABI.
- `docs/TEMPLATES*.md` documents generator template variables.

Keep docs in sync when changing routes, pipeline IDs, build targets, CLI flags, or wasm exports.
