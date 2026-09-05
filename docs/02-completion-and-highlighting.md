# 02. Tab補完とコマンドのシンタックスハイライト

見た目に一番影響する2つの不具合と、その直し方。

## 不具合A: Tab補完が候補一覧を出さない

**原因**: `compinit` が一度も呼ばれていなかった。`zsh-completions` や `gcloud` の
`completion.zsh.inc` (内部で `compdef` を使う) を入れても、大元の `compinit` が
無ければ zsh は最低限のフォールバック補完 (候補一覧なし、大文字小文字を区別、色なし)
のままになる。

**対処**: `shell/zshrc` の先頭付近に以下を追加(1日1回だけ重いセキュリティチェックを
行い、それ以外はキャッシュから高速読み込み):

```zsh
autoload -Uz compinit
_zcompdump="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump-${ZSH_VERSION}"
mkdir -p "${_zcompdump:h}"
if [[ -n ${_zcompdump}(#qN.mh+24) ]]; then
    compinit -d "$_zcompdump"
    { zcompile "$_zcompdump" } &!
else
    compinit -C -d "$_zcompdump"
fi
```

`compinit` は **`compdef` を使う他の初期化(gcloud等)より前** に呼ぶこと。順序を守らないと
`compdef: command not found` になる。

続けて `zstyle` で候補一覧の見た目(lsと同じ配色、矢印/hjklで選択、大文字小文字無視の
マッチング)を設定する。詳細は `shell/zshrc` 本体を参照。

**検証方法**(対話的なキー入力を自動テストするのは難しいので、内部状態を直接確認する):

```bash
zsh -lic '
  echo "cd    -> ${_comps[cd]:-<none>}"
  echo "rm    -> ${_comps[rm]:-<none>}"
  echo "mkdir -> ${_comps[mkdir]:-<none>}"
'
# compinit が効いていれば _cd / _rm / _mkdir が出る。空なら未初期化。
```

## 不具合B: コマンドの色分け(zsh-syntax-highlighting)が効かない

**原因**: `zsh-syntax-highlighting` は ZLE (zsh's line editor) のウィジェットを
ラップして動く。**他のウィジェットをラップ/再定義するもの(fzf, atuin, zoxide, 独自の
bindkey)より後に読み込まないと、ラップが壊れて機能しなくなる。** これは
zsh-syntax-highlighting 自体のREADMEに明記されている制約。

**対処**: `sheldon` (zsh-autosuggestions/zsh-syntax-highlighting を管理) の読み込みを
`.zshrc` の **最後** に移動する。fzf keybindings, zoxide init, atuin init, starship init,
独自の bindkey (Ctrl+Q など) より後。

**検証方法**:

```bash
zsh -lic 'echo highlighters: ${(k)ZSH_HIGHLIGHT_HIGHLIGHTERS[@]}'
# "highlighters: main" のように出れば有効。空なら読み込み順序を疑う。
```

## 不具合C(環境依存): 新しいターミナルを開いても bash のまま

Windows Terminal などのWSLプロファイルは、明示的に `zsh` を起動コマンドに指定しない限り、
**ログインシェル** (`/etc/passwd` の shell フィールド、通常 `/bin/bash`) を起動する。
zshに完全な設定 (このリポジトリの内容) を書いても、ログインシェルが bash のままだと
一生 `.zshrc` は読まれない。

`chsh -s $(command -v zsh)` で直せるが、**これは対話的なパスワード入力が必須**で
スクリプトからは実行できない。それがどうしても嫌な場合(あるいはパスワード入力が
できない自動化環境)向けに、`shell/bash_profile` に以下のフォールバックを入れてある:

```bash
case $- in
    *i*)
        if [ -z "${__NO_ZSH_EXEC:-}" ] && command -v zsh >/dev/null 2>&1; then
            exec zsh -li
        fi
        [ -r "$HOME/.bashrc" ] && . "$HOME/.bashrc"
        ;;
esac
```

対話的なログインシェルが起動した瞬間に zsh へ `exec` で完全に入れ替わる。非対話的な
`bash -c '...'` やスクリプト実行には一切影響しない(`case $- in *i*)` でガードしている
ため)。`__NO_ZSH_EXEC=1 bash` と打てば、この自動切り替えを無効化して素のbashに留まれる。
