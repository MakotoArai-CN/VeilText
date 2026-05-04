# VeilText WASM Reference

`veiltext-core.wasm` is a `wasm32-freestanding` compute module for browsers, Node.js, and other WebAssembly hosts. It does not include the HTTP server, local storage, threading, AI network calls, or history.

## Build

```bash
zig build wasm --release=small
```

Output:

```text
zig-out/bin/Wasm/veiltext-core.wasm
```

`zig build dist --release=fast` and `zig build dist --release=small` also include the wasm module.

## Exports

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

Call flow:

1. Allocate input with `veiltext_alloc`.
2. Write UTF-8 bytes into `memory.buffer`.
3. Call `veiltext_transform`.
4. Read output from `veiltext_result_ptr` and `veiltext_result_len`.
5. Call `veiltext_clear_result`.
6. Free the input buffer with `veiltext_free`.

`veiltext_transform` returns `1` on success and `0` on failure.

## Modes

| mode | Meaning |
| --- | --- |
| `0` | encode |
| `1` | decode |

Hash algorithms ignore mode and always return hex digests.

## Algorithm IDs

| ID | Algorithm |
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

AES/ChaCha/OpenSSL CBC are intentionally not exported in the current wasm ABI because they need a key-aware ABI and random nonce/salt handling. The native HTTP API supports them.

## Error Codes

| Code | Meaning |
| --- | --- |
| `0` | no error / unset |
| `1` | invalid input pointer or length |
| `2` | unknown algorithm |
| `3` | invalid mode |
| `4` | transform failed |
| `5` | out of memory |

## Node.js Example

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

  if (!ok) throw new Error(`veiltext error ${e.veiltext_last_error()}`);

  const out = decoder.decode(
    new Uint8Array(e.memory.buffer, e.veiltext_result_ptr(), e.veiltext_result_len()),
  );
  e.veiltext_clear_result();
  return out;
}

console.log(transform(3, 0, "Hello"));   // SGVsbG8=
console.log(transform(3, 1, "SGVsbG8")); // Hello
```
