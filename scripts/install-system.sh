#!/usr/bin/env bash
set -euo pipefail
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
mkdir -p "$HOME/.local/bin"

if [[ "$(uname -s)" == Linux ]]; then
  command -v apt-get >/dev/null || { echo 'Install system dependencies manually on non-apt Linux.' >&2; exit 1; }
  sudo apt-get update -qq
  sudo apt-get install -y tmux fzf ripgrep fd-find xsel build-essential python3 unzip git curl ca-certificates
  if ! command -v fd >/dev/null && command -v fdfind >/dev/null; then
    ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
  fi
  if ! command -v nvim >/dev/null || ! nvim --headless -u NONE '+lua if vim.fn.has("nvim-0.11.3") == 0 then vim.cmd("cquit") end' +qa; then
    case "$(uname -m)" in
      x86_64) arch=x86_64 ;;
      aarch64|arm64) arch=arm64 ;;
      *) echo 'Unsupported Neovim architecture' >&2; exit 1 ;;
    esac
    tmp=$(mktemp -d)
    curl -fsSL "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-$arch.tar.gz" -o "$tmp/nvim.tar.gz"
    tar xzf "$tmp/nvim.tar.gz" -C "$tmp"
    mkdir -p "$HOME/.local/opt"
    # Keep old releases rather than deleting a possibly customized installation.
    release=$(mktemp -d "$HOME/.local/opt/nvim.XXXXXX")
    mv "$tmp/nvim-linux-$arch" "$release/nvim"
    ln -sf "$release/nvim/bin/nvim" "$HOME/.local/bin/nvim"
    rm -rf "$tmp"
  fi

  # Populate and verify the full editor before optional system-tool work.
  "$root/scripts/install-nvim.sh"

  # Preserve the local preference to build mosh when it is missing.
  if ! command -v mosh >/dev/null; then
    sudo apt-get install -y build-essential autoconf automake protobuf-compiler \
      libprotobuf-dev pkg-config libutempter-dev zlib1g-dev libncurses-dev libssl-dev
    tmp=$(mktemp -d)
    git clone https://github.com/keithw/mosh.git "$tmp/mosh"
    (cd "$tmp/mosh" && ./autogen.sh && ./configure --prefix="$HOME/.local" && make && make install)
    rm -rf "$tmp"
  fi

  if ! command -v delta >/dev/null; then
    case "$(uname -m)" in
      x86_64) arch=x86_64 ;;
      aarch64|arm64) arch=aarch64 ;;
      *) echo 'Unsupported delta architecture' >&2; exit 1 ;;
    esac
    tmp=$(mktemp -d)
    curl -fsSL "https://github.com/dandavison/delta/releases/download/0.18.2/delta-0.18.2-$arch-unknown-linux-gnu.tar.gz" -o "$tmp/delta.tar.gz"
    tar xzf "$tmp/delta.tar.gz" -C "$tmp"
    install -m 755 "$tmp/delta-0.18.2-$arch-unknown-linux-gnu/delta" "$HOME/.local/bin/delta"
    rm -rf "$tmp"
  fi
else
  echo 'macOS: existing system tools are left alone; install nvim, tmux, fzf, ripgrep, fd and git-delta with your package manager.'
  "$root/scripts/install-nvim.sh"
fi

if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  # Cloning does not rewrite the .zshrc link created by install.sh.
  git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
fi
if command -v tic >/dev/null; then
  tic -x "$root/terminfo/xterm-ghostty.terminfo"
fi

# Do not depend on a submodule: Workspaces migration copies files, not gitlinks.
export TMUX_PLUGIN_MANAGER_PATH="$HOME/.local/share/tmux/plugins/"
tpm="${TMUX_PLUGIN_MANAGER_PATH}tpm"
if [[ ! -e "$tpm" ]]; then
  git clone https://github.com/tmux-plugins/tpm "$tpm"
  git -C "$tpm" checkout --detach 99469c4a9b1ccf77fade25842dc7bafbc8ce9946
fi
# Clone the configured plugin without contacting/reconfiguring a running tmux
# server, which may still have the old TPM path until the user reloads config.
if [[ ! -e "${TMUX_PLUGIN_MANAGER_PATH}tmux-fzf-url" ]]; then
  git clone https://github.com/wfxr/tmux-fzf-url "${TMUX_PLUGIN_MANAGER_PATH}tmux-fzf-url"
fi

if ! command -v claude >/dev/null; then
  curl -fsSL https://claude.ai/install.sh | bash
fi
if ! command -v cargo >/dev/null; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
fi
if ! command -v claude-kanban >/dev/null; then
  cargo install --git https://github.com/alexanderbianchi/claude-kanban.git
fi
# No automatic cache deletion, branch switching, or background builds.
