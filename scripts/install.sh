#!/usr/bin/env bash
# 設定ファイルを配置するスクリプト。ツール本体(pyenv/nvm/mise/atuin/zoxide/
# starship/sheldon/fzf/neovim/yazi)のインストールはしない - docs/00-prerequisites.md
# を参照して個別に入れてから実行すること。既存ファイルは自動でバックアップする。
#
# Usage:
#   ./scripts/install.sh              # 対話式(既存ファイルの上書き確認)
#   ./scripts/install.sh --yes        # 確認なしで上書き

set -uo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_DIR="$HOME/dotfiles-backup-$(date +%Y%m%d-%H%M%S)"
ASSUME_YES=0
[ "${1:-}" = "--yes" ] && ASSUME_YES=1

c_ok()   { printf '\033[32m  ok\033[0m %s\n' "$*"; }
c_info() { printf '\033[36m  ->\033[0m %s\n' "$*"; }
c_warn() { printf '\033[33m  !\033[0m %s\n' "$*"; }

confirm() {
    [ "$ASSUME_YES" = 1 ] && return 0
    printf '    %s [y/N] ' "$1"
    read -r reply </dev/tty || return 1
    case "$reply" in [yY]*) return 0 ;; *) return 1 ;; esac
}

backup_and_copy() {
    src="$REPO_DIR/$1"; dst="$2"
    [ -f "$src" ] || { c_warn "見つかりません: $1"; return 1; }
    if [ -e "$dst" ] || [ -L "$dst" ]; then
        mkdir -p "$BACKUP_DIR"
        cp -a "$dst" "$BACKUP_DIR/$(basename "$dst")" 2>/dev/null
    fi
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    c_ok "${dst/#$HOME/\~}"
}

echo "配置先: \$HOME = $HOME"
echo "バックアップ: $BACKUP_DIR (既存ファイルがある場合のみ作成)"
echo ""

backup_and_copy shell/env.sh          "$HOME/.config/shell/env.sh"
backup_and_copy shell/interactive.sh  "$HOME/.config/shell/interactive.sh"
backup_and_copy shell/bashrc          "$HOME/.bashrc"
backup_and_copy shell/bash_profile    "$HOME/.bash_profile"
backup_and_copy shell/profile         "$HOME/.profile"
backup_and_copy shell/zshrc           "$HOME/.zshrc"

if command -v sheldon >/dev/null 2>&1; then
    backup_and_copy zsh/sheldon_plugins.toml "$HOME/.config/sheldon/plugins.toml"
else
    c_warn "sheldon 未インストール - zsh/sheldon_plugins.toml の配置をスキップ"
fi

backup_and_copy nvim/init.lua   "$HOME/.config/nvim/init.lua"
backup_and_copy yazi/keymap.toml "$HOME/.config/yazi/keymap.toml"
backup_and_copy starship/starship.toml       "$HOME/.config/starship.toml"
backup_and_copy starship/starship-cloud.toml "$HOME/.config/starship-cloud.toml"

if [ -d "$HOME/.claude" ]; then
    backup_and_copy claude-code/statusline.sh "$HOME/.claude/statusline.sh"
    chmod +x "$HOME/.claude/statusline.sh" 2>/dev/null
    c_info "settings.json への statusLine 追記は claude-code/settings.snippet.json を参照して手動でマージしてください"
else
    c_warn "~/.claude が無い - Claude Code 未インストールとみなし statusline.sh の配置をスキップ"
fi

echo ""
echo "--- 構文チェック ---"
for f in "$HOME/.config/shell/env.sh" "$HOME/.config/shell/interactive.sh" \
         "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile"; do
    bash -n "$f" 2>/dev/null && c_ok "${f/#$HOME/\~}" || c_warn "構文エラー: ${f/#$HOME/\~}"
done
if command -v zsh >/dev/null 2>&1; then
    zsh -n "$HOME/.zshrc" 2>/dev/null && c_ok "~/.zshrc" || c_warn "構文エラー: ~/.zshrc"
fi

echo ""
echo "完了。次の手順:"
echo "  1. docs/00-prerequisites.md でツール本体(pyenv/nvm/mise/atuin/zoxide/starship/sheldon/fzf/neovim/yazi)を確認"
echo "  2. 新しいシェルを開く、または \`exec zsh\` / \`exec bash\`"
echo "  3. ./scripts/verify.sh で動作確認"
echo "  4. Windows側: windows-terminal/install-hackgen-font.ps1 と apply-default-font.ps1 (任意)"
