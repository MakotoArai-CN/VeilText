# VeilText HTTP API Reference

All API responses are JSON. JSON request bodies should use:

```http
Content-Type: application/json
```

Typical error response:

```json
{
  "ok": false,
  "error": "message"
}
```

## Pipeline Steps

`/api/encrypt` and `/api/decrypt` use the same `pipeline` array. Each step needs a `type`; key-based algorithms may include `key`.

```json
[
  { "type": "base64" },
  { "type": "aes_256_gcm", "key": "secret" }
]
```

Supported `type` values:

```text
base16, base32, base58, base64, base85
aes_256_gcm, chacha20_poly1305, xchacha20_poly1305, aes_256_cbc
sha256, sha512, blake3, md5
js_hex_escape, js_unicode_escape, js_binary_string, js_jjencode, js_aaencode
js_jsfuck, js_eval_wrap, js_constructor_wrap, js_base36_tostring
bf_text, bf_emoji
```

Hash steps are one-way and cannot be reversed by `/api/decrypt`.

## POST `/api/encrypt`

Runs the pipeline in order.

```json
{
  "text": "hello world",
  "pipeline": [
    { "type": "base64" },
    { "type": "aes_256_gcm", "key": "secret" }
  ]
}
```

Response:

```json
{
  "ok": true,
  "ciphertext": "...",
  "pipeline_desc": "Base64 -> AES-256-GCM",
  "plaintext_hash": "..."
}
```

Symmetric encryption outputs are Base64-wrapped for text transport.

## POST `/api/decrypt`

Runs the provided pipeline in reverse order.

```json
{
  "text": "...",
  "pipeline": [
    { "type": "base64" },
    { "type": "aes_256_gcm", "key": "secret" }
  ],
  "expected_hash": "optional sha256 hex"
}
```

Response:

```json
{
  "ok": true,
  "plaintext": "hello world",
  "verified": null,
  "hash_match": null
}
```

If `expected_hash` is omitted, `verified` and `hash_match` are `null`; otherwise they are booleans.

## POST `/api/decode-smart`

Automatically detects and decodes layered text.

```json
{
  "text": "SGVsbG8",
  "key": "",
  "max_depth": 8,
  "pipeline": []
}
```

Response:

```json
{
  "ok": true,
  "plaintext": "Hello",
  "pipeline_desc": "AI decode: undo Base64",
  "attempts": 1,
  "still_encoded": false,
  "steps": ["Base64"]
}
```

`max_depth` defaults to 8 and is clamped to 1 through 12. `pipeline` is optional and is tried first when provided.

## Puzzle

### POST `/api/puzzle/split`

```json
{
  "text": "secret message",
  "pieces": 3
}
```

Response:

```json
{
  "ok": true,
  "pieces": ["...", "...", "..."]
}
```

### POST `/api/puzzle/merge`

```json
{
  "pieces": ["...", "...", "..."]
}
```

Response:

```json
{
  "ok": true,
  "text": "secret message"
}
```

## POST `/api/generate`

```json
{
  "template": "sk-{date:MMDD}-{word:tech}-{random:hex:8}"
}
```

Response:

```json
{
  "ok": true,
  "text": "sk-0501-kubernetes-a3f12c9b"
}
```

Template variables are documented in [TEMPLATES.md](TEMPLATES.md).

## History

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `/api/history` | List history records |
| DELETE | `/api/history` | Clear all history |
| DELETE | `/api/history/:id` | Delete one record |

## Template Data

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `/api/template-data` | Read word banks and template data |
| PUT | `/api/template-data` | Replace template data |
| DELETE | `/api/template-data` | Reset template data to defaults |

## Settings

### GET `/api/settings`

Returns basic UI settings:

```json
{
  "ok": true,
  "settings": {
    "theme": "auto",
    "language": "auto"
  }
}
```

### PUT `/api/settings`

Updates in-memory AI settings:

```json
{
  "ai_provider": "openai",
  "ai_endpoint": "https://api.openai.com/v1",
  "ai_key": "sk-...",
  "ai_model": "gpt-4o-mini"
}
```

## AI

### POST `/api/ai/test`

Tests AI connectivity with the provided provider, endpoint, key, and model.

### POST `/api/ai/chat`

AI assistant endpoint. The model can call built-in tools; the server performs up to 4 tool rounds.

```json
{
  "message": "base64 encode hello",
  "provider": "openai",
  "endpoint": "https://api.openai.com/v1",
  "key": "sk-...",
  "model": "gpt-4o-mini"
}
```

Response:

```json
{
  "ok": true,
  "reply": "...",
  "actions": []
}
```

Available tools:

```text
encrypt, decrypt, generate, puzzle_split, puzzle_merge, web_search, get_time, system_info
```
