# VeilText WASM 文档

VeilText 的 wasm 产物是一个 `wasm32-freestanding` 核心模块，面向浏览器、Node.js 或其他 WebAssembly 宿主环境。它只包含纯计算能力，不包含 HTTP 服务器、文件存储、线程、AI 网络请求或本地历史记录。

## 构建

```powershell
zig build wasm --release=small
```

产物：

```text
zig-out/bin/Wasm/veiltext-core.wasm
```

`zig build dist --release=fast` 和 `zig build dist --release=small` 也会生成该 wasm 文件。

## 导出函数

```text
veiltext_wasm_abi_version() -> u32
veiltext_supported_algorithms_ptr() -> usize
veiltext_supported_algorithms_len() -> usize
veiltext_alloc(len: usize) -> usize
veiltext_free(ptr: usize, len: usize) -> void
veiltext_transform(algorithm: u32, mode: u32, ptr: usize, len: usize) -> u32
veiltext_result_ptr() -> usize
veiltext_result_len() -> usize
veiltext_last_error() -> u32
veiltext_clear_result() -> void
```

调用约定：

- 宿主通过 `veiltext_alloc` 在 wasm 内存中分配输入缓冲。
- 将 UTF-8 字节写入 `memory.buffer`。
- 调用 `veiltext_transform`。
- 返回 `1` 表示成功，返回 `0` 表示失败。
- 成功后用 `veiltext_result_ptr` 和 `veiltext_result_len` 读取结果。
- 读取完必须调用 `veiltext_clear_result`。
- 输入缓冲由宿主调用 `veiltext_free(ptr, len)` 释放。

## mode

| mode | 含义 |
| --- | --- |
| `0` | encode |
| `1` | decode |

哈希算法忽略 `mode`，始终输出 hex 摘要。

## 算法编号

可通过 `veiltext_supported_algorithms_ptr/len` 读取 wasm 内置文本表，也可以直接使用以下编号。

| 编号 | 算法 |
| --- | --- |
| `0` | base16 |
| `1` | base32 |
| `2` | base58 |
| `3` | base64 |
| `4` | base85 |
| `20` | sha256 |
| `21` | sha512 |
| `22` | blake3 |
| `23` | md5 |
| `40` | js_hex_escape |
| `41` | js_unicode_escape |
| `42` | js_binary_string |
| `43` | js_jjencode |
| `44` | js_aaencode |
| `45` | js_jsfuck |
| `46` | js_eval_wrap |
| `47` | js_constructor_wrap |
| `48` | js_base36_tostring |
| `60` | bf_text |
| `61` | bf_emoji |

wasm 当前不导出 AES/ChaCha/OpenSSL CBC。原因是这些算法需要更明确的密钥输入 ABI，并且通常还需要随机 nonce/salt。原生 HTTP API 已完整支持这些算法。

## 错误码

| 错误码 | 含义 |
| --- | --- |
| `0` | 无错误或未设置 |
| `1` | 输入指针/长度无效 |
| `2` | 未知算法编号 |
| `3` | mode 无效 |
| `4` | 转换失败，例如输入格式无效 |
| `5` | 内存不足 |

## Node.js 示例

```js
const fs = require("fs");

const wasm = fs.readFileSync("zig-out/bin/Wasm/veiltext-core.wasm");
const { instance } = await WebAssembly.instantiate(wasm, {});
const e = instance.exports;

const encoder = new TextEncoder();
const decoder = new TextDecoder();

function transform(algorithm, mode, text) {
  const input = encoder.encode(text);
  const ptr = e.veiltext_alloc(input.length);
  if (!ptr) throw new Error("alloc failed");

  new Uint8Array(e.memory.buffer, ptr, input.length).set(input);

  const ok = e.veiltext_transform(algorithm, mode, ptr, input.length);
  e.veiltext_free(ptr, input.length);

  if (!ok) {
    throw new Error(`veiltext error ${e.veiltext_last_error()}`);
  }

  const out = decoder.decode(
    new Uint8Array(e.memory.buffer, e.veiltext_result_ptr(), e.veiltext_result_len()),
  );
  e.veiltext_clear_result();
  return out;
}

console.log(transform(3, 0, "Hello"));   // SGVsbG8=
console.log(transform(3, 1, "SGVsbG8")); // Hello
```

## 浏览器加载提示

浏览器中可以使用：

```js
const response = await fetch("/veiltext-core.wasm");
const { instance } = await WebAssembly.instantiateStreaming(response, {});
```

如果服务器没有返回正确的 `application/wasm` MIME 类型，可改用：

```js
const bytes = await (await fetch("/veiltext-core.wasm")).arrayBuffer();
const { instance } = await WebAssembly.instantiate(bytes, {});
```
