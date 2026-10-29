#!/usr/bin/env bash
# Shared by the public dotfiles repo and users/alex.bianchi in Workspaces.
set -euo pipefail

DOTFILES_PATH=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
export PATH="$HOME/.local/bin:$HOME/.pi/agent/bin:$HOME/.cargo/bin:$PATH"
# Provisioning is noninteractive; make forwarded credentials available to every
# phase, including Git/Cargo in system setup, not just the Pi bootstrap.
if [[ ! -S "${SSH_AUTH_SOCK:-}" && -S "$HOME/.ssh/ssh_auth_sock" ]]; then
  export SSH_AUTH_SOCK="$HOME/.ssh/ssh_auth_sock"
fi
mode="${1:-}"
case "$mode" in
  ''|--links-only|--pi-only) ;;
  *) printf 'Usage: %s [--links-only|--pi-only]\n' "$0" >&2; exit 2 ;;
esac

backup_path() {
  local dest="$1" backup
  if [[ -e "$dest" || -L "$dest" ]]; then
    mkdir -p "$HOME/.local/state/dotfiles/backups"
    backup=$(mktemp -d "$HOME/.local/state/dotfiles/backups/conflict.XXXXXX")
    mv "$dest" "$backup/$(basename "$dest")"
    printf 'Preserved %s in %s\n' "$dest" "$backup"
  fi
}

# Never replace a file through a parent symlink when it resolves to the source.
link_file() {
  local src="$1" dest="$2"
  [[ -e "$src" ]] || return 0
  [[ "$dest" -ef "$src" ]] && return 0
  mkdir -p "$(dirname "$dest")"
  backup_path "$dest"
  ln -s "$src" "$dest"
}

copy_shell_rc() {
  local src="$DOTFILES_PATH/.zshrc" dest="$HOME/.zshrc"
  [[ -f "$src" ]] || return 0
  # A writable local copy prevents shell-hook installers from dirtying the
  # shared checkout and blocking its next git pull. Preserve any local edits.
  if [[ ! -L "$dest" ]] && cmp -s "$src" "$dest"; then return 0; fi
  backup_path "$dest"
  cp -p "$src" "$dest"
}

materialize_gh_directory() {
  local dest="$HOME/.config/gh" temporary
  if [[ -L "$dest" ]]; then
    [[ -d "$dest" ]] || { echo "Dangling gh directory: $dest" >&2; return 1; }
    temporary=$(mktemp -d "$HOME/.config/.gh.XXXXXX")
    # Earlier installers linked this whole directory. Copy its contents locally
    # (including hosts.yml and its permissions) before replacing that link.
    cp -a "$dest/." "$temporary/"
    backup_path "$dest"
    mv "$temporary" "$dest"
  fi
}

if [[ "$mode" != --pi-only ]]; then
  copy_shell_rc
  for name in .zshenv .inputrc .gitignore_global .tmux.conf .bazelrc; do
    link_file "$DOTFILES_PATH/$name" "$HOME/$name"
  done
  # The platform's wrapper already includes our personal .gitconfig. Keep its
  # authentication/account routing in place while provisioning runs.
  if [[ ! -f "$HOME/.gitconfig" ]] || ! grep -q '^# Managed by workspaces' "$HOME/.gitconfig"; then
    link_file "$DOTFILES_PATH/.gitconfig" "$HOME/.gitconfig"
  fi
  link_file "$DOTFILES_PATH/.config/nvim" "$HOME/.config/nvim"
  materialize_gh_directory
  link_file "$DOTFILES_PATH/.config/gh/config.yml" "$HOME/.config/gh/config.yml"
  link_file "$DOTFILES_PATH/.config/ghostty/config" "$HOME/.config/ghostty/config"
  if [[ "$(uname -s)" == Darwin ]]; then
    link_file "$DOTFILES_PATH/.config/ghostty/config" "$HOME/Library/Application Support/com.mitchellh.ghostty/config"
  fi
  [[ "$mode" == --links-only ]] && exit 0
fi

# Pi installation is part of normal workspace creation AND dotfiles sync.
# Errors propagate rather than claiming a successful install without extensions.
"$DOTFILES_PATH/scripts/install-pi.sh"

# Only the company-owned copy contains this overlay (gateway, internal skills,
# work shell settings, and optional Trajectory registration).
if [[ -x "$DOTFILES_PATH/scripts/install-work.sh" ]]; then
  "$DOTFILES_PATH/scripts/install-work.sh"
fi
# Slow/optional developer tools must not prevent the required Pi setup.
if [[ "$mode" != --pi-only ]]; then
  "$DOTFILES_PATH/scripts/install-system.sh"
fi
printf 'Dotfiles installed. Restart your shell; authenticate in Pi with /login.\n'
