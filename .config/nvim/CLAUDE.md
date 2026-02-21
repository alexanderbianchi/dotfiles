# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a Neovim configuration based on kickstart.nvim - a starting point for Neovim that is small, single-file, and completely documented. It's NOT a distribution but rather a foundation for personal configuration.

## Architecture

The configuration follows a modular structure:

- **init.lua**: Main configuration file containing all core settings, key mappings, autocommands, and plugin definitions using lazy.nvim
- **lua/custom/**: Custom user configurations and extensions
  - `plugins/init.lua`: Entry point for custom plugins
  - `terminal.lua`: Enhanced terminal functionality with splits, floating terminal, and code sending
- **lua/kickstart/**: Optional example plugins (commented out by default)
  - `health.lua`: Health check functionality
  - `plugins/`: Collection of optional plugins (autopairs, debug, gitsigns, indent_line, lint, neo-tree)

## Plugin Management

Uses lazy.nvim as the plugin manager. Plugin specifications are defined in init.lua:248.

### Core Plugins Installed:
- **guess-indent.nvim**: Automatic tabstop/shiftwidth detection
- **which-key.nvim**: Keybinding help and discovery
- **telescope.nvim**: Fuzzy finder for files, LSP, grep, etc.
- **nvim-lspconfig + mason**: LSP configuration and management
- **conform.nvim**: Code formatting
- **blink.cmp**: Completion engine
- **tokyonight.nvim**: Colorscheme
- **todo-comments.nvim**: Highlight TODO/NOTE/etc in comments
- **mini.nvim**: Collection of small utilities (ai, surround, statusline)
- **nvim-treesitter**: Syntax highlighting and code understanding
- **neo-tree.nvim**: File explorer/tree

### Custom Enhanced Plugins:
- **Enhanced Terminal Management**: 
  - Toggle terminals with persistence (`<leader>th`, `<leader>tv`, `<leader>tf`)
  - Legacy compatibility (`<leader>vh`, `<leader>vv`, `<leader>vf`)
  - Code sending to terminal (`<leader>sl` for line, `<leader>ss` for selection)
- **Git Integration**:
  - **git-blame.nvim**: Inline git blame with virtual text
  - **Enhanced gitsigns.nvim**: Git gutter signs with comprehensive hunk management

## Key Bindings

Leader key is set to space (`<space>`).

### Core Navigation:
- `<C-h/j/k/l>`: Window navigation
- `<space>sh`: Search help
- `<space>sk`: Search keymaps
- `<space>sf`: Search files
- `<space>sg`: Live grep
- `<space>/`: Fuzzy search in current buffer

### LSP:
- `grn`: Rename symbol
- `gra`: Code actions
- `grr`: Find references
- `grd`: Go to definition
- `grt`: Go to type definition

### File Tree (Neo-tree):
- `\`: Toggle Neo-tree file explorer
- Within Neo-tree: `\` to close

### Terminal (Enhanced):
- `<leader>th`: Toggle horizontal terminal (new preferred)
- `<leader>tv`: Toggle vertical terminal (new preferred) 
- `<leader>tf`: Toggle floating terminal (new preferred)
- `<leader>vh`: Horizontal terminal split (legacy)
- `<leader>vv`: Vertical terminal split (legacy)
- `<leader>vf`: Floating terminal (legacy)
- `<leader>sl`: Send current line to terminal
- `<leader>ss`: Send visual selection to terminal

### Git Integration:
- `<leader>gb`: Toggle git blame
- `<leader>go`: Open commit URL in browser
- `<leader>gc`: Copy commit SHA to clipboard
- `<leader>gf`: Open file URL in browser
- `<leader>hs`: Stage current hunk
- `<leader>hr`: Reset current hunk
- `<leader>hp`: Preview hunk diff
- `<leader>hb`: Show line blame popup
- `]c` / `[c`: Navigate to next/previous git hunk

## Development Commands

### Plugin Management:
- `:Lazy`: View plugin status and manage plugins
- `:Lazy update`: Update all plugins
- `:Mason`: Manage LSP servers and tools
- `:checkhealth`: Run health checks

### File Tree:
- `:Neotree`: Open file tree
- `:Neotree reveal`: Open and reveal current file
- `:Neotree close`: Close file tree

### Git Commands:
- `:GitBlameToggle`: Toggle git blame display
- `:GitBlameOpenCommitURL`: Open current line's commit in browser
- `:Gitsigns preview_hunk`: Preview current hunk changes

### LSP and Formatting:
- `<leader>f`: Format current buffer with conform.nvim
- `:ConformInfo`: View conform.nvim status

### Telescope:
All telescope commands are prefixed with `<leader>s`:
- `<leader>sf`: Find files
- `<leader>sg`: Live grep
- `<leader>sw`: Search current word
- `<leader>sd`: Search diagnostics
- `<leader>sr`: Resume last search

## Configuration Patterns

### Adding New Plugins:
Add plugin specifications to the lazy.setup() table in init.lua:248. Use the pattern:
```lua
{
  'author/plugin-name',
  opts = {}, -- or config = function() ... end
  dependencies = { ... },
  keys = { ... }, -- lazy loading keybinds
}
```

### Custom Configuration:
- Add personal keymaps/logic to `lua/custom/terminal.lua` or create new files
- Custom plugins go in `lua/custom/plugins/`
- The custom directory is protected from merge conflicts

### LSP Configuration:
LSP servers are configured in the `servers` table at init.lua:673. Currently only lua_ls is configured. To add more:
```lua
servers = {
  lua_ls = { ... },
  -- Add new servers here
  pyright = {},
  ts_ls = {},
}
```

## External Dependencies

Required tools (checked by `:checkhealth`):
- git, make, unzip, ripgrep (rg)
- C compiler for some plugins
- fd-find for telescope
- Nerd Font (optional, controlled by `vim.g.have_nerd_font`)

## File Structure Notes

- `lazy-lock.json`: Plugin version lockfile (modify .gitignore to track this)
- Optional kickstart plugins in `lua/kickstart/plugins/` are available but not loaded by default
- Health check functionality available via `lua/kickstart/health.lua`