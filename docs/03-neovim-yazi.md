# 03. Neovim と yazi

## Neovim

Ubuntu 22.04/24.04 の apt 版 Neovim は古く(0.6系)、Treesitterベースのシンタックス
ハイライトが弱い。公式のプリビルドバイナリを `sudo` 無しでユーザー領域に入れる。

```bash
V=0.12.5   # https://github.com/neovim/neovim/releases から最新を確認
curl -L -o /tmp/nvim.tar.gz \
  "https://github.com/neovim/neovim/releases/download/v${V}/nvim-linux-x86_64.tar.gz"
mkdir -p ~/.local/opt
rm -rf ~/.local/opt/nvim-linux-x86_64
tar xzf /tmp/nvim.tar.gz -C ~/.local/opt
ln -sfn ~/.local/opt/nvim-linux-x86_64 ~/.local/opt/nvim
mkdir -p ~/.local/bin
ln -sf ~/.local/opt/nvim/bin/nvim ~/.local/bin/nvim
```

`~/.local/bin` が PATH の先頭にある前提 (`shell/env.sh` 参照)。

`nvim/init.lua` を `~/.config/nvim/init.lua` に置くと、[lazy.nvim](https://github.com/folke/lazy.nvim)
経由で [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) が入り、
主要言語 (bash, python, js/ts/tsx, rust, go, lua, json/yaml/toml, markdown, html/css等)
のシンタックスハイライトが有効になる。初回起動時にパーサーのダウンロード+コンパイルが
走るので **Cコンパイラ(gcc/cc)とgitが必須**、初回だけ数分かかる:

```bash
nvim --headless "+Lazy! sync" "+qa"   # プラグイン取得
nvim --headless "+TSUpdateSync" "+qa" # パーサーのコンパイルを確実に完走させる
```

`vi` は `nvim` のエイリアス(`shell/interactive.sh` 参照)。`vim` 自体は変更していない
ので、実体としてのvimがまだ必要なスクリプト等には影響しない。

**既知の制限**: `tree-sitter-zsh` は nvim-treesitter の標準レジストリに存在しないため、
`.zshrc`/`.bashrc` はTreesitterでのハイライト対象外(vimの従来のregex構文ハイライトは効く)。

## yazi

```bash
V=26.9.1   # https://github.com/sxyazi/yazi/releases から最新を確認
curl -L -o /tmp/yazi.zip \
  "https://github.com/sxyazi/yazi/releases/download/v${V}/yazi-x86_64-unknown-linux-gnu.zip"
mkdir -p /tmp/yazi_extract && python3 -m zipfile -e /tmp/yazi.zip /tmp/yazi_extract
mkdir -p ~/.local/opt
mv "/tmp/yazi_extract/yazi-x86_64-unknown-linux-gnu" ~/.local/opt/
ln -sfn ~/.local/opt/yazi-x86_64-unknown-linux-gnu ~/.local/opt/yazi
ln -sf ~/.local/opt/yazi/yazi ~/.local/bin/yazi
ln -sf ~/.local/opt/yazi/ya   ~/.local/bin/ya
```

`yazi/keymap.toml` を `~/.config/yazi/keymap.toml` に配置。2つのキーマップを追加している:

### `i` : ホバー中のファイルを $EDITOR (nvim) で開く

```toml
{ on = "i", run = "shell '$EDITOR %h' --block", desc = "Open hovered file in $EDITOR" }
```

- yazi のデフォルトキーマップで `i` は (ファイルマネージャ画面では) 未使用 -
  競合しないことをyaziの公式デフォルトキーマップで確認済み。
- `--block` が yazi をバックグラウンドに退避させ nvim をフォアグラウンドに出す。
  nvim を `:q` (通常の終了操作) すれば、そのまま yazi の画面に戻る。

### `P` : 強制ペースト + Windows "Zone.Identifier" 残骸の掃除

WSLでWindows側(`/mnt/c/...`)とLinux側の間でファイルをコピーすると、NTFSの
Alternate Data Stream (`Zone.Identifier`、ダウンロードしたファイルに付く
"インターネットゾーン" マーク) が ext4 上では別ファイルとして具現化してしまい、
`filename:Zone.Identifier` のようなゴミファイルが残ることがある
([参考: microsoft/WSL#4609](https://github.com/microsoft/WSL/issues/4609))。

```toml
{ on = "P", run = [
    "paste --force",
    "shell 'd=\"$PWD\"; for i in $(seq 1 20); do find \"$d\" -maxdepth 1 \( -iname \"*:Zone.Identifier\" -o -iname \"*Zone.Identifier\" \) -delete 2>/dev/null; sleep 1; done'",
  ], desc = "Paste (force) and strip Zone.Identifier sidecars" }
```

- `paste` は yazi 内部ではバックグラウンドタスクなので、直後に1回 `find -delete` する
  だけでは大きい転送だと間に合わない可能性がある。そのため **20秒間、1秒おきに
  ペースト先ディレクトリだけ (`-maxdepth 1`) を掃除するポーリングループ**にしてある。
  単発/複数ファイルどちらのペーストでも同じ仕組みで効く。
- **既知の制限**: 20秒を超えるような非常に大きい/遅い転送では取りこぼす可能性がある。
  その場合は `P` を再度押すか、`find . -maxdepth 1 -iname '*:Zone.Identifier' -delete`
  を手で実行する。
- gcloud/AWSログインと同様、この機能は「表示・後始末」だけで、コピー自体の中身や
  権限には一切手を加えない。

`~/.config/yazi/keymap.toml` の妥当性は `python3 -c "import tomllib; tomllib.load(open('keymap.toml','rb'))"`
で構文チェックできる。実際のキー入力(擬似端末経由)の完全な自動テストはこのリポジトリの
検証環境では安定しなかったため、**実機での動作確認を推奨**する。
