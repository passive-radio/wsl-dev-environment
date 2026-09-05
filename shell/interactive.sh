# ~/.config/shell/interactive.sh
# Shared interactive setup for bash and zsh: aliases, lazy tool init.
# Sourced near the end of ~/.bashrc and ~/dotfiles-zsh-2026/dotfiles/.zshrc.
# Anything shell-specific (history options, prompt, completion styles,
# keybindings, sheldon/starship/zoxide/atuin init) stays in the rc file itself.

if [ -z "${CURRENT_SHELL:-}" ]; then
    if [ -n "${ZSH_VERSION:-}" ]; then CURRENT_SHELL=zsh
    elif [ -n "${BASH_VERSION:-}" ]; then CURRENT_SHELL=bash
    else CURRENT_SHELL=sh
    fi
fi
__cur_shell=$CURRENT_SHELL

# --- extra aliases ------------------------------------------------------------
# Existing aliases (g=gitui, pn=pnpm, ll/la/l) are defined in the rc files
# themselves and are NOT touched here to avoid clobbering them.
alias gs='git status -sb'
alias gd='git diff'
alias gl='git log --oneline --graph --decorate -20'
alias e.='explorer.exe .'   # WSL: open cwd in Windows Explorer

# `vim` itself is left alone (still real vim 9.1); only `vi` points at nvim.
command -v nvim >/dev/null 2>&1 && alias vi='nvim'

if [ "$__cur_shell" = zsh ]; then
    alias reload='source ~/.zshrc'
else
    alias reload='source ~/.bashrc'
fi

# --- prompt: cloud-identity visibility toggle --------------------------------
# ~/.config/starship.toml (default) hides the gcloud/AWS modules, since they
# print your GCP account email / AWS region-profile on every prompt line -
# awkward during screen recordings. These just swap STARSHIP_CONFIG for the
# current shell; your actual gcloud/AWS login is never touched either way.
cloud-prompt-on()  { export STARSHIP_CONFIG="$HOME/.config/starship-cloud.toml"; }
cloud-prompt-off() { unset STARSHIP_CONFIG; }

# --- input method (fcitx5 / jp layout) ----------------------------------------
# Was bash-only before; moved here so it's set up no matter which shell is
# actually entered first (bash login -> exec zsh, or a terminal profile that
# launches zsh directly). Idempotent: pgrep guards the daemon launch.
setxkbmap -layout jp 2>/dev/null
export GTK_IM_MODULE=fcitx5
export QT_IM_MODULE=fcitx5
export XMODIFIERS=@im=fcitx5
export DefaultIMModule=fcitx5
export INPUT_METHOD=fcitx5
if ! pgrep -x fcitx5 > /dev/null; then
    (fcitx5 --disable=wayland,waylandim -d --verbose '*'=0 &) 2>/dev/null
fi

# --- nvm: lazy load ------------------------------------------------------------
# The default version's bin dir is already on PATH (env.sh), so `node`, `npm`,
# `npx` work instantly without sourcing nvm.sh (~450ms, mostly its own
# "use default" resolution at load time). The real nvm.sh is only sourced the
# first time `nvm` is actually invoked, at which point this shim replaces
# itself with the real function - same end behaviour, just deferred.
if [ -s "$NVM_DIR/nvm.sh" ]; then
    nvm() {
        unset -f nvm 2>/dev/null
        # shellcheck disable=SC1091
        \. "$NVM_DIR/nvm.sh"
        if [ "$__cur_shell" = bash ] && [ -s "$NVM_DIR/bash_completion" ]; then
            \. "$NVM_DIR/bash_completion"
        fi
        nvm "$@"
    }
fi

# --- pyenv (cached init + conditional rehash) ---------------------------------
__pyenv_init_filtered() {
    "$PYENV_ROOT/bin/pyenv" init - --no-rehash "$1" \
        | sed '/^PATH="\$(bash --norc/,/^export PATH=".*shims:\${PATH}"$/d'
}

if [ -x "$PYENV_ROOT/bin/pyenv" ] && command -v eval_cached >/dev/null 2>&1; then
    eval_cached "pyenv-init.$__cur_shell.sh" "$PYENV_ROOT/bin/pyenv" \
        __pyenv_init_filtered "$__cur_shell"

    __pyenv_venv="$PYENV_ROOT/plugins/pyenv-virtualenv/bin/pyenv-virtualenv-init"
    if [ -x "$__pyenv_venv" ]; then
        eval_cached "pyenv-venv-init.$__cur_shell.sh" "$__pyenv_venv" \
            "$PYENV_ROOT/bin/pyenv" virtualenv-init - "$__cur_shell"
    fi
    unset __pyenv_venv

    # rehash is only needed after a global `pip install` adds a new executable;
    # skip the ~120ms x2 pyenv normally spends checking this every shell start.
    __pyenv_autorehash() {
        __par_stamp="${__shell_cache:-${XDG_CACHE_HOME:-$HOME/.cache}/shell}/pyenv-rehash-stamp"
        if [ ! -e "$__par_stamp" ] || [ -n "$(find "$PYENV_ROOT/versions" -maxdepth 2 -name bin \
                -newer "$__par_stamp" -print -quit 2>/dev/null)" ]; then
            "$PYENV_ROOT/bin/pyenv" rehash 2>/dev/null
            : > "$__par_stamp"
        fi
        unset __par_stamp
    }
    __pyenv_autorehash
fi
unset -f __pyenv_init_filtered 2>/dev/null

# --- mise: lazy load ------------------------------------------------------
# `mise activate` + its precmd/chpwd hook costs ~600ms/shell combined, but this
# machine has zero tools currently pinned via mise (pyenv/nvm own that job).
# Kept installed and fully usable - the first actual `mise` (or `mise-activate`)
# call loads the real activation hook, including per-directory auto-switching
# from then on in that shell.  Run `mise-activate` once at the top of a shell
# if you start relying on directory-based auto-switching in a mise project.
MISE_BIN="$HOME/.local/bin/mise"
if [ -x "$MISE_BIN" ]; then
    __mise_lazy_load() {
        unset -f mise mise-activate __mise_lazy_load 2>/dev/null
        __mlz_shell=zsh; [ -n "${BASH_VERSION:-}" ] && __mlz_shell=bash
        eval "$("$MISE_BIN" activate "$__mlz_shell")"
        unset __mlz_shell
    }
    # `mise activate` itself defines the real `mise` shell function (needed for
    # `mise shell`/`deactivate` to work correctly) but doesn't invoke it - so
    # after activating, re-dispatch to that real function with the original args.
    mise() { __mise_lazy_load; mise "$@"; }
    mise-activate() { __mise_lazy_load; }
fi

# --- maintenance ---------------------------------------------------------
shell-cache-clear() {
    rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}/shell"
    printf 'shell eval cache cleared - restart your shell\n'
}

unset __cur_shell
