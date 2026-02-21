# dotfiles

Personal dotfiles for Datadog Workspaces (also works on macOS).

## What's included

- **zsh** - Oh My Zsh with robbyrussell theme, vi mode, custom aliases and functions
- **neovim** - Kickstart.nvim-based config with LSP, Telescope, Treesitter, Git integration, Claude Code integration
- **tmux** - Vim-like navigation, mouse support, vi copy mode
- **git** - Delta pager, gitsign commit signing, diff3 merge style
- **claude-kanban** - Terminal UI kanban board for Claude Code sessions (installed via cargo)
- **gh** - GitHub CLI config

## Usage with Workspaces

```bash
workspaces create <name> --dotfiles https://github.com/alexanderbianchi/dotfiles --shell zsh
```

Or save in `~/.config/datadog/workspaces/config.yaml`:

```yaml
shell: zsh
dotfiles: https://github.com/alexanderbianchi/dotfiles
```

## What install.sh does

1. Symlinks all dotfiles to the home directory
2. Installs Oh My Zsh (if not present)
3. Installs system packages: neovim, tmux, fzf, ripgrep, fd-find, delta, xsel
4. Installs Rust toolchain (if not present)
5. Builds and installs claude-kanban from source

## Platform support

The `.zshrc` includes platform detection (`uname`) so it works on both macOS and Linux workspaces. macOS-specific items (Homebrew, pyenv, SCFW, etc.) are conditionally loaded.
