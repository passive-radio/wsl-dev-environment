# 01. シェル起動の高速化

WSL2 (Ubuntu 24.04) 実測: zsh **1.2s -> 0.24s**、bash **0.18s -> 0.09s**。

## 計測方法

```bash
zsh -lic exit >/dev/null 2>&1   # 1回目は補完キャッシュ生成が走るので捨てる
for i in 1 2 3 4 5; do /usr/bin/time -f "%e s" zsh -lic 'exit' 2>&1 | tail -1; done
```

内訳を見るには zsh の `zprof`:

```bash
cat > /tmp/prof.zsh <<'EOF'
zmodload zsh/zprof
source ~/.zshrc
zprof | head -20
EOF
zsh -lic 'source /tmp/prof.zsh'
```

## 見つかったボトルネックと対処

| 原因 | コスト | 対処 | ファイル |
|---|---:|---|---|
| `nvm.sh` を毎回 source (+自動 `use default`) | 約450ms | default バージョンの bin を直接PATHに置き、`nvm`関数自体は初回呼び出し時だけ読み込む | `shell/interactive.sh` |
| `mise activate` (hook登録 + 初回hook実行) | 約600ms | 完全遅延化。`mise`/`mise-activate` を呼んだ瞬間に初めて本体を読み込む | `shell/interactive.sh` |
| `eval "$(pyenv init - zsh)"` を毎回 | 約190ms | 出力をキャッシュして再利用(pyenv本体が更新された時だけ再生成)、`pyenv rehash` も新しい実行ファイルが増えた時だけ実行 | `shell/interactive.sh` |

## なぜ mise を「使ってるのに」遅延化したか

このマシンでは mise は **1つもツールをpinしていなかった** (`mise ls` が空)。つまり
`mise activate` の hook は起動のたびに何もしないチェックのために600ms払っていただけだった。
遅延化すると、`mise` コマンドを一度も打たないシェルではコストゼロになる。

トレードオフ: ディレクトリ移動での自動バージョン切り替え (mise の目玉機能) は、そのシェルで
一度 `mise` (または `mise-activate`) を呼ぶまで有効にならない。mise を積極的に使うプロジェクトが
増えたら、シェル起動直後に `mise-activate` と打つ運用に切り替えるか、`shell/interactive.sh` の
遅延化ブロックを削除して元の eager activate に戻すこと。

## PATH の重複除去

`shell/env.sh` の `path_prepend`/`path_append` は追加前に既存エントリを削除するので、
何度 source しても重複しない。最後に `path_dedupe` で全体を1回だけ掃除する。

## WSL特有の注意

WSL は Windows 側の PATH をそのまま継承するため、`pyenv-win` の残骸などが混ざることがある。
`shell/env.sh` の最後の方で `*pyenv-win*` にマッチするエントリを機械的に除去している。
