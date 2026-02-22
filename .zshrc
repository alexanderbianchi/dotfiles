# ── Platform detection ────────────────────────────────────────────────────────
IS_MACOS=false
IS_LINUX=false
[[ "$(uname)" == "Darwin" ]] && IS_MACOS=true
[[ "$(uname)" == "Linux" ]]  && IS_LINUX=true

# ── macOS-only: early setup ──────────────────────────────────────────────────
if $IS_MACOS; then
  export GITLAB_TOKEN=$(security find-generic-password -a ${USER} -s gitlab_token -w 2>/dev/null)

  # Google Cloud SDK
  if [ -f '/opt/homebrew/share/google-cloud-sdk/path.zsh.inc' ]; then
    . '/opt/homebrew/share/google-cloud-sdk/path.zsh.inc'
  fi
  if [ -f '/opt/homebrew/share/google-cloud-sdk/completion.zsh.inc' ]; then
    . '/opt/homebrew/share/google-cloud-sdk/completion.zsh.inc'
  fi
fi

# ── Oh My Zsh ────────────────────────────────────────────────────────────────
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git)
[ -d "$ZSH" ] && source $ZSH/oh-my-zsh.sh

# ── Aliases ──────────────────────────────────────────────────────────────────
alias vim="nvim"
alias pip="pip3"
alias k=kubectl
alias ck="claude-kanban"
alias loadshuffle="cd ~/dd/dd-go/apps/shuffle-service && nvim"
alias loadbeagle="cd ~/dd/dd-go/apps/beagle && nvim"
alias mergeprod="git checkout prod && git pull && git checkout - && git merge prod"
alias rebaseprod="git checkout prod && git pull && git checkout - && git rebase prod"

# ── Shell functions ──────────────────────────────────────────────────────────
ghstaging() {
    local pr_number=$(gh pr view --json number -q .number 2>/dev/null)
    if [ -z "$pr_number" ]; then
        echo "Error: No PR found for current branch"
        return 1
    fi
    gh pr comment "$pr_number" --body "/integrate -d $*"
}

ghmerge() {
    local pr_number=$(gh pr view --json number -q .number 2>/dev/null)
    if [ -z "$pr_number" ]; then
        echo "Error: No PR found for current branch"
        return 1
    fi
    gh pr comment "$pr_number" --body "/merge"
}

# ── Shell settings ───────────────────────────────────────────────────────────
ulimit -n 32768
bindkey -v
export KEYTIMEOUT=1
bindkey -M viins '^[' vi-cmd-mode

# ── Go environment ───────────────────────────────────────────────────────────
export GOPATH="$HOME/go"
export PATH="$GOPATH/bin:$PATH"
export DATADOG_ROOT="$HOME/dd"
export MOUNT_ALL_GO_SRC=1
export GO111MODULE=auto
export GONOSUMDB=github.com/DataDog,go.ddbuild.io
export GOPRIVATE=
export GOPROXY="https://depot-read-api-go.us1.ddbuild.io/magicmirror/magicmirror/@current/|https://depot-read-api-go.us1.ddbuild.io/magicmirror/magicmirror/@current/|https://depot-read-api-go.us1.ddbuild.io/magicmirror/testing/@current/"

# ── AWS ──────────────────────────────────────────────────────────────────────
export AWS_VAULT_KEYCHAIN_NAME=login
export AWS_SESSION_TTL=24h
export AWS_ASSUME_ROLE_TTL=1h

# ── Helm ─────────────────────────────────────────────────────────────────────
export HELM_DRIVER=configmap

# ── PATH additions (universal) ───────────────────────────────────────────────
export PATH="$HOME/.yarn/bin:$HOME/.config/yarn/global/node_modules/.bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"
export PATH="$HOME/.local/bin:$HOME/dotfiles/bin:$PATH"
export VOLTA_HOME="$HOME/.volta"
export PATH="$VOLTA_HOME/bin:$PATH"

# ── fzf ──────────────────────────────────────────────────────────────────────
if command -v fzf &>/dev/null; then
  # fzf 0.48+ supports --zsh; older versions need manual sourcing
  if fzf --zsh &>/dev/null; then
    eval "$(fzf --zsh)"
  elif [ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]; then
    source /usr/share/doc/fzf/examples/key-bindings.zsh
    [ -f /usr/share/doc/fzf/examples/completion.zsh ] && source /usr/share/doc/fzf/examples/completion.zsh
  fi
fi

# ── macOS-only: late setup ───────────────────────────────────────────────────
if $IS_MACOS; then
  # Homebrew
  export HOMEBREW_NO_INSECURE_REDIRECT=1
  export HOMEBREW_CASK_OPTS=--require-sha
  export HOMEBREW_DIR=/opt/homebrew
  export HOMEBREW_BIN=/opt/homebrew/bin

  # C library paths for Go
  export PKG_CONFIG_PATH="/opt/homebrew/opt/openssl/lib/pkgconfig:$PKG_CONFIG_PATH"
  export PKG_CONFIG_PATH="/opt/homebrew/lib/pkgconfig:$PKG_CONFIG_PATH"
  export CPATH="/opt/homebrew/include:$CPATH"
  export LIBRARY_PATH="/opt/homebrew/lib:$LIBRARY_PATH"

  # GNU coreutils over macOS defaults
  export PATH="/opt/homebrew/opt/coreutils/libexec/gnubin:$PATH"

  # Python and Ruby version managers
  command -v pyenv &>/dev/null && eval "$(pyenv init -)"
  command -v rbenv &>/dev/null && eval "$(rbenv init -)"

  # Datadog devtools
  export PATH="$HOME/dd/devtools/bin:$PATH"

  # Gitsign
  command -v dd-gitsign &>/dev/null && eval "$(dd-gitsign load-key)"

  # Privilegesalias (Jamf managed)
  [ -f "$HOME/.privilegesalias" ] && source "$HOME/.privilegesalias"

  # SCFW
  alias npm="scfw run npm"
  alias pip="scfw run pip"
  alias poetry="scfw run poetry"
  export SCFW_DD_AGENT_LOG_PORT="10365"
  export SCFW_DD_LOG_LEVEL="ALLOW"
  export SCFW_HOME="$HOME/.scfw"

  # Yarn Switch
  [ -f "$HOME/.yarn/switch/env" ] && source "$HOME/.yarn/switch/env"
fi

# ── Linux/Workspace-only setup ───────────────────────────────────────────────
if $IS_LINUX; then
  # SSH agent forwarding socket
  [ -S "$HOME/.ssh/ssh_auth_sock" ] && export SSH_AUTH_SOCK="$HOME/.ssh/ssh_auth_sock"

  # Datadog devtools (workspace location)
  [ -d "$HOME/dd/devtools/bin" ] && export PATH="$HOME/dd/devtools/bin:$PATH"

  # Remove Volta from PATH — workspace Volta install is broken and
  # intercepts node/npm/claude. Use system node or install manually.
  export PATH=$(echo $PATH | tr ':' '\n' | grep -v volta | tr '\n' ':' | sed 's/:$//')

  # Note: dd-gitsign load-key is laptop-only. Workspace gets signing
  # via SSH agent forwarding automatically.
fi
