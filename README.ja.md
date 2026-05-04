# VeilText

[English](README.md) | [中文](README.zh.md) | **日本語**

VeilText は Zig 0.16.0 で実装されたセルフホスト型のテキスト暗号化・エンコード・生成ツールキットです。単一の HTTP サーバーバイナリとして動作し、Web UI を内蔵します。ブラウザやホスト環境向けに `wasm32-freestanding` のコアモジュールも提供します。

## 主な機能

- **パイプライン処理**：Base エンコード、対称暗号、ハッシュ、JS 難読化形式、Brainfuck コーデックを組み合わせ可能。
- **AI デコード**：入力の特徴から多層エンコードを推定し、再帰的に復号/デコードを試行。
- **Base コーデック**：Base16、Base32、Base58、Base64、Base85。Base64 は padding なし、URL-safe、空白入り貼り付けにも対応。
- **対称暗号**：AES-256-GCM、ChaCha20-Poly1305、XChaCha20-Poly1305、OpenSSL/CryptoJS 互換 AES-256-CBC `Salted__`。
- **ハッシュ**：SHA-256、SHA-512、BLAKE3、MD5。
- **JS / Brainfuck**：Hex Escape、Unicode Escape、Binary String、JJEncode、AAEncode、JSFuck、Eval Wrap、Constructor Wrap、Base36 ToString、Brainfuck、Brainfuck Emoji。
- **Puzzle モード**：テキストを Base64 の複数ピースに分割し、後で結合。
- **テンプレート生成**：日付、ランダム値、UUID、ワードバンク、原神キャラクターデータ、カスタム変数。詳細は [テンプレートリファレンス](docs/TEMPLATES.ja.md)。
- **AI アシスタント**：OpenAI 互換 API と Claude API に対応。
- **ローカル履歴**：`.veiltext-data/.veiltext.db` に履歴とテンプレートデータを保存。
- **WebAssembly コア**：`zig-out/bin/Wasm/veiltext-core.wasm`。

## 要件

- Zig `0.16.0`
- Windows、Linux、macOS、FreeBSD

## クイックスタート

```bash
zig build test
zig build run

zig build --release=fast
zig build --release=small

zig build wasm --release=small
zig build dist --release=fast
```

デフォルト URL：

```text
http://127.0.0.1:7478
```

Windows で `zig-out/bin/veiltext.exe` の上書き時に `AccessDenied` が出る場合は、古い `veiltext.exe` プロセスが実行中です。停止してから再ビルドしてください。

## CLI

```text
veiltext [options]

Options:
  -port <port>              リッスンポート、デフォルト 7478
  -bind <address>           バインドアドレス、デフォルト 127.0.0.1
  -data <dir>               データディレクトリ、デフォルト .veiltext-data
  -openai-key <key>         OpenAI API key
  -openai-endpoint <url>    OpenAI 互換 API endpoint
  -claude-key <key>         Claude API key
  -claude-endpoint <url>    Claude API endpoint
  -h, --help                ヘルプを表示
  -v, --version             バージョンを表示
```

## 配布ターゲット

`zig build dist --release=fast` はネイティブバイナリと wasm コアを生成します。

| プラットフォーム | ターゲット |
| --- | --- |
| Linux glibc | x86_64, aarch64, x86, arm, riscv64, mips, mips64, powerpc, powerpc64, powerpc64le, s390x, loongarch64, sparc64 |
| Linux musl | x86_64, aarch64, x86, arm, riscv64, mips, mips64, powerpc, powerpc64, powerpc64le, s390x, loongarch64 |
| Windows | x86_64, aarch64, x86 |
| macOS | x86_64, aarch64 |
| FreeBSD | x86_64, aarch64, x86, arm-eabihf, powerpc64, powerpc64le, riscv64 |
| Wasm | wasm32-freestanding |

出力：

```text
zig-out/bin/<OS>/veiltext-<arch>[.exe]
zig-out/bin/Wasm/veiltext-core.wasm
```

## API とアルゴリズム

主な API は `/api/encrypt`、`/api/decrypt`、`/api/decode-smart`、`/api/puzzle/split`、`/api/puzzle/merge`、`/api/generate`、`/api/history`、`/api/template-data`、`/api/ai/chat` です。詳細な API 仕様は [API reference](docs/API.md) を参照してください。

パイプライン ID：

| 種類 | ID |
| --- | --- |
| Base | `base16`, `base32`, `base58`, `base64`, `base85` |
| 対称暗号 | `aes_256_gcm`, `chacha20_poly1305`, `xchacha20_poly1305`, `aes_256_cbc` |
| ハッシュ | `sha256`, `sha512`, `blake3`, `md5` |
| JS | `js_hex_escape`, `js_unicode_escape`, `js_binary_string`, `js_jjencode`, `js_aaencode`, `js_jsfuck`, `js_eval_wrap`, `js_constructor_wrap`, `js_base36_tostring` |
| Brainfuck | `bf_text`, `bf_emoji` |

## WebAssembly

```bash
zig build wasm --release=small
```

wasm ABI の詳細は [WASM reference](docs/WASM.md) を参照してください。

## 構成

```text
src/
├── bin/main.zig
├── config.zig
├── server.zig
├── wasm.zig
├── crypto/
├── generator/
├── storage/
├── i18n/
└── view/
```

## セキュリティメモ

- デフォルトでは `127.0.0.1` にのみバインドします。
- 公開環境では TLS 対応のリバースプロキシを前段に置いてください。
- 履歴には操作メタデータと暗号文プレビューが保存されます。
- ハッシュは一方向であり、復号できません。

## ライセンス

MIT
