#!/usr/bin/env bash
# 導入後の簡易チェック。壊れていても止まらず、項目ごとに OK/NG を出す。
set +e

pass=0; fail=0
check_cmd() {
    if command -v "$1" >/dev/null 2>&1; then
        printf '  \033[32mok\033[0m  %-12s %s\n' "$1" "$("$1" --version 2>&1 | head -1)"
        pass=$((pass+1))
    else
        printf '  \033[31mNG\033[0m  %-12s not found\n' "$1"
        fail=$((fail+1))
    fi
}

echo "--- コマンド存在チェック ---"
for c in zsh starship fzf atuin zoxide sheldon pyenv uv nvim yazi ya jq git; do
    check_cmd "$c"
done

echo ""
echo "--- 設定ファイル存在チェック ---"
for f in "$HOME/.config/shell/env.sh" "$HOME/.config/shell/interactive.sh" \
         "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile" \
         "$HOME/.config/nvim/init.lua" "$HOME/.config/yazi/keymap.toml" \
         "$HOME/.config/starship.toml" "$HOME/.config/starship-cloud.toml"; do
    if [ -e "$f" ]; then
        printf '  \033[32mok\033[0m  %s\n' "${f/#$HOME/\~}"
        pass=$((pass+1))
    else
        printf '  \033[31mNG\033[0m  %s\n' "${f/#$HOME/\~}"
        fail=$((fail+1))
    fi
done

echo ""
echo "--- 起動時間 (5回, 1回目は捨てる) ---"
zsh -lic exit >/dev/null 2>&1
for i in 1 2 3; do /usr/bin/time -f "  zsh:  %e s" zsh -lic 'exit' 2>&1 | tail -1; done
for i in 1 2 3; do /usr/bin/time -f "  bash: %e s" bash -lic 'exit' 2>&1 | tail -1; done

echo ""
echo "--- PATH 重複エントリ ---"
dupes=$(zsh -lic 'echo $PATH' 2>/dev/null | tr ':' '\n' | sort | uniq -d | wc -l)
echo "  $dupes 件"

echo ""
echo "$pass OK / $fail NG"
[ "$fail" -eq 0 ]
