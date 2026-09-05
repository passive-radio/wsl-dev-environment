# 04. Claude Code のステータスライン

```
~/dev/my-project  main  +910 -198 3new
sonnet[1m] high  211K / 1M  |  5h 47% →00:00  7d 8%  |  1h33m (実作業 58m)
```

導入:

```bash
cp claude-code/statusline.sh ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh
```

`~/.claude/settings.json` に `claude-code/settings.snippet.json` の `statusLine` キーをマージ。

## 機能

- 1行目: cwd (`$HOME`配下は`~`、それ以外は絶対パス。WSLの`/mnt/c/...`と区別するため)
  + gitブランチ + ベースブランチからの差分 (コミット済み+staged+unstaged+未追跡ファイル)
- 2行目: モデル名 + `[コンテキスト長]` + **reasoning effortレベル** + 使用トークン/上限
  + 5h/7dレート制限 + セッション経過時間(アイドル除いた実作業時間つき)

数値は緑 -> 黄(50%) -> オレンジ(75%) -> 赤太字(90%) でエスカレートする(`SL_WARN`/`SL_HIGH`/`SL_CRIT`で調整可)。

## このリポジトリで直した3つのバグ

### 1. Reasoning effort レベルの表示を追加

入力JSONの `effort.level` (`"low"`/`"medium"`/`"high"` 等) を抽出して
`sonnet[1m] high` のように表示するようにした。フィールドが無い(古いバージョン等)場合は
何も表示せず、既存のレイアウトを崩さない。

### 2. `@tsv` + `IFS=$'\t'` によるフィールドずれ

jqの出力を1回の `read` でまとめて受け取る際、`@tsv` (タブ区切り) と `IFS=$'\t'` の
組み合わせを使っていたが、**bashの`read`はIFSが単一のタブであっても連続する空白文字系の
区切りを1つに畳んでしまう** ため、`session_id` のような空文字列フィールドがあると
それ以降の全フィールドが1つ左にずれる、というバグがあった(レート制限の数値と
リセット時刻が入れ替わる形で表面化)。

区切り文字を `\x1f` (unit separator, 非空白文字) に変更することで解決。空文字列の
フィールドがあっても`read`が正しく空として扱うようになる。

```bash
# Before (バグ): 空フィールドで後続がずれる
IFS=$'\t' read -r a b c <<< "$(printf 'x\t\ty\n')"   # a=x b=y c=(空) になってしまう

# After: 正しく空フィールドとして扱われる
IFS=$'\x1f' read -r a b c <<< "$(printf 'x\x1f\x1fy\n')"  # a=x b=(空) c=y
```

### 3. 5h/7dレート制限が頻繁に非表示になる

`rate_limits` フィールドは**毎回のペイロードに必ず含まれるわけではない**らしく
(直近のAPI呼び出しの有無に連動している様子)、フィールドが無い瞬間はセグメントが
消えてしまい、ちらつきの原因になっていた。

対処: 5h/7dの値を `~/.cache/claude-statusline/rate-limit-{5h,7d}` にそれぞれ独立して
キャッシュし、当該呼び出しの値が無い時はキャッシュへフォールバックする(それぞれ独立
しているので、片方だけ来ないペイロードでもう片方を巻き込まない)。一度も値を見た
ことが無い状態(キャッシュも無い)では、捏造せず非表示のままにする。

## 依存

必須: bash, git, awk, sed, grep, coreutils
任意: jq (無いと grep/sed のフォールバックパーサに切り替わり、セッション実作業時間の
表示だけが消える。トランスクリプトのJSONLパースには本物のJSONパーサが必要なため)

## カスタマイズ

```bash
SL_WARN=50; SL_HIGH=75; SL_CRIT=90     # 色が変わる閾値(%)
SL_ACTIVE_LABEL=実作業                  # "active" にすれば英語表記
SL_UNTRACKED_SCAN=200                   # 行数を数える未追跡ファイルの上限
```
