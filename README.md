# WSL Dev Environment

WSL2 (Ubuntu 24.04) 上のシェル・エディタ・ファイラ・Claude Codeステータスライン・
Windows Terminal 設定一式。個人の環境で見つけた不具合とその原因・直し方を、
再現できる形でまとめてある。個人情報 (ユーザー名・メールアドレス・プロジェクトIDなど)
はすべて `$HOME`/`$USER` 等の変数か汎用的な説明に置き換えてある。

## クイックスタート

```bash
git clone <this-repo> ~/wsl-dev-environment
cd ~/wsl-dev-environment
# ツール本体を先に: docs/00-prerequisites.md
./scripts/install.sh
./scripts/verify.sh
```

Windows側 (フォント + Windows Terminal):

```bash
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w ./windows-terminal/install-hackgen-font.ps1)"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w ./windows-terminal/apply-default-font.ps1)"
```

## 実測値 (WSL2 / Ubuntu 24.04)

| 項目 | Before | After |
|---|---:|---:|
| zsh起動 | 1.2 s | **0.24 s** |
| bash起動 | 0.18 s | **0.09 s** |
| PATH重複エントリ | - | **0** |

## 構成

| ディレクトリ | 内容 | 詳細ドキュメント |
|---|---|---|
| `shell/` | env.sh(共有PATH/環境変数), interactive.sh(共有エイリアス/遅延ロード), bashrc/bash_profile/profile, zshrc | [01](docs/01-shell-performance.md), [02](docs/02-completion-and-highlighting.md) |
| `zsh/` | sheldon (zshプラグインマネージャ) 設定 | [02](docs/02-completion-and-highlighting.md) |
| `nvim/` | Neovim設定 (Treesitterシンタックスハイライト) | [03](docs/03-neovim-yazi.md) |
| `yazi/` | ターミナルファイラのキーマップ | [03](docs/03-neovim-yazi.md) |
| `claude-code/` | Claude Code ステータスライン | [04](docs/04-statusline.md) |
| `starship/` | プロンプト設定 (クラウド識別情報の表示切り替え) | [05](docs/05-starship-cloud-toggle.md) |
| `windows-terminal/` | HackGenフォント導入 + デフォルトフォント設定スクリプト | [06](docs/06-windows-terminal-hackgen.md) |
| `scripts/` | 導入(`install.sh`)・検証(`verify.sh`) | - |

## 見つけて直した不具合の一覧(概要)

- **zsh起動が1.2秒かかっていた** → nvm/mise/pyenvの初期化を遅延ロード・キャッシュ化 ([01](docs/01-shell-performance.md))
- **Tab補完が候補一覧を出さない** → `compinit` が一度も呼ばれていなかった ([02](docs/02-completion-and-highlighting.md))
- **コマンドの色分けが効かない** → zsh-syntax-highlightingの読み込み順序 (他のZLEウィジェットより後に読む必要がある) ([02](docs/02-completion-and-highlighting.md))
- **新しいターミナルがbashのまま** → ログインシェルがzshになっていない場合のフォールバック ([02](docs/02-completion-and-highlighting.md))
- **statuslineのレート制限表示がちらつく** → ペイロードに毎回`rate_limits`が来るとは限らないのでキャッシュ+フォールバック ([04](docs/04-statusline.md))
- **statuslineの`@tsv`パースでフィールドがずれる** → bashの`read`がIFS区切りの空白文字を畳んでしまうバグ ([04](docs/04-statusline.md))
- **プロンプトに毎回GCPアカウント/AWSリージョンが出る** → starship設定ファイルを新規作成しモジュール単位で表示切り替え可能に ([05](docs/05-starship-cloud-toggle.md))

## ライセンス

自由に使ってください。各自の環境に合わせて調整することを前提にしています。
