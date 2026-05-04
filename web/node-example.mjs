// Node 18+ / Deno usage example.
// Run: node web/node-example.mjs zig-out/bin/Wasm/veiltext-core.wasm
import { load, ALGOS } from './veiltext.js';

const wasmPath = process.argv[2] ?? new URL('../zig-out/bin/Wasm/veiltext-core.wasm', import.meta.url);
const vt = await load(wasmPath);

console.log('algorithms loaded:', Object.keys(ALGOS).length);

const sample = 'Hello, VeilText!';
console.log('input :', JSON.stringify(sample));
console.log('base64:', vt.encode('base64', sample));
console.log('sha256:', vt.hash('sha256', sample));

const bf = vt.encode('bf_emoji', 'Hi');
console.log('bf_emoji:', bf);
console.log('  -> back:', vt.decode('bf_emoji', bf));

// Roundtrip every codec.
const failures = [];
for (const [name, meta] of Object.entries(ALGOS)) {
  if (meta.kind !== 'codec') continue;
  try {
    const enc = vt.encode(name, sample);
    const dec = vt.decode(name, enc);
    if (dec !== sample) failures.push(`${name}: roundtrip mismatch`);
  } catch (e) {
    failures.push(`${name}: ${e.message}`);
  }
}

if (failures.length === 0) console.log('roundtrip: all codec algorithms OK');
else console.error('roundtrip failures:\n  ' + failures.join('\n  '));
