#!/usr/bin/env bash
# Shared by the public dotfiles repo and users/alex.bianchi in Workspaces.
set -euo pipefail

DOTFILES_PATH=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
export PATH="$HOME/.local/bin:$HOME/.pi/agent/bin:$HOME/.cargo/bin:$PATH"
mode="${1:-}"
case "$mode" in
  ''|--links-only|--pi-only) ;;
  *) printf 'Usage: %s [--links-only|--pi-only]\n' "$0" >&2; exit 2 ;;
esac

# Preserve conflicts once; repeated syncs leave correct links alone. Never link
# a whole agent or gh directory over its credentials, sessions, or runtime data.
link_file() {
  local src="$1" dest="$2" backup
  [[ -e "$src" ]] || return 0
  if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  if [[ -e "$dest" || -L "$dest" ]]; then
    mkdir -p "$HOME/.local/state/dotfiles/backups"
    backup=$(mktemp -d "$HOME/.local/state/dotfiles/backups/conflict.XXXXXX")
    mv "$dest" "$backup/$(basename "$dest")"
    printf 'Preserved %s in %s\n' "$dest" "$backup"
  fi
  ln -s "$src" "$dest"
}

if [[ "$mode" != --pi-only ]]; then
  for name in .zshrc .zshenv .inputrc .gitconfig .gitignore_global .tmux.conf .bazelrc; do
    link_file "$DOTFILES_PATH/$name" "$HOME/$name"
  done
  link_file "$DOTFILES_PATH/.config/nvim" "$HOME/.config/nvim"
  link_file "$DOTFILES_PATH/.config/gh/config.yml" "$HOME/.config/gh/config.yml"
  link_file "$DOTFILES_PATH/.config/ghostty/config" "$HOME/.config/ghostty/config"
  if [[ "$(uname -s)" == Darwin ]]; then
    link_file "$DOTFILES_PATH/.config/ghostty/config" "$HOME/Library/Application Support/com.mitchellh.ghostty/config"
  fi
  [[ "$mode" == --links-only ]] && exit 0
  "$DOTFILES_PATH/scripts/install-system.sh"
fi

# Pi installation is part of normal workspace creation AND dotfiles sync.
# Errors propagate rather than claiming a successful install without extensions.
"$DOTFILES_PATH/scripts/install-pi.sh"

# Only the company-owned copy contains this overlay (gateway, internal skills,
# work shell settings, and optional Trajectory registration).
if [[ -x "$DOTFILES_PATH/scripts/install-work.sh" ]]; then
  "$DOTFILES_PATH/scripts/install-work.sh"
fi
printf 'Dotfiles installed. Restart your shell; authenticate in Pi with /login.\n'
