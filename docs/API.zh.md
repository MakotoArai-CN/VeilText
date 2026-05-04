# VeilText HTTP API 参考

所有 API 都返回 JSON。请求体为 JSON 的接口应发送：

```http
Content-Type: application/json
```

错误响应通常为：

```json
{
  "ok": false,
  "error": "message"
}
```

## 管线步骤

加密和解密 API 使用同一种 `pipeline` 数组。每个步骤至少包含 `type`，需要密钥的算法可额外传 `key`。

```json
[
  { "type": "base64" },
  { "type": "aes_256_gcm", "key": "secret" }
]
```

支持的 `type`：

```text
base16
base32
base58
base64
base85
aes_256_gcm
chacha20_poly1305
xchacha20_poly1305
aes_256_cbc
sha256
sha512
blake3
md5
js_hex_escape
js_unicode_escape
js_binary_string
js_jjencode
js_aaencode
js_jsfuck
js_eval_wrap
js_constructor_wrap
js_base36_tostring
bf_text
bf_emoji
```

哈希步骤不可逆，不能用于 `/api/decrypt` 恢复明文。

## POST `/api/encrypt`

按顺序执行管线。

请求：

```json
{
  "text": "hello world",
  "pipeline": [
    { "type": "base64" },
    { "type": "aes_256_gcm", "key": "secret" }
  ]
}
```

响应：

```json
{
  "ok": true,
  "ciphertext": "...",
  "pipeline_desc": "Base64 -> AES-256-GCM",
  "plaintext_hash": "..."
}
```

说明：

- 对称加密输出会自动再做 Base64，便于文本传输。
- `plaintext_hash` 是明文 SHA-256，可在解密时作为 `expected_hash` 校验。

## POST `/api/decrypt`

按逆序执行管线。

请求：

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

响应：

```json
{
  "ok": true,
  "plaintext": "hello world",
  "verified": null,
  "hash_match": null
}
```

说明：

- `pipeline` 仍按加密时的顺序传入，服务端会自动逆序执行。
- 没有传 `expected_hash` 时，`verified` 和 `hash_match` 都是 `null`。
- 传入 `expected_hash` 时，二者为 `true` 或 `false`。

## POST `/api/decode-smart`

根据密文特征自动尝试多层解码。适合 Base64、Base16、JS escape、Brainfuck、OpenSSL/CryptoJS CBC 等嵌套文本。

请求：

```json
{
  "text": "SGVsbG8",
  "key": "",
  "max_depth": 8,
  "pipeline": []
}
```

响应：

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

字段：

- `key` 用于尝试需要密钥的对称算法，可为空。
- `max_depth` 默认 8，服务端限制为 1 到 12。
- `pipeline` 可选，传入后会优先按这些步骤逆向尝试。
- `still_encoded` 表示输出是否仍疑似编码/密文。

## POST `/api/puzzle/split`

把文本拆成多个 Base64 碎片。

请求：

```json
{
  "text": "secret message",
  "pieces": 3
}
```

响应：

```json
{
  "ok": true,
  "pieces": ["...", "...", "..."]
}
```

`pieces` 最少为 2。

## POST `/api/puzzle/merge`

合并 Puzzle 碎片。

请求：

```json
{
  "pieces": ["...", "...", "..."]
}
```

响应：

```json
{
  "ok": true,
  "text": "secret message"
}
```

## POST `/api/generate`

按模板生成文本。

请求：

```json
{
  "template": "sk-{date:MMDD}-{word:tech}-{random:hex:8}"
}
```

响应：

```json
{
  "ok": true,
  "text": "sk-0501-kubernetes-a3f12c9b"
}
```

模板变量见 [TEMPLATES.zh.md](TEMPLATES.zh.md)。

## 历史记录

### GET `/api/history`

响应：

```json
{
  "ok": true,
  "records": [
    {
      "id": "...",
      "operation": "encrypt",
      "pipeline_desc": "Base64",
      "timestamp": "...",
      "ciphertext_preview": "..."
    }
  ]
}
```

### DELETE `/api/history/:id`

删除单条记录：

```json
{ "ok": true }
```

### DELETE `/api/history`

清空历史：

```json
{ "ok": true }
```

## 模板数据

### GET `/api/template-data`

返回当前词库、原神角色生日和自定义词库数据。

```json
{
  "ok": true,
  "data": {
    "games_words": [],
    "tech_words": [],
    "finance_words": [],
    "general_words": [],
    "genshin_characters": [],
    "genshin_birthdays": [],
    "custom_banks": {}
  }
}
```

### PUT `/api/template-data`

请求体直接使用上面的 `data` 对象结构。成功返回：

```json
{ "ok": true }
```

### DELETE `/api/template-data`

重置为内置默认数据：

```json
{ "ok": true }
```

## 设置

### GET `/api/settings`

当前只返回基础 UI 设置：

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

更新服务端内存中的 AI 配置：

```json
{
  "ai_provider": "openai",
  "ai_endpoint": "https://api.openai.com/v1",
  "ai_key": "sk-...",
  "ai_model": "gpt-4o-mini"
}
```

响应：

```json
{ "ok": true }
```

## AI

### POST `/api/ai/test`

使用给定配置测试 AI 连接。

请求：

```json
{
  "provider": "openai",
  "endpoint": "https://api.openai.com/v1",
  "key": "sk-...",
  "model": "gpt-4o-mini"
}
```

### POST `/api/ai/chat`

AI 助手接口。AI 可以返回自然语言，也可以请求调用内置工具。服务端最多进行 4 轮工具调用。

请求：

```json
{
  "message": "把 hello 做 base64",
  "provider": "openai",
  "endpoint": "https://api.openai.com/v1",
  "key": "sk-...",
  "model": "gpt-4o-mini",
  "system_prompt": "optional"
}
```

响应：

```json
{
  "ok": true,
  "reply": "...",
  "actions": [
    {
      "type": "fill_encrypt",
      "text": "hello",
      "algorithm": "base64",
      "key": "",
      "result": "aGVsbG8="
    }
  ]
}
```

AI 工具支持：

```text
encrypt
decrypt
generate
puzzle_split
puzzle_merge
web_search
get_time
system_info
```
