# dotfiles

Portable personal shell, Neovim, tmux, Ghostty, Git and Pi configuration.
Company-only settings live separately in `DataDog/workspaces-dotfiles`.

## Install

Requires Bash, Git, Node.js 22.19+ and npm. Linux system setup currently uses apt;
macOS system tools are left to your package manager.

```bash
git clone https://github.com/alexanderbianchi/dotfiles ~/dotfiles
~/dotfiles/install.sh
```

The installer:

1. Links an explicit list of configuration files, preserving conflicts under
   `~/.local/state/dotfiles/backups`. Repeated installs keep correct links alone.
   Only `gh/config.yml` is linked, never `gh/hosts.yml` or an entire agent directory.
2. Installs Linux tools, Oh My Zsh, Ghostty terminfo and TPM. TPM is cloned to
   `~/.local/share/tmux/plugins/tpm` instead of relying on a Git submodule.
3. Installs Pi 0.85.1 when Pi is missing/older, preserving newer versions. Installs
   the pinned private package in `config/pi-package.txt`, then **runs its bootstrap
   to install the full extension and skill set**. GitHub SSH access to
   `alexanderbianchi/pi-config` is required. Failures stop the installer.
4. Runs `scripts/install-work.sh` only when the company-owned overlay is present.

Pi includes copy-friendly output, Herdr integration, an MCP bridge, subagents,
worktrees, Markdown preview/tree, render-btw, Herdr aside, Vim mode, Go/Rust skills,
and ketch. Credentials and sessions stay local; use Pi's `/login` on a new machine.
Herdr/Trajectory binaries are managed separately, not bundled here.

```bash
# Link configuration without network/package installation:
~/dotfiles/install.sh --links-only
# Install/reconcile Pi and the optional work overlay only:
~/dotfiles/install.sh --pi-only
```

There are **no automatic cache deletions, branch switches, or background builds**.
Old cron jobs from earlier versions are not silently changed: review `crontab -l`
and remove the old weekly cleanup/daily build jobs manually if they were installed.

## Workspaces

`workspaces dotfiles migrate <URL>` is a one-time copy, not a continuous GitHub
sync. The company-owned copy also carries private work configuration, so subsequent
updates should copy the public files while preserving that overlay and open a
**draft PR** under `users/alex.bianchi/`.

After that PR merges:

```bash
workspaces dotfiles sync <workspace-name>
```

Both workspace creation and sync run `install.sh`, including Pi extension
installation. `--pi-only` can retry that step after fixing GitHub authentication.

## Local customization

- `.zshrc.local`: machine-specific overrides and credential-loading commands.
- `.gitconfig.local`: local identity/signing/credential helpers. Workspaces manages
  its own signing configuration; this repo does not force laptop signing keys.
- `.zshrc.work`: installed only by the company overlay.

Neovim includes notes (`<leader>n`), package tests (`<leader>w`, `go test .` for Go
modules), diagnostic popups and Ghostty comment keybindings. `gopls` is resolved
from PATH. No notes, repository contents or credentials are included.

## Tests

```bash
python3 -m unittest discover -s tests -v
```

Installer tests use temporary homes and mocked provisioning commands. They never
install tools into your real home or modify running workspaces.
