# VeilText Template Variables Reference

Templates are strings with `{variable}` placeholders. Use them in the **Generate** page to produce dynamic text for passwords, keys, and custom patterns.

---

## Date & Time

| Variable | Example Output | Description |
|---|---|---|
| `{date}` | `2026-04-16` | Today's date in ISO format (YYYY-MM-DD) |
| `{date:MMDD}` | `0416` | Month and day only |
| `{date:compact}` | `20260416` | Compact date without separators |
| `{date:YYYY}` | `2026` | Year only |
| `{date:HHmm}` | `1423` | Current time as HHmm (24-hour) |

---

## Random Values

| Variable | Example Output | Description |
|---|---|---|
| `{random:N}` | `8294` | N random decimal digits (0–9) |
| `{random:hex:N}` | `a3f12c9b` | N random lowercase hex characters (0–9, a–f) |
| `{random:alnum:N}` | `k7x2m9q1` | N random alphanumeric characters (a–z, 0–9) |
| `{random:lower:N}` | `kjxmqpzr` | N random lowercase letters (a–z) |
| `{random:upper:N}` | `KJXMQPZR` | N random uppercase letters (A–Z) |

Replace `N` with a number, e.g. `{random:6}` gives 6 decimal digits.

---

## Identifiers

| Variable | Example Output | Description |
|---|---|---|
| `{uuid}` | `f47ac10b-58cc-4372-a567-0e02b2c3d479` | UUID v4 — universally unique identifier |

---

## Word Banks

| Variable | Example Output | Description |
|---|---|---|
| `{word:tech}` | `kubernetes` | Random tech industry term |
| `{word:games}` | `respawn` | Random gaming term |
| `{word:finance}` | `arbitrage` | Random finance/trading term |
| `{word:general}` | `serenity` | Random general English word |

---

## Game Data (Genshin Impact)

| Variable | Example Output | Description |
|---|---|---|
| `{game:genshin:character}` | `furina` | Random Genshin Impact character name |
| `{game:genshin:birthday:NAME}` | `1213` | Birthday of the named character (MMDD) |

For birthday lookups, replace `NAME` with the character's internal name in lowercase with no spaces, e.g.:

- `{game:genshin:birthday:funingna}` → Furina's birthday
- `{game:genshin:birthday:hutao}` → Hu Tao's birthday
- `{game:genshin:birthday:zhongli}` → Zhongli's birthday

---

## Special

| Variable | Example Output | Description |
|---|---|---|
| `{literal:TEXT}` | `TEXT` | Output TEXT verbatim, no processing |

---

## Custom Variables (Chips)

You can define your own named variables on the Generate page using the **+ Add** button. Each chip maps a label to a template expression. For example:

- Label: `my-key`, Value: `sk-{date:MMDD}{random:hex:6}`

Click any chip to insert its template value at the cursor position.

---

## Template Examples

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

## Editable Built-in Data

You can now edit the server-side built-in template data in **Settings -> Built-in Template Data**.

- Word banks use one item per line.
- Genshin birthdays use `name=MMDD`.
- **Save** applies the changes to future generations.
- **Reset** restores the built-in defaults.

### Default Games Word Bank

`yuanshen`, `genshin`, `funingna`, `funina`, `naxida`, `nahida`, `zhongli`, `wendi`, `venti`, `leishen`, `raiden`, `ganyu`, `hutao`, `keqing`, `xiao`, `ayaka`, `yoimiya`, `yelan`, `alhaitham`, `wanderer`, `nilou`, `shenhe`, `yae`, `kokomi`, `eula`, `kazuha`, `tighnari`, `cyno`, `dehya`, `baizhu`, `lyney`, `lynette`, `freminet`, `neuvillette`, `wriothesley`, `navia`, `chiori`, `arlecchino`, `clorinde`, `sigewinne`, `emilie`, `mualani`, `kinich`, `xilonen`, `chasca`, `mavuika`, `teyvat`, `mondstadt`, `liyue`, `inazuma`, `sumeru`, `fontaine`, `natlan`, `snezhnaya`, `celestia`, `primogem`, `mora`, `resin`, `archon`, `vision`, `gnosis`, `abyss`

### Default Tech Word Bank

`kubernetes`, `docker`, `terraform`, `ansible`, `prometheus`, `grafana`, `jenkins`, `gitlab`, `nginx`, `redis`, `postgres`, `mongodb`, `elasticsearch`, `kafka`, `rabbitmq`, `consul`, `vault`, `istio`, `envoy`, `grpc`, `graphql`, `restapi`, `websocket`, `oauth`, `jwt`, `ssl`, `tls`, `https`, `cicd`, `devops`, `sre`, `mlops`, `microservice`, `serverless`, `lambda`, `cloudflare`, `wasm`, `rust`, `golang`, `typescript`, `python`, `swift`, `kotlin`, `zig`

### Default Finance Word Bank

`bitcoin`, `ethereum`, `solana`, `defi`, `nft`, `dao`, `staking`, `yield`, `liquidity`, `swap`, `bridge`, `oracle`, `bullish`, `bearish`, `hodl`, `whale`, `altcoin`, `mainnet`, `testnet`, `airdrop`, `ipo`, `nasdaq`, `sp500`, `dowjones`, `forex`, `commodity`, `futures`, `options`, `dividend`, `portfolio`, `hedge`, `arbitrage`, `inflation`, `deflation`, `gdp`, `cpi`, `fed`, `ecb`, `pboc`, `boj`

### Default General Word Bank

`alpha`, `bravo`, `charlie`, `delta`, `echo`, `foxtrot`, `golf`, `hotel`, `india`, `juliet`, `kilo`, `lima`, `mike`, `november`, `oscar`, `papa`, `quebec`, `romeo`, `sierra`, `tango`, `uniform`, `victor`, `whiskey`, `xray`, `yankee`, `zulu`, `phoenix`, `dragon`, `storm`, `shadow`, `cipher`, `quantum`, `nebula`, `aurora`, `zenith`, `vortex`, `prism`, `apex`, `nova`, `pulse`

### Default Genshin Characters

`funingna`, `funina`, `naxida`, `nahida`, `zhongli`, `wendi`, `venti`, `leishen`, `raiden`, `ganyu`, `hutao`, `keqing`, `xiao`, `ayaka`, `yoimiya`, `yelan`, `alhaitham`, `wanderer`, `nilou`, `shenhe`, `yae`, `kokomi`, `eula`, `kazuha`, `tighnari`, `cyno`, `dehya`, `baizhu`, `lyney`, `lynette`, `freminet`, `neuvillette`, `wriothesley`, `navia`, `chiori`, `arlecchino`, `clorinde`, `sigewinne`, `emilie`, `mualani`, `kinich`, `xilonen`, `chasca`, `mavuika`

### Default Genshin Birthdays

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
