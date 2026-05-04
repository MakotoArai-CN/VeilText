// Type definitions for veiltext.js (WASM bindings)

export type AlgoKind = 'codec' | 'hash';

export type AlgoName =
  | 'base16' | 'base32' | 'base58' | 'base64' | 'base85'
  | 'sha256' | 'sha512' | 'blake3' | 'md5'
  | 'js_hex_escape' | 'js_unicode_escape' | 'js_binary_string'
  | 'js_jjencode' | 'js_aaencode' | 'js_jsfuck'
  | 'js_eval_wrap' | 'js_constructor_wrap' | 'js_base36_tostring'
  | 'bf_text' | 'bf_emoji';

export interface AlgoMeta {
  id: number;
  kind: AlgoKind;
}

export const ALGOS: Readonly<Record<AlgoName, AlgoMeta>>;

export class VeilTextError extends Error {
  readonly code: number;
}

export type LoadSource =
  | string
  | URL
  | Request
  | Response
  | Promise<Response>
  | ArrayBuffer
  | ArrayBufferView;

export function load(source: LoadSource): Promise<VeilText>;
export default load;

export class VeilText {
  supportedAlgorithms(): string;
  encode(algo: AlgoName | number, input: string | ArrayBufferView | ArrayBuffer): string;
  decode(algo: AlgoName | number, input: string | ArrayBufferView | ArrayBuffer): string;
  decodeBytes(algo: AlgoName | number, input: string | ArrayBufferView | ArrayBuffer): Uint8Array;
  hash(algo: 'sha256' | 'sha512' | 'blake3' | 'md5' | number,
       input: string | ArrayBufferView | ArrayBuffer): string;
}
