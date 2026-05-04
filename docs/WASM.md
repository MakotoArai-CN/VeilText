# VeilText WASM Reference

`veiltext-core.wasm` is a `wasm32-freestanding` compute module for browsers, Node.js, and other WebAssembly hosts. It does not include the HTTP server, local storage, threading, AI network calls, or history.

## Build

```bash
zig build wasm --release=small
```

Output:

```text
zig-out/bin/Wasm/
├── veiltext-core.wasm    ← compute core
├── veiltext.js           ← high-level ES-module bindings
├── veiltext.d.ts         ← TypeScript types
├── index.html            ← live playground (open it in a browser)
└── node-example.mjs      ← Node 18+ / Deno / Bun example
```

`zig build dist --release=fast` and `zig build dist --release=small` also include the wasm bundle.

## Quick Start (high-level — recommended)

The shipped `veiltext.js` wraps the raw ABI behind a small ergonomic class.
Zero dependencies, ~5 KB, works in browsers, Node 18+, Deno, and Bun.

### Browser

```html
<script type="module">
  import { load } from './veiltext.js';
  const vt = await load('./veiltext-core.wasm');

  vt.encode('base64', 'Hello');           // 'SGVsbG8='
  vt.decode('base64', 'SGVsbG8=');        // 'Hello'
  vt.hash('sha256', 'abc');               // 'ba7816bf...'
  vt.encode('bf_emoji', 'Hi');            // emoji-Brainfuck
</script>
```

Or just open `zig-out/bin/Wasm/index.html` in a browser — it's a complete playground.

### Node.js / Deno / Bun

```js
import { load } from './veiltext.js';
const vt = await load('./veiltext-core.wasm');
console.log(vt.encode('base64', 'Hello'));
```

Run the bundled example:

```bash
node web/node-example.mjs                     # uses zig-out/bin/Wasm/...wasm
node web/node-example.mjs path/to/core.wasm   # explicit path
bun  web/node-example.mjs                     # also works
```

### High-level API surface

```ts
class VeilText {
  encode(algo: AlgoName, input: string | Uint8Array): string;
  decode(algo: AlgoName, input: string | Uint8Array): string;
  decodeBytes(algo: AlgoName, input: string | Uint8Array): Uint8Array;
  hash(algo: 'sha256' | 'sha512' | 'blake3' | 'md5',
       input: string | Uint8Array): string;
  supportedAlgorithms(): string;
}

// AlgoName: 'base16' | 'base32' | 'base58' | 'base64' | 'base85'
//         | 'sha256' | 'sha512' | 'blake3' | 'md5'
//         | 'js_hex_escape' | 'js_unicode_escape' | 'js_binary_string'
//         | 'js_jjencode' | 'js_aaencode' | 'js_jsfuck'
//         | 'js_eval_wrap' | 'js_constructor_wrap' | 'js_base36_tostring'
//         | 'bf_text' | 'bf_emoji'
```

Errors throw `VeilTextError` with a numeric `.code` matching the table below.

## Low-level ABI

If you don't want to use the JS bindings, here's the raw export surface.

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

## Manual ABI Example (no bindings)

For environments where you don't want the JS wrapper:

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
