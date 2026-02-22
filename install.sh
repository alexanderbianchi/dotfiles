#!/usr/bin/env bash
# Dotfiles install script for Datadog Workspaces
# This runs automatically during workspace creation when an install.sh is present.
# It replaces the default symlinking behavior, so we handle symlinking ourselves.

set -euo pipefail

DOTFILES_PATH="$HOME/dotfiles"

echo "==> Installing dotfiles from $DOTFILES_PATH"

# ── Step 1: Symlink dotfiles to home directory ───────────────────────────────
echo "==> Symlinking dotfiles..."
# Symlink root-level dotfiles (skip .config — handled separately below)
find "$DOTFILES_PATH" -maxdepth 1 -name '.*' -not -name '.git' -not -name '.gitignore' -not -name '.config' |
while read -r df; do
  basename=$(basename "$df")
  target="$HOME/$basename"
  if [ -e "$target" ] || [ -L "$target" ]; then
    echo "    Backing up existing $target -> ${target}.bak"
    mv "$target" "${target}.bak" 2>/dev/null || true
  fi
  ln -sf "$df" "$target"
  echo "    Linked $basename"
done

# Symlink .config subdirectories (nvim, gh, gitsign)
for config_dir in nvim gh gitsign; do
  src="$DOTFILES_PATH/.config/$config_dir"
  dest="$HOME/.config/$config_dir"
  if [ -d "$src" ]; then
    mkdir -p "$HOME/.config"
    if [ -e "$dest" ] || [ -L "$dest" ]; then
      echo "    Backing up existing $dest -> ${dest}.bak"
      mv "$dest" "${dest}.bak" 2>/dev/null || true
    fi
    ln -sf "$src" "$dest"
    echo "    Linked .config/$config_dir"
  fi
done

# ── Step 2: Install Oh My Zsh ────────────────────────────────────────────────
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  echo "==> Installing Oh My Zsh..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended || true
else
  echo "==> Oh My Zsh already installed"
fi

# ── Step 3: Install system packages ──────────────────────────────────────────
install_if_missing() {
  local cmd="$1"
  local pkg="${2:-$1}"
  if ! command -v "$cmd" &>/dev/null; then
    echo "    Installing $pkg..."
    sudo apt-get install -y "$pkg" 2>/dev/null || true
  else
    echo "    $cmd already available"
  fi
}

echo "==> Checking system packages..."
sudo apt-get update -qq 2>/dev/null || true
install_if_missing nvim neovim
install_if_missing tmux tmux
install_if_missing fzf fzf
install_if_missing rg ripgrep
install_if_missing fd fd-find
install_if_missing xsel xsel
install_if_missing make make
install_if_missing unzip unzip

# Install delta (git-delta) - not in standard apt repos, use cargo or download
if ! command -v delta &>/dev/null; then
  echo "    Installing git-delta..."
  # Try downloading a prebuilt binary
  DELTA_VERSION="0.18.2"
  ARCH=$(uname -m)
  if [ "$ARCH" = "x86_64" ]; then
    DELTA_ARCH="x86_64-unknown-linux-gnu"
  elif [ "$ARCH" = "aarch64" ]; then
    DELTA_ARCH="aarch64-unknown-linux-gnu"
  else
    DELTA_ARCH="x86_64-unknown-linux-gnu"
  fi
  curl -fsSL "https://github.com/dandavison/delta/releases/download/${DELTA_VERSION}/delta-${DELTA_VERSION}-${DELTA_ARCH}.tar.gz" | \
    tar xz -C /tmp/
  sudo mv "/tmp/delta-${DELTA_VERSION}-${DELTA_ARCH}/delta" /usr/local/bin/delta 2>/dev/null || \
    mv "/tmp/delta-${DELTA_VERSION}-${DELTA_ARCH}/delta" "$HOME/.local/bin/delta"
  echo "    delta installed"
else
  echo "    delta already available"
fi

# ── Step 4: Install Rust/Cargo ────────────────────────────────────────────────
if ! command -v cargo &>/dev/null; then
  echo "==> Installing Rust toolchain..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  source "$HOME/.cargo/env"
else
  echo "==> Rust toolchain already installed"
fi

# ── Step 5: Install claude-kanban ─────────────────────────────────────────────
if ! command -v claude-kanban &>/dev/null; then
  echo "==> Installing claude-kanban..."
  cargo install --git https://github.com/alexanderbianchi/claude-kanban.git 2>&1 || \
    echo "    Warning: claude-kanban install failed. You may need to install it manually."
else
  echo "==> claude-kanban already installed"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "==> Dotfiles installation complete!"
echo "    Restart your shell or run: source ~/.zshrc"
