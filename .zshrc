# Portable shell settings. Work-specific settings are installed separately.
IS_MACOS=false
IS_LINUX=false
[[ "$(uname)" == Darwin ]] && IS_MACOS=true
[[ "$(uname)" == Linux ]] && IS_LINUX=true

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
# Keep completion caching without disabling Oh My Zsh's permission checks.
mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}"
ZSH_COMPDUMP="${XDG_CACHE_HOME:-$HOME/.cache}/zcompdump-${ZSH_VERSION}"
plugins=(git)
[[ -f "$ZSH/oh-my-zsh.sh" ]] && source "$ZSH/oh-my-zsh.sh"

alias vim=nvim
alias pip=pip3
alias k=kubectl
alias ck=claude-kanban
alias vibe-kanban='npx vibe-kanban'
bindkey -v
export KEYTIMEOUT=1
bindkey -M viins '^[' vi-cmd-mode
ulimit -n 32768 2>/dev/null || true

export GOPATH="${GOPATH:-$HOME/go}"
export PATH="$HOME/.local/bin:$HOME/.pi/agent/bin:$HOME/dotfiles/bin:$HOME/.cargo/bin:$GOPATH/bin:$PATH"
export PATH="$HOME/.yarn/bin:$HOME/.config/yarn/global/node_modules/.bin:$PATH"

if command -v fzf >/dev/null; then
  if fzf --zsh >/dev/null 2>&1; then
    cache="${XDG_CACHE_HOME:-$HOME/.cache}/fzf-zsh.zsh"
    if [[ ! -f "$cache" || "$(command -v fzf)" -nt "$cache" ]]; then
      fzf --zsh > "$cache"
    fi
    source "$cache"
    unset cache
  elif [[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]]; then
    source /usr/share/doc/fzf/examples/key-bindings.zsh
    [[ -f /usr/share/doc/fzf/examples/completion.zsh ]] && source /usr/share/doc/fzf/examples/completion.zsh
  fi
fi

if $IS_MACOS; then
  for file in /opt/homebrew/share/google-cloud-sdk/{path,completion}.zsh.inc; do
    [[ -f "$file" ]] && source "$file"
  done
  export HOMEBREW_NO_INSECURE_REDIRECT=1
  export HOMEBREW_CASK_OPTS=--require-sha
  export PKG_CONFIG_PATH="/opt/homebrew/opt/openssl/lib/pkgconfig:/opt/homebrew/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
  export CPATH="/opt/homebrew/include:${CPATH:-}"
  export LIBRARY_PATH="/opt/homebrew/lib:${LIBRARY_PATH:-}"
  export PATH="/opt/homebrew/opt/coreutils/libexec/gnubin:$PATH"
  export PYENV_ROOT="$HOME/.pyenv"
  export PATH="$PYENV_ROOT/shims:$HOME/.rbenv/shims:$PATH"
  if command -v pyenv >/dev/null; then
    pyenv() { unset -f pyenv; eval "$(command pyenv init -)"; pyenv "$@"; }
  fi
  if command -v rbenv >/dev/null; then
    rbenv() { unset -f rbenv; eval "$(command rbenv init -)"; rbenv "$@"; }
  fi
  [[ -f "$HOME/.yarn/switch/env" ]] && source "$HOME/.yarn/switch/env"
fi

# Workspaces expose a stable socket across SSH reconnects. Do not choose an
# arbitrary /tmp/ssh-* socket (it could be stale or belong to a different agent).
if $IS_LINUX && [[ -S "$HOME/.ssh/ssh_auth_sock" ]]; then
  export SSH_AUTH_SOCK="$HOME/.ssh/ssh_auth_sock"
fi
[[ -f "$HOME/.zshrc.work" ]] && source "$HOME/.zshrc.work"
[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
