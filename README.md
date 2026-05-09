# VeilText

**English** | [中文](README.zh.md) | [日本語](README.ja.md)

VeilText is a self-hosted text encryption, encoding, and generation toolkit built with Zig 0.16.0. It ships as a single HTTP server binary with an embedded Web UI, plus an optional `wasm32-freestanding` core module for host-side embedding.

## Features

- **Composable pipelines**: chain Base encodings, symmetric encryption, hashes, JS obfuscation formats, and Brainfuck codecs.
- **Smart decode**: automatically detects likely ciphertext/encoding layers and recursively decodes them.
- **Base codecs**: Base16, Base32, Base58, Base64, Base85. Base64 accepts padded, unpadded, URL-safe, and whitespace-pasted input.
- **Symmetric encryption**: AES-256-GCM, ChaCha20-Poly1305, XChaCha20-Poly1305, and OpenSSL/CryptoJS-compatible AES-256-CBC `Salted__` payloads.
- **Hashes**: SHA-256, SHA-512, BLAKE3, MD5.
- **JS and Brainfuck codecs**: Hex Escape, Unicode Escape, Binary String, JJEncode, AAEncode, JSFuck, Eval Wrap, Constructor Wrap, Base36 ToString, Brainfuck, Brainfuck Emoji.
- **Puzzle mode**: split text into transport-safe Base64 pieces and merge them later.
- **Template generator**: date, random values, UUIDs, word banks, Genshin character data, and custom template chips. See [template reference](docs/TEMPLATES.md).
- **AI assistant**: OpenAI-compatible and Claude API support, with tool calls for encryption, decryption, generation, puzzle, time, and system info.
- **Local history**: the Web UI stores user history in browser `localStorage`; template data remains in `.veiltext-data/.veiltext.db`.
- **i18n and themes**: English, Chinese, Japanese; Light Jade, Dark Ocean, Sakura, Midnight, Amber, and auto mode.
- **WebAssembly core**: pure compute wasm module at `zig-out/bin/Wasm/veiltext-core.wasm`.

## Requirements

- Zig `0.16.0`
- Windows, Linux, macOS, or FreeBSD
- Optional: Node.js for local wasm smoke tests

## Quick Start

```bash
zig build test
zig build run

zig build --release=fast
zig build --release=small

zig build wasm --release=small
zig build dist --release=fast
```

Default URL:

```text
http://127.0.0.1:7478
```

On Windows, `AccessDenied` while overwriting `zig-out/bin/veiltext.exe` usually means an older `veiltext.exe` process is still running. Stop it and rebuild.

## CLI

```text
veiltext [options]

Options:
  -port <port>              Listen port, default 7478
  -bind <address>           Bind address, default 127.0.0.1
  -data <dir>               Data directory, default .veiltext-data
  -openai-key <key>         OpenAI API key
  -openai-endpoint <url>    OpenAI-compatible API endpoint
  -claude-key <key>         Claude API key
  -claude-endpoint <url>    Claude API endpoint
  -h, --help                Show help
  -v, --version             Show version
```

## Distribution Targets

`zig build dist --release=fast` builds native binaries and the wasm core.

| Platform | Targets |
| --- | --- |
| Linux glibc | x86_64, aarch64, x86, arm, riscv64, mips, mips64, powerpc, powerpc64, powerpc64le, s390x, loongarch64, sparc64 |
| Linux musl | x86_64, aarch64, x86, arm, riscv64, mips, mips64, powerpc, powerpc64, powerpc64le, s390x, loongarch64 |
| Windows | x86_64, aarch64, x86 |
| macOS | x86_64, aarch64 |
| FreeBSD | x86_64, aarch64, x86, arm-eabihf, powerpc64, powerpc64le, riscv64 |
| Wasm | wasm32-freestanding |

Output layout:

```text
zig-out/bin/<OS>/veiltext-<arch>[.exe]
zig-out/bin/Wasm/veiltext-core.wasm
```

## Web UI

- **Encrypt**: enter plaintext, choose a pipeline step, optionally provide a key, then encrypt.
- **Decrypt**: paste ciphertext and use the same pipeline used for encryption.
- **AI Decode**: use smart recursive decoding when the input may contain multiple unknown encoding layers.
- **Puzzle**: split text into pieces or merge pieces back into the original text.
- **Generate**: build text from templates such as `sk-{date:MMDD}-{word:tech}-{random:hex:8}`.
- **AI**: chat with an OpenAI-compatible or Claude model and let it call VeilText tools.
- **Settings**: configure AI provider data and customize generator template data.

## API

The HTTP API is documented in [docs/API.md](docs/API.md). Main routes:

| Method | Path | Purpose |
| --- | --- | --- |
| POST | `/api/encrypt` | Run an encryption/encoding pipeline |
| POST | `/api/decrypt` | Reverse a pipeline |
| POST | `/api/decode-smart` | Automatically decode layered text |
| POST | `/api/puzzle/split` | Split text into pieces |
| POST | `/api/puzzle/merge` | Merge pieces |
| POST | `/api/generate` | Generate text from a template |
| GET/DELETE | `/api/history` | Read or clear admin-only backend audit history |
| DELETE | `/api/history/:id` | Delete one admin-only backend audit record |
| GET/PUT/DELETE | `/api/template-data` | Read, update, or reset template data |
| PUT | `/api/settings` | Update AI settings |
| POST | `/api/ai/chat` | AI assistant |
| POST | `/api/ai/test` | Test AI connectivity |

## Pipeline Algorithm IDs

| Category | IDs |
| --- | --- |
| Base | `base16`, `base32`, `base58`, `base64`, `base85` |
| Symmetric | `aes_256_gcm`, `chacha20_poly1305`, `xchacha20_poly1305`, `aes_256_cbc` |
| Hash | `sha256`, `sha512`, `blake3`, `md5` |
| JS codecs | `js_hex_escape`, `js_unicode_escape`, `js_binary_string`, `js_jjencode`, `js_aaencode`, `js_jsfuck`, `js_eval_wrap`, `js_constructor_wrap`, `js_base36_tostring` |
| Brainfuck | `bf_text`, `bf_emoji` |

The codebase also includes tested X25519, Ed25519, PBKDF2, and HKDF modules, but those are not currently exposed as Web UI pipeline steps.

## WebAssembly

Build:

```bash
zig build wasm --release=small
```

Core exports:

```text
veiltext_alloc
veiltext_free
veiltext_transform
veiltext_result_ptr
veiltext_result_len
veiltext_last_error
veiltext_clear_result
```

Full wasm ABI details are in [docs/WASM.md](docs/WASM.md).

## Architecture

```text
src/
├── bin/main.zig           # CLI entry point
├── config.zig             # constants and runtime config
├── server.zig             # HTTP server and API routes
├── wasm.zig               # wasm32-freestanding ABI
├── root.zig               # module exports
├── crypto/                # pipeline, crypto, encodings, puzzle
├── generator/             # templates, dates, random values, word banks, AI
├── storage/               # local KV database and history
├── i18n/                  # zh / ja / en strings
└── view/                  # embedded HTML, CSS, and browser JS
```

## Security Notes

- The server binds to `127.0.0.1` by default. Use `--bind 0.0.0.0` only when you intend to expose it beyond localhost.
- TLS is not built in. Put VeilText behind a reverse proxy for public deployments.
- Web UI history stores operation metadata and ciphertext previews in browser `localStorage`. Backend history APIs are retained for admin-only audit access; configure `--admin-token` or `VEILTEXT_ADMIN_TOKEN` before using them.
- Hash steps are one-way and cannot be decrypted.

## Thanks

- [Ziglang](https://ziglang.org/)
- [Linux.do](https://linux.do/)

## License

GNU Affero General Public License v3.0 (AGPL-3.0). See [LICENSE](LICENSE).
