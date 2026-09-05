# ~/.config/shell/env.sh
# Shared, non-interactive environment for bash and zsh: PATH and exported vars only.
# Sourced from ~/.bashrc / ~/.bash_profile (bash) and ~/dotfiles-zsh-2026/dotfiles/.zshrc (zsh).
# Must stay non-interactive: no prompts, no aliases, no completion setup.
#
# Adapted from https://github.com/ (my-terminal-configurations) for this machine's
# actual toolchain: pyenv, nvm, mise, atuin, sheldon, gcloud, opencode, kimi-code.

# --- idempotency guard -------------------------------------------------------
if [ -n "${__SHELL_ENV_LOADED:-}" ] && [ -z "${__SHELL_ENV_FORCE:-}" ]; then
    return 0 2>/dev/null || true
fi
__SHELL_ENV_LOADED=1

# --- PATH helpers ------------------------------------------------------------
# Remove any existing occurrence before adding, so PATH never accumulates
# duplicates when this file is sourced more than once (e.g. nested shells).
path_remove() {
    case ":$PATH:" in
        *":$1:"*)
            PATH=$(printf '%s' "$PATH" | tr ':' '\n' | grep -vxF "$1" | paste -sd: -)
            export PATH
            ;;
    esac
}
path_prepend() { [ -d "$1" ] || return 0; path_remove "$1"; PATH="$1${PATH:+:$PATH}"; export PATH; }
path_append()  { [ -d "$1" ] || return 0; path_remove "$1"; PATH="${PATH:+$PATH:}$1"; export PATH; }

# Collapse duplicate PATH entries, keeping the first (highest-priority) one.
path_dedupe() {
    PATH=$(printf '%s' "$PATH" | awk -v RS=: -v ORS=: '!seen[$0]++' | sed 's/:$//')
    export PATH
}

# --- eval cache ----------------------------------------------------------
# `pyenv init -` costs ~150-200ms because it shells out. Its output only
# changes when pyenv itself is upgraded, so cache it and regenerate only when
# the binary is newer than the cached copy.
__shell_cache="${XDG_CACHE_HOME:-$HOME/.cache}/shell"
[ -d "$__shell_cache" ] || mkdir -p "$__shell_cache"

# eval_cached <cache-key> <stamp-file> <command> [args...]
eval_cached() {
    __ec_key=$1; __ec_stamp=$2; shift 2
    __ec_file="$__shell_cache/$__ec_key"
    if [ ! -s "$__ec_file" ] || [ "$__ec_stamp" -nt "$__ec_file" ]; then
        if "$@" > "$__ec_file.$$" 2>/dev/null && [ -s "$__ec_file.$$" ]; then
            mv -f "$__ec_file.$$" "$__ec_file"
        else
            rm -f "$__ec_file.$$"
        fi
    fi
    if [ -s "$__ec_file" ]; then
        . "$__ec_file"
    else
        eval "$("$@" 2>/dev/null)"
    fi
    unset __ec_key __ec_stamp __ec_file
}

# --- current shell -------------------------------------------------------
if [ -n "${ZSH_VERSION:-}" ]; then
    CURRENT_SHELL=zsh
elif [ -n "${BASH_VERSION:-}" ]; then
    CURRENT_SHELL=bash
else
    CURRENT_SHELL=sh
fi

# --- core env --------------------------------------------------------------
export EDITOR="${EDITOR:-nvim}"
export VISUAL="$EDITOR"
export PAGER="${PAGER:-less}"
export LESS="-R -F -X"

export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

# --- Rust: cargo -------------------------------------------------------------
[ -s "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# --- Node: nvm ---------------------------------------------------------------
# Sourcing nvm.sh (plus its automatic "use default" at load) costs ~450ms.
# Instead: put the *default* alias version's bin dir on PATH directly (instant),
# and lazy-load the full `nvm` function on first actual use (see interactive.sh).
export NVM_DIR="$HOME/.nvm"

nvm_default_version() {
    [ -r "$NVM_DIR/alias/default" ] || return 1
    __v=$(cat "$NVM_DIR/alias/default" 2>/dev/null)
    [ -n "$__v" ] || return 1
    if [ -d "$NVM_DIR/versions/node/v${__v#v}" ]; then
        printf 'v%s' "${__v#v}"; unset __v; return 0
    fi
    if [ -r "$NVM_DIR/alias/$__v" ]; then
        __v=$(cat "$NVM_DIR/alias/$__v" 2>/dev/null)
        if [ -d "$NVM_DIR/versions/node/v${__v#v}" ]; then
            printf 'v%s' "${__v#v}"; unset __v; return 0
        fi
    fi
    unset __v; return 1
}
__nvm_default=$(nvm_default_version 2>/dev/null)
[ -n "$__nvm_default" ] && path_prepend "$NVM_DIR/versions/node/$__nvm_default/bin"
unset __nvm_default

# --- Python: pyenv -----------------------------------------------------------
export PYENV_ROOT="$HOME/.pyenv"
if [ -x "$PYENV_ROOT/bin/pyenv" ]; then
    path_prepend "$PYENV_ROOT/bin"
    # Replaces `eval "$(pyenv init --path)"`, which pays for a `bash --norc`
    # subprocess + a `pyenv rehash` every shell start just to put shims first.
    path_prepend "$PYENV_ROOT/shims"
fi

# --- opencode / kimi-code (CLI tools) ----------------------------------------
path_prepend "$HOME/.opencode/bin"

# --- Google Cloud SDK: PATH only (completion loaded per-shell, see rc files) --
if [ -n "${ZSH_VERSION:-}" ] && [ -f "$HOME/packages/google-cloud-sdk/path.zsh.inc" ]; then
    . "$HOME/packages/google-cloud-sdk/path.zsh.inc"
elif [ -f "$HOME/packages/google-cloud-sdk/path.bash.inc" ]; then
    . "$HOME/packages/google-cloud-sdk/path.bash.inc"
fi

# --- atuin (history) ----------------------------------------------------------
[ -s "$HOME/.atuin/bin/env" ] && . "$HOME/.atuin/bin/env"

# --- Bun ----------------------------------------------------------------------
export BUN_INSTALL="$HOME/.bun"
path_prepend "$BUN_INSTALL/bin"

# --- mise: NOT activated here ---------------------------------------------
# mise is lazy-loaded on first use (interactive.sh) — see the comment there for
# why: it currently manages zero pinned tools but its eager `activate` hook
# costs ~600ms/shell.

# --- WSL: pyenv-win cleanup ---------------------------------------------------
# WSL inherits the whole Windows PATH, which can drag in pyenv-win .bat shims
# that are useless from Linux and confuse `uv python list`.
for __wp in $(printf '%s' "$PATH" | tr ':' '\n' | grep -i 'pyenv-win' 2>/dev/null); do
    path_remove "$__wp"
done
unset __wp

# --- user bin / kimi-code (highest precedence, prepended last) --------------
path_prepend "$HOME/bin"
path_prepend "$HOME/.local/bin"
path_prepend "$HOME/.kimi-code/bin"

# --- machine-specific overrides ----------------------------------------------
[ -r "${XDG_CONFIG_HOME:-$HOME/.config}/shell/local.sh" ] && \
    . "${XDG_CONFIG_HOME:-$HOME/.config}/shell/local.sh"

path_dedupe
export PATH
