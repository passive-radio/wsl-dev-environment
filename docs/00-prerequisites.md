# 00. 前提ツール

`scripts/install.sh` は設定ファイルの配置だけを行う。ツール本体は各自インストールしてから実行すること。

## 必須ではないが、設定が前提にしているもの

| ツール | 役割 | インストール例 |
|---|---|---|
| zsh | メインシェル | `sudo apt install -y zsh` |
| [starship](https://starship.rs/) | プロンプト | `curl -sS https://starship.rs/install.sh \| sh -s -- -b ~/.local/bin -y` |
| [sheldon](https://github.com/rossmacarthur/sheldon) | zshプラグインマネージャ | `cargo install sheldon` (要 Rust) |
| [fzf](https://github.com/junegunn/fzf) | ファジー検索 | `sudo apt install -y fzf` (apt版でも動作。最新機能が要るなら git clone 版) |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | スマートcd | `sudo apt install -y zoxide` |
| [atuin](https://atuin.sh/) | 履歴検索(Ctrl-R) | `curl --proto '=https' --tlsv1.2 -sSf https://setup.atuin.sh \| sh` |
| [pyenv](https://github.com/pyenv/pyenv) | Pythonインタプリタ管理 | `curl https://pyenv.run \| bash` |
| [uv](https://github.com/astral-sh/uv) | Pythonプロジェクト/CLIツール管理 | `curl -LsSf https://astral.sh/uv/install.sh \| sh` (**standaloneバイナリで。`pip install uv` は避ける**) |
| [nvm](https://github.com/nvm-sh/nvm) | Nodeバージョン管理 | `curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh \| bash` |
| [mise](https://mise.jdx.dev/) | 汎用ランタイム管理(使わないなら省略可) | `curl https://mise.run \| sh` |
| [Neovim](https://neovim.io/) 0.10+ | エディタ (`vi` はこれを指す) | 公式ビルド推奨、詳細は [docs/03-neovim-yazi.md](03-neovim-yazi.md) |
| [yazi](https://yazi-rs.github.io/) | ターミナルファイラ | 公式ビルド推奨、詳細は [docs/03-neovim-yazi.md](03-neovim-yazi.md) |
| jq | statusline.sh が使う(無くても動くが機能が減る) | `sudo apt install -y jq` |

zsh-autosuggestions / zsh-syntax-highlighting は sheldon 経由 (`zsh/sheldon_plugins.toml` を
`~/.config/sheldon/plugins.toml` に配置、sheldon が自動で clone する)。

## この設定が前提にしていない/含まないもの

- gcloud SDK, opencode, kimi-code, bun, cargo/rust, gvm, conda/mamba, GCP/AWS CLI --
  `shell/env.sh` と `shell/zshrc` は「入っていれば使う、無ければ無視する」形で書かれているので、
  無くてもエラーにはならない。使わないツールの行は削除して構わない。
- Windows側のIME設定 (fcitx5) は日本語入力環境を使う場合のみ関係する。使わないなら
  `shell/interactive.sh` の該当ブロックを削除してよい。
