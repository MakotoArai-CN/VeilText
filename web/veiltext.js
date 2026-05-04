// VeilText WASM JS bindings — vanilla ES module, zero dependencies.
//
// Exposes a high-level Promise-based API around veiltext-core.wasm.
//
// Quick start:
//   import { load } from './veiltext.js';
//   const vt = await load('./veiltext-core.wasm');
//   vt.encode('base64', 'Hello');               // 'SGVsbG8='
//   vt.decode('base64', 'SGVsbG8=');            // 'Hello'
//   vt.hash('sha256', 'abc');                   // hex digest
//   vt.encode('bf_emoji', 'Hi');                // emoji-BF blob
//   vt.decode('bf_emoji', '<emoji blob>');      // 'Hi'
//
// Browser:    <script type="module" src="veiltext.js"></script>
// Node 18+:   import { load } from './veiltext.js';   await load(...);
// Deno:       import { load } from './veiltext.js';   await load(...);
//
// AES/ChaCha/OpenSSL-CBC are NOT in the wasm ABI yet — use the HTTP API
// (POST /api/encrypt) for those, since they need key + RNG handling.

// ─── Algorithm registry ────────────────────────────────────────────
// Mirrors the table in src/wasm.zig.
export const ALGOS = Object.freeze({
  base16:               { id:  0, kind: 'codec' },
  base32:               { id:  1, kind: 'codec' },
  base58:               { id:  2, kind: 'codec' },
  base64:               { id:  3, kind: 'codec' },
  base85:               { id:  4, kind: 'codec' },
  sha256:               { id: 20, kind: 'hash'  },
  sha512:               { id: 21, kind: 'hash'  },
  blake3:               { id: 22, kind: 'hash'  },
  md5:                  { id: 23, kind: 'hash'  },
  js_hex_escape:        { id: 40, kind: 'codec' },
  js_unicode_escape:    { id: 41, kind: 'codec' },
  js_binary_string:     { id: 42, kind: 'codec' },
  js_jjencode:          { id: 43, kind: 'codec' },
  js_aaencode:          { id: 44, kind: 'codec' },
  js_jsfuck:            { id: 45, kind: 'codec' },
  js_eval_wrap:         { id: 46, kind: 'codec' },
  js_constructor_wrap:  { id: 47, kind: 'codec' },
  js_base36_tostring:   { id: 48, kind: 'codec' },
  bf_text:              { id: 60, kind: 'codec' },
  bf_emoji:             { id: 61, kind: 'codec' },
});

const MODE_ENCODE = 0;
const MODE_DECODE = 1;

// Error codes returned by veiltext_last_error()
const ERROR_MESSAGES = {
  0: 'ok',
  1: 'invalid input pointer',
  2: 'unknown algorithm id',
  3: 'invalid mode',
  4: 'transform failed (malformed input?)',
  5: 'out of memory',
};

export class VeilTextError extends Error {
  constructor(code, hint) {
    super(`VeilText[${code}]: ${ERROR_MESSAGES[code] || 'unknown'}${hint ? ' (' + hint + ')' : ''}`);
    this.name = 'VeilTextError';
    this.code = code;
  }
}

// ─── Loader ────────────────────────────────────────────────────────

/**
 * Load and instantiate the wasm module.
 *
 * @param {string|URL|Request|Response|BufferSource|Promise<Response>} source
 *        URL/path to .wasm, a fetch Response, or raw bytes.
 * @returns {Promise<VeilText>} bound API object.
 */
export async function load(source) {
  const bytes = await resolveBytes(source);
  const { instance } = await WebAssembly.instantiate(bytes, {});
  return new VeilText(instance);
}

async function resolveBytes(source) {
  // Already raw bytes
  if (source instanceof ArrayBuffer || ArrayBuffer.isView(source)) return source;

  // Promise<Response> | Response
  if (source && typeof source.then === 'function') source = await source;
  if (typeof Response !== 'undefined' && source instanceof Response) {
    return source.arrayBuffer();
  }

  // string / URL — fetch in browser, fs in Node/Deno
  if (typeof source === 'string' || source instanceof URL) {
    if (typeof fetch === 'function' && !looksLikeNodePath(source)) {
      const r = await fetch(source);
      if (!r.ok) throw new Error(`fetch ${source} -> ${r.status}`);
      return r.arrayBuffer();
    }
    // Node fallback
    const fs = await import('node:fs/promises');
    const buf = await fs.readFile(source instanceof URL ? source : String(source));
    return buf.buffer.slice(buf.byteOffset, buf.byteOffset + buf.byteLength);
  }

  throw new TypeError('load(): unsupported source — pass a URL, Response, or bytes');
}

function looksLikeNodePath(s) {
  if (typeof s !== 'string') return false;
  // Heuristic: if there is no scheme and we are in Node, treat as path.
  const isNode = typeof process !== 'undefined' && process.versions && process.versions.node;
  return isNode && !/^[a-z][a-z0-9+.-]*:/i.test(s);
}

// ─── Bound API ─────────────────────────────────────────────────────

export class VeilText {
  constructor(instance) {
    this._inst = instance;
    this._exp = instance.exports;
    this._mem = instance.exports.memory;
    this._enc = new TextEncoder();
    this._dec = new TextDecoder('utf-8', { fatal: false });

    // Sanity: ABI version must match what this binding was written against.
    const abi = this._exp.veiltext_wasm_abi_version();
    if (abi !== 1) {
      throw new Error(`VeilText wasm ABI v${abi} not supported by this binding (expects v1)`);
    }
  }

  /** Returns the algorithm id table baked into the wasm (debug aid). */
  supportedAlgorithms() {
    const ptr = this._exp.veiltext_supported_algorithms_ptr();
    const len = this._exp.veiltext_supported_algorithms_len();
    return this._dec.decode(new Uint8Array(this._mem.buffer, ptr, len));
  }

  /** Encode `input` with `algo`. Returns the encoded string. */
  encode(algo, input) {
    return this._call(algo, MODE_ENCODE, input, 'encode');
  }

  /** Decode `input` with `algo`. Returns the decoded string (UTF-8). */
  decode(algo, input) {
    return this._call(algo, MODE_DECODE, input, 'decode');
  }

  /**
   * Compute a one-way hash. `algo` must be sha256/sha512/blake3/md5.
   * Returns the lower-case hex digest.
   */
  hash(algo, input) {
    return this._call(algo, MODE_ENCODE, input, 'hash');
  }

  /** Decode bytes (Uint8Array) instead of UTF-8 — useful when output isn't text. */
  decodeBytes(algo, input) {
    return this._callBytes(algo, MODE_DECODE, input);
  }

  // ─── Internals ────────────────────────────────────────────────

  _resolveAlgo(algo, op) {
    if (typeof algo === 'number') return algo;
    const meta = ALGOS[algo];
    if (!meta) throw new TypeError(`unknown algorithm '${algo}'`);
    if (op === 'hash' && meta.kind !== 'hash') {
      throw new TypeError(`'${algo}' is not a hash algorithm`);
    }
    return meta.id;
  }

  _writeInput(input) {
    const bytes = typeof input === 'string'
      ? this._enc.encode(input)
      : input instanceof Uint8Array
        ? input
        : new Uint8Array(input);

    if (bytes.length === 0) {
      return { ptr: 0, len: 0 };
    }

    const ptr = this._exp.veiltext_alloc(bytes.length);
    if (ptr === 0) throw new VeilTextError(5, 'alloc failed for input');
    new Uint8Array(this._mem.buffer, ptr, bytes.length).set(bytes);
    return { ptr, len: bytes.length };
  }

  _call(algoName, mode, input, op) {
    const view = this._callBytes(algoName, mode, input, op);
    return this._dec.decode(view);
  }

  _callBytes(algoName, mode, input, op = 'transform') {
    const algoId = this._resolveAlgo(algoName, op);
    const { ptr, len } = this._writeInput(input);

    let outCopy;
    try {
      const ok = this._exp.veiltext_transform(algoId, mode, ptr, len);
      if (ok !== 1) {
        const code = this._exp.veiltext_last_error();
        throw new VeilTextError(code, `${op} ${algoName}`);
      }

      const outPtr = this._exp.veiltext_result_ptr();
      const outLen = this._exp.veiltext_result_len();
      // Copy out before clear_result frees the wasm-side buffer.
      outCopy = new Uint8Array(outLen);
      if (outLen > 0) {
        outCopy.set(new Uint8Array(this._mem.buffer, outPtr, outLen));
      }
    } finally {
      this._exp.veiltext_clear_result();
      if (len > 0) this._exp.veiltext_free(ptr, len);
    }

    return outCopy;
  }
}

// Convenience: default export is the loader.
export default load;
