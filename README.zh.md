# VeilText

[English](README.md) | **中文** | [日本語](README.ja.md)

VeilText 是一个自托管文本加密与编码工具箱，使用 Zig 0.16.0 构建。它提供单文件 HTTP 服务端、内嵌 Web UI、加密管线、智能解码、模板生成器、Puzzle 拆分、AI 助手和 wasm 核心模块。

## 当前能力

- **加密/解密管线**：按顺序组合 Base 编码、对称加密、哈希、JS 混淆、Brainfuck 编码等步骤。
- **AI 解码**：与普通解密同页，自动判断解码结果是否仍像密文，并继续尝试下一层解码。
- **Base 编码**：Base16、Base32、Base58、Base64、Base85。Base64 支持无 padding、URL-safe 字符和带空白的粘贴内容。
- **对称加密**：AES-256-GCM、ChaCha20-Poly1305、XChaCha20-Poly1305、AES-256-CBC OpenSSL/CryptoJS `Salted__` 格式。
- **哈希**：SHA-256、SHA-512、BLAKE3、MD5。哈希步骤不可逆，只能用于加密/摘要方向。
- **JS/Brainfuck 编码**：Hex Escape、Unicode Escape、Binary String、JJEncode、AAEncode、JSFuck、Eval Wrap、Constructor Wrap、Base36 ToString、Brainfuck、Brainfuck Emoji。
- **Puzzle 模式**：将文本拆分为多个 Base64 文本碎片，支持合并恢复。
- **模板生成器**：支持日期、随机值、UUID、词库、原神角色数据、自定义变量芯片。详见 [模板变量参考](docs/TEMPLATES.zh.md)。
- **AI 助手**：支持 OpenAI-compatible API 和 Claude API，可调用内置工具完成加密、解密、生成、Puzzle、时间和系统信息查询。
- **本地历史与设置**：历史记录和模板数据保存在本地 `.veiltext-data/.veiltext.db`。
- **多语言与主题**：中文、日文、英文；Light Jade、Dark Ocean、Sakura、Midnight、Amber 和自动主题。
- **wasm 核心模块**：提供可嵌入浏览器/宿主环境的纯计算编码模块，详见 [WASM 文档](docs/WASM.zh.md)。

## 环境要求

- Zig `0.16.0`
- Windows、Linux、macOS 或 FreeBSD
- 可选：Node.js，用于本地验证 wasm 产物

## 快速开始

```powershell
# 测试
zig build test

# 调试运行
zig build run

# 发布构建
zig build --release=fast
zig build --release=small

# 全量分发构建，包含原生二进制和 wasm
zig build dist --release=fast
```

默认服务地址：

```text
http://127.0.0.1:7478
```

如果 Windows 提示 `AccessDenied` 且目标是 `zig-out\bin\veiltext.exe`，通常是旧的 `veiltext.exe` 仍在运行。先关闭该进程后重新构建。

## 命令行参数

```text
veiltext [options]

Options:
  -port <port>              监听端口，默认 7478
  -bind <address>           绑定地址，默认 127.0.0.1
  -data <dir>               数据目录，默认 .veiltext-data
  -openai-key <key>         OpenAI API key
  -openai-endpoint <url>    OpenAI-compatible API endpoint
  -claude-key <key>         Claude API key
  -claude-endpoint <url>    Claude API endpoint
  -h, --help                显示帮助
  -v, --version             显示版本
```

示例：

```powershell
.\zig-out\bin\veiltext.exe --port 7478 --bind 127.0.0.1
```

## 构建产物

`zig build dist --release=fast` 会生成以下目标：

| 平台 | 目标 |
| --- | --- |
| Linux glibc | x86_64, aarch64, x86, arm, riscv64, mips, mips64, powerpc, powerpc64, powerpc64le, s390x, loongarch64, sparc64 |
| Linux musl | x86_64, aarch64, x86, arm, riscv64, mips, mips64, powerpc, powerpc64, powerpc64le, s390x, loongarch64 |
| Windows | x86_64, aarch64, x86 |
| macOS | x86_64, aarch64 |
| FreeBSD | x86_64, aarch64, x86, arm-eabihf, powerpc64, powerpc64le, riscv64 |
| Wasm | wasm32-freestanding |

原生二进制输出：

```text
zig-out/bin/<OS>/veiltext-<arch>[.exe]
```

wasm 输出：

```text
zig-out/bin/Wasm/veiltext-core.wasm
```

## Web UI 使用

### 加密

1. 打开 `http://127.0.0.1:7478`
2. 进入加密页
3. 输入明文，选择算法，必要时填写密钥
4. 点击加密

### 解密与 AI 解码

普通解密要求你知道正确算法和密钥。AI 解码适合处理多层 Base/JS/Brainfuck/OpenSSL 格式，或者不确定原始编码类型的文本。

AI 解码会：

1. 根据密文特征计算候选算法置信度
2. 尝试解码当前层
3. 判断输出是否仍像编码/密文
4. 最多递归到 `max_depth`，默认 8，服务端上限 12

### Puzzle

Puzzle 拆分会把输入文本分成多个可文本传输的 Base64 碎片。合并时传入任意顺序的所有碎片即可恢复原文。

### 生成器

模板示例：

```text
sk-{date:MMDD}-{word:tech}-{random:hex:8}
```

完整变量见 [docs/TEMPLATES.zh.md](docs/TEMPLATES.zh.md)。

## HTTP API

完整 API 参考见 [docs/API.zh.md](docs/API.zh.md)。常用接口：

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| POST | `/api/encrypt` | 按管线加密/编码 |
| POST | `/api/decrypt` | 按管线反向解密/解码 |
| POST | `/api/decode-smart` | 智能多层解码 |
| POST | `/api/puzzle/split` | 拆分文本 |
| POST | `/api/puzzle/merge` | 合并碎片 |
| POST | `/api/generate` | 模板生成 |
| GET | `/api/history` | 获取历史 |
| DELETE | `/api/history` | 清空历史 |
| DELETE | `/api/history/:id` | 删除单条历史 |
| GET/PUT/DELETE | `/api/template-data` | 读取、更新、重置模板数据 |
| PUT | `/api/settings` | 更新 AI 设置 |
| POST | `/api/ai/chat` | AI 助手 |
| POST | `/api/ai/test` | 测试 AI 连接 |

## 管线算法 ID

| 类别 | ID |
| --- | --- |
| Base | `base16`, `base32`, `base58`, `base64`, `base85` |
| 对称加密 | `aes_256_gcm`, `chacha20_poly1305`, `xchacha20_poly1305`, `aes_256_cbc` |
| 哈希 | `sha256`, `sha512`, `blake3`, `md5` |
| JS 编码 | `js_hex_escape`, `js_unicode_escape`, `js_binary_string`, `js_jjencode`, `js_aaencode`, `js_jsfuck`, `js_eval_wrap`, `js_constructor_wrap`, `js_base36_tostring` |
| Brainfuck | `bf_text`, `bf_emoji` |

代码库还包含 X25519、Ed25519、PBKDF2、HKDF 等底层模块和测试，但当前 Web UI 管线没有直接暴露这些模块。

## wasm API

wasm 模块导出以下 ABI：

```text
veiltext_wasm_abi_version() -> u32
veiltext_supported_algorithms_ptr() -> usize
veiltext_supported_algorithms_len() -> usize
veiltext_alloc(len) -> ptr
veiltext_free(ptr, len)
veiltext_transform(algorithm, mode, ptr, len) -> 1/0
veiltext_result_ptr() -> ptr
veiltext_result_len() -> len
veiltext_last_error() -> u32
veiltext_clear_result()
```

算法编号和 JS 调用示例见 [docs/WASM.zh.md](docs/WASM.zh.md)。

## 项目结构

```text
src/
├── bin/main.zig           # CLI 入口
├── config.zig             # 应用常量和运行时配置
├── server.zig             # HTTP 服务与 API 路由
├── wasm.zig               # wasm32-freestanding 核心 ABI
├── root.zig               # Zig 模块导出
├── crypto/
│   ├── engine.zig         # 管线执行和 AI 解码
│   ├── base.zig           # Base16/32/58/64/85
│   ├── symmetric.zig      # AES-GCM、ChaCha20、XChaCha20
│   ├── openssl_compat.zig # OpenSSL/CryptoJS AES-256-CBC
│   ├── hash.zig           # SHA/MD5/BLAKE3/HMAC
│   ├── jsobfuscation.zig  # JS 编码与混淆格式
│   ├── brainfuck.zig      # Brainfuck VM 和编码器
│   ├── puzzle.zig         # 拆分/合并
│   └── random.zig         # Zig 0.16 随机源封装
├── generator/             # 模板、日期、随机值、词库、AI、实时值
├── storage/               # 本地 KV 数据库和历史记录
├── i18n/                  # zh / ja / en 文案
└── view/                  # HTML、CSS、浏览器端 JS
```

## 安全与部署说明

- 默认只绑定 `127.0.0.1`，如需局域网访问请显式传入 `--bind 0.0.0.0`。
- 服务端本身不提供 TLS，公网部署应放在 Nginx、Caddy 或其他反向代理后面。
- 历史记录会保存操作摘要和密文预览；处理敏感内容时可在 UI 中清空历史，或删除数据目录。
- AI API key 通过命令行或设置页提供。不要把带 key 的启动命令写入公开脚本。
- 哈希是单向步骤，不能用于解密管线恢复明文。

## 鸣谢

- [Ziglang](https://ziglang.org/)
- [Linux.do](https://linux.do/)

## 许可证

GNU Affero General Public License v3.0 (AGPL-3.0)。详见 [LICENSE](LICENSE)。
