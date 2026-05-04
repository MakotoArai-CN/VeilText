# VeilText 模板变量参考

模板是包含 `{变量}` 占位符的字符串。在**明文生成**页面使用模板，可动态生成密码、密钥和自定义格式的文本。

---

## 日期与时间

| 变量 | 示例输出 | 说明 |
|---|---|---|
| `{date}` | `2026-04-16` | 今天的日期，ISO 格式（YYYY-MM-DD） |
| `{date:MMDD}` | `0416` | 仅月份和日期 |
| `{date:compact}` | `20260416` | 无分隔符的紧凑日期 |
| `{date:YYYY}` | `2026` | 仅年份 |
| `{date:HHmm}` | `1423` | 当前时间，HHmm 格式（24小时制） |

---

## 随机值

| 变量 | 示例输出 | 说明 |
|---|---|---|
| `{random:N}` | `8294` | N 位随机十进制数字（0–9） |
| `{random:hex:N}` | `a3f12c9b` | N 位随机小写十六进制字符（0–9, a–f） |
| `{random:alnum:N}` | `k7x2m9q1` | N 位随机字母数字混合字符（a–z, 0–9） |
| `{random:lower:N}` | `kjxmqpzr` | N 位随机小写字母（a–z） |
| `{random:upper:N}` | `KJXMQPZR` | N 位随机大写字母（A–Z） |

将 `N` 替换为数字，例如 `{random:6}` 生成 6 位十进制数字。

---

## 标识符

| 变量 | 示例输出 | 说明 |
|---|---|---|
| `{uuid}` | `f47ac10b-58cc-4372-a567-0e02b2c3d479` | UUID v4 — 全局唯一标识符 |

---

## 词库

| 变量 | 示例输出 | 说明 |
|---|---|---|
| `{word:tech}` | `kubernetes` | 随机科技行业词汇 |
| `{word:games}` | `respawn` | 随机游戏词汇 |
| `{word:finance}` | `arbitrage` | 随机金融/交易词汇 |
| `{word:general}` | `serenity` | 随机通用英语单词 |

---

## 游戏数据（原神）

| 变量 | 示例输出 | 说明 |
|---|---|---|
| `{game:genshin:character}` | `furina` | 随机原神角色名称 |
| `{game:genshin:birthday:NAME}` | `1213` | 指定角色的生日（MMDD格式） |

生日查询中，将 `NAME` 替换为角色的英文内部名称（小写，无空格），例如：

- `{game:genshin:birthday:funingna}` → 芙宁娜的生日
- `{game:genshin:birthday:hutao}` → 胡桃的生日
- `{game:genshin:birthday:zhongli}` → 钟离的生日

---

## 特殊

| 变量 | 示例输出 | 说明 |
|---|---|---|
| `{literal:文本}` | `文本` | 原样输出文本，不做任何处理 |

---

## 自定义变量（模板芯片）

在**明文生成**页面点击 **+ 添加** 按钮，可以定义自己的命名变量。每个芯片将标签名映射到模板表达式。例如：

- 标签：`my-key`，值：`sk-{date:MMDD}{random:hex:6}`

点击任意芯片可将其模板值插入到光标位置。

---

## 模板示例

```
sk-{date:MMDD}-{random:6}
```

→ `sk-0416-827493`

```
{uuid}_{word:tech}
```

→ `f47ac10b-58cc-4372-a567-0e02b2c3d479_kubernetes`

```
{game:genshin:character}-{date:compact}-{random:4}
```

→ `furina-20260416-7291`

```
{random:upper:3}-{random:4}-{random:lower:3}
```

→ `XKP-8273-mzq`

---

## 可编辑的内置数据

现在可以在 **设置 -> 内置模板数据** 中直接编辑服务端实际使用的内置模板值。

- 词库：每行一个值
- 原神生日：使用 `name=MMDD`
- 点击 **保存** 后，后续生成立即使用新值
- 点击 **重置** 可恢复默认值

### 默认游戏词库

`yuanshen`, `genshin`, `funingna`, `funina`, `naxida`, `nahida`, `zhongli`, `wendi`, `venti`, `leishen`, `raiden`, `ganyu`, `hutao`, `keqing`, `xiao`, `ayaka`, `yoimiya`, `yelan`, `alhaitham`, `wanderer`, `nilou`, `shenhe`, `yae`, `kokomi`, `eula`, `kazuha`, `tighnari`, `cyno`, `dehya`, `baizhu`, `lyney`, `lynette`, `freminet`, `neuvillette`, `wriothesley`, `navia`, `chiori`, `arlecchino`, `clorinde`, `sigewinne`, `emilie`, `mualani`, `kinich`, `xilonen`, `chasca`, `mavuika`, `teyvat`, `mondstadt`, `liyue`, `inazuma`, `sumeru`, `fontaine`, `natlan`, `snezhnaya`, `celestia`, `primogem`, `mora`, `resin`, `archon`, `vision`, `gnosis`, `abyss`

### 默认技术词库

`kubernetes`, `docker`, `terraform`, `ansible`, `prometheus`, `grafana`, `jenkins`, `gitlab`, `nginx`, `redis`, `postgres`, `mongodb`, `elasticsearch`, `kafka`, `rabbitmq`, `consul`, `vault`, `istio`, `envoy`, `grpc`, `graphql`, `restapi`, `websocket`, `oauth`, `jwt`, `ssl`, `tls`, `https`, `cicd`, `devops`, `sre`, `mlops`, `microservice`, `serverless`, `lambda`, `cloudflare`, `wasm`, `rust`, `golang`, `typescript`, `python`, `swift`, `kotlin`, `zig`

### 默认金融词库

`bitcoin`, `ethereum`, `solana`, `defi`, `nft`, `dao`, `staking`, `yield`, `liquidity`, `swap`, `bridge`, `oracle`, `bullish`, `bearish`, `hodl`, `whale`, `altcoin`, `mainnet`, `testnet`, `airdrop`, `ipo`, `nasdaq`, `sp500`, `dowjones`, `forex`, `commodity`, `futures`, `options`, `dividend`, `portfolio`, `hedge`, `arbitrage`, `inflation`, `deflation`, `gdp`, `cpi`, `fed`, `ecb`, `pboc`, `boj`

### 默认通用词库

`alpha`, `bravo`, `charlie`, `delta`, `echo`, `foxtrot`, `golf`, `hotel`, `india`, `juliet`, `kilo`, `lima`, `mike`, `november`, `oscar`, `papa`, `quebec`, `romeo`, `sierra`, `tango`, `uniform`, `victor`, `whiskey`, `xray`, `yankee`, `zulu`, `phoenix`, `dragon`, `storm`, `shadow`, `cipher`, `quantum`, `nebula`, `aurora`, `zenith`, `vortex`, `prism`, `apex`, `nova`, `pulse`

### 默认原神角色列表

`funingna`, `funina`, `naxida`, `nahida`, `zhongli`, `wendi`, `venti`, `leishen`, `raiden`, `ganyu`, `hutao`, `keqing`, `xiao`, `ayaka`, `yoimiya`, `yelan`, `alhaitham`, `wanderer`, `nilou`, `shenhe`, `yae`, `kokomi`, `eula`, `kazuha`, `tighnari`, `cyno`, `dehya`, `baizhu`, `lyney`, `lynette`, `freminet`, `neuvillette`, `wriothesley`, `navia`, `chiori`, `arlecchino`, `clorinde`, `sigewinne`, `emilie`, `mualani`, `kinich`, `xilonen`, `chasca`, `mavuika`

### 默认原神生日

- `funingna=1013`
- `funina=1013`
- `zhongli=1231`
- `wendi=0616`
- `venti=0616`
- `ganyu=1202`
- `hutao=0715`
- `keqing=1120`
- `xiao=0417`
- `ayaka=0928`
- `yoimiya=0621`
- `raiden=0626`
- `nahida=1027`
- `naxida=1027`
- `yelan=0420`
- `kazuha=1029`
- `eula=1025`
- `shenhe=0310`
- `kokomi=0222`
- `yae=0627`
- `nilou=1203`
- `alhaitham=0211`
- `neuvillette=1218`
- `wriothesley=1109`
- `navia=0816`
- `arlecchino=0422`
- `clorinde=0910`
- `mavuika=0114`
