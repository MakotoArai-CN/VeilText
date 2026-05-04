# VeilText テンプレート変数リファレンス

テンプレートは `{変数}` プレースホルダーを含む文字列です。**明文生成**ページでテンプレートを使用することで、パスワードや鍵、カスタムパターンのテキストを動的に生成できます。

---

## 日付と時刻

| 変数 | 出力例 | 説明 |
|---|---|---|
| `{date}` | `2026-04-16` | 今日の日付（ISO形式: YYYY-MM-DD） |
| `{date:MMDD}` | `0416` | 月と日のみ |
| `{date:compact}` | `20260416` | 区切り文字なしのコンパクト日付 |
| `{date:YYYY}` | `2026` | 年のみ |
| `{date:HHmm}` | `1423` | 現在時刻（24時間制のHHmm形式） |

---

## ランダム値

| 変数 | 出力例 | 説明 |
|---|---|---|
| `{random:N}` | `8294` | N桁のランダムな十進数（0〜9） |
| `{random:hex:N}` | `a3f12c9b` | N文字のランダムな小文字16進数（0〜9, a〜f） |
| `{random:alnum:N}` | `k7x2m9q1` | N文字のランダムな英数字（a〜z, 0〜9） |
| `{random:lower:N}` | `kjxmqpzr` | N文字のランダムな小文字（a〜z） |
| `{random:upper:N}` | `KJXMQPZR` | N文字のランダムな大文字（A〜Z） |

`N` を数字に置き換えてください。例: `{random:6}` → 6桁の十進数。

---

## 識別子

| 変数 | 出力例 | 説明 |
|---|---|---|
| `{uuid}` | `f47ac10b-58cc-4372-a567-0e02b2c3d479` | UUID v4 — 汎用一意識別子 |

---

## ワードバンク

| 変数 | 出力例 | 説明 |
|---|---|---|
| `{word:tech}` | `kubernetes` | ランダムなテック用語 |
| `{word:games}` | `respawn` | ランダムなゲーム用語 |
| `{word:finance}` | `arbitrage` | ランダムな金融/取引用語 |
| `{word:general}` | `serenity` | ランダムな一般英単語 |

---

## ゲームデータ（原神）

| 変数 | 出力例 | 説明 |
|---|---|---|
| `{game:genshin:character}` | `furina` | ランダムな原神キャラクター名 |
| `{game:genshin:birthday:NAME}` | `1213` | 指定キャラクターの誕生日（MMDD形式） |

誕生日検索では `NAME` をキャラクターの英語内部名（小文字、スペースなし）に置き換えてください。例:

- `{game:genshin:birthday:funingna}` → フリーナの誕生日
- `{game:genshin:birthday:hutao}` → 胡桃の誕生日
- `{game:genshin:birthday:zhongli}` → 鍾離の誕生日

---

## 特殊

| 変数 | 出力例 | 説明 |
|---|---|---|
| `{literal:テキスト}` | `テキスト` | テキストをそのまま出力（処理なし） |

---

## カスタム変数（チップ）

**明文生成**ページの **+ 追加** ボタンで独自の名前付き変数を定義できます。各チップはラベルをテンプレート式にマッピングします。例:

- ラベル: `my-key`、値: `sk-{date:MMDD}{random:hex:6}`

チップをクリックするとカーソル位置にテンプレート値が挿入されます。

---

## テンプレート例

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

## 編集可能な組み込みデータ

現在は **設定 -> 組み込みテンプレートデータ** から、生成で実際に使われるサーバー側の組み込み値を直接編集できます。

- 単語リスト: 1行に1項目
- 原神の誕生日: `name=MMDD`
- **保存** で以後の生成に反映
- **リセット** で既定値に復元

### デフォルトのゲーム単語リスト

`yuanshen`, `genshin`, `funingna`, `funina`, `naxida`, `nahida`, `zhongli`, `wendi`, `venti`, `leishen`, `raiden`, `ganyu`, `hutao`, `keqing`, `xiao`, `ayaka`, `yoimiya`, `yelan`, `alhaitham`, `wanderer`, `nilou`, `shenhe`, `yae`, `kokomi`, `eula`, `kazuha`, `tighnari`, `cyno`, `dehya`, `baizhu`, `lyney`, `lynette`, `freminet`, `neuvillette`, `wriothesley`, `navia`, `chiori`, `arlecchino`, `clorinde`, `sigewinne`, `emilie`, `mualani`, `kinich`, `xilonen`, `chasca`, `mavuika`, `teyvat`, `mondstadt`, `liyue`, `inazuma`, `sumeru`, `fontaine`, `natlan`, `snezhnaya`, `celestia`, `primogem`, `mora`, `resin`, `archon`, `vision`, `gnosis`, `abyss`

### デフォルトの技術単語リスト

`kubernetes`, `docker`, `terraform`, `ansible`, `prometheus`, `grafana`, `jenkins`, `gitlab`, `nginx`, `redis`, `postgres`, `mongodb`, `elasticsearch`, `kafka`, `rabbitmq`, `consul`, `vault`, `istio`, `envoy`, `grpc`, `graphql`, `restapi`, `websocket`, `oauth`, `jwt`, `ssl`, `tls`, `https`, `cicd`, `devops`, `sre`, `mlops`, `microservice`, `serverless`, `lambda`, `cloudflare`, `wasm`, `rust`, `golang`, `typescript`, `python`, `swift`, `kotlin`, `zig`

### デフォルトの金融単語リスト

`bitcoin`, `ethereum`, `solana`, `defi`, `nft`, `dao`, `staking`, `yield`, `liquidity`, `swap`, `bridge`, `oracle`, `bullish`, `bearish`, `hodl`, `whale`, `altcoin`, `mainnet`, `testnet`, `airdrop`, `ipo`, `nasdaq`, `sp500`, `dowjones`, `forex`, `commodity`, `futures`, `options`, `dividend`, `portfolio`, `hedge`, `arbitrage`, `inflation`, `deflation`, `gdp`, `cpi`, `fed`, `ecb`, `pboc`, `boj`

### デフォルトの汎用単語リスト

`alpha`, `bravo`, `charlie`, `delta`, `echo`, `foxtrot`, `golf`, `hotel`, `india`, `juliet`, `kilo`, `lima`, `mike`, `november`, `oscar`, `papa`, `quebec`, `romeo`, `sierra`, `tango`, `uniform`, `victor`, `whiskey`, `xray`, `yankee`, `zulu`, `phoenix`, `dragon`, `storm`, `shadow`, `cipher`, `quantum`, `nebula`, `aurora`, `zenith`, `vortex`, `prism`, `apex`, `nova`, `pulse`

### デフォルトの原神キャラクター

`funingna`, `funina`, `naxida`, `nahida`, `zhongli`, `wendi`, `venti`, `leishen`, `raiden`, `ganyu`, `hutao`, `keqing`, `xiao`, `ayaka`, `yoimiya`, `yelan`, `alhaitham`, `wanderer`, `nilou`, `shenhe`, `yae`, `kokomi`, `eula`, `kazuha`, `tighnari`, `cyno`, `dehya`, `baizhu`, `lyney`, `lynette`, `freminet`, `neuvillette`, `wriothesley`, `navia`, `chiori`, `arlecchino`, `clorinde`, `sigewinne`, `emilie`, `mualani`, `kinich`, `xilonen`, `chasca`, `mavuika`

### デフォルトの原神誕生日

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
