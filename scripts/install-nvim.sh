#!/usr/bin/env bash
# Provision the editor, not just its executable. Safe to run again after failure.
set -euo pipefail
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
if [[ ! -S "${SSH_AUTH_SOCK:-}" && -S "$HOME/.ssh/ssh_auth_sock" ]]; then
  export SSH_AUTH_SOCK="$HOME/.ssh/ssh_auth_sock"
fi
[[ "${NVIM_APPNAME:-nvim}" == nvim ]] || { echo 'Unset NVIM_APPNAME before provisioning the standard nvim setup.' >&2; exit 1; }
for tool in nvim node git make cc go java; do
  command -v "$tool" >/dev/null || { echo "Neovim provisioning requires $tool on PATH." >&2; exit 1; }
done

state="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
data="${XDG_DATA_HOME:-$HOME/.local/share}/nvim"
mkdir -p "$state/logs" "$data/lazy"
guard="$data/.dotfiles-install-lock"
mkdir "$guard" 2>/dev/null || { echo "Neovim provisioning already running (or stale lock: $guard)." >&2; exit 1; }
work=''
cleanup() {
  [[ -z "$work" ]] || rm -rf "$work"
  rmdir "$guard"
}
trap cleanup EXIT
work=$(mktemp -d)
logs=$(mktemp -d "$state/logs/nvim.XXXXXX")
lock="$root/.config/nvim/lazy-lock.json"
# Validate before touching any plugin checkout. Never reset local plugin edits.
node - "$lock" > "$work/pins" <<'JS'
const pins = require(process.argv[2]);
if (!pins['lazy.nvim']) throw new Error('Missing lazy.nvim pin');
for (const [name, {commit}] of Object.entries(pins)) {
  if (!/^[a-zA-Z0-9_.-]+$/.test(name) || !/^[a-f0-9]{40}$/.test(commit)) throw new Error(`Invalid plugin pin: ${name}`);
  console.log(`${name} ${commit}`);
}
JS
while read -r name commit; do
  dir="$data/lazy/$name"
  if [[ -e "$dir" ]]; then
    [[ -e "$dir/.git" ]] || { echo "Not a managed plugin checkout: $dir" >&2; exit 1; }
    changes=$(git -C "$dir" status --porcelain)
    while IFS= read -r change; do
      # Neovim generates help tags even for plugins that forgot to gitignore it.
      [[ -z "$change" || "$change" == '?? doc/tags' ]] || { echo "Refusing to overwrite Neovim plugin edits: $dir" >&2; exit 1; }
    done <<< "$changes"
  fi
  if [[ "$name" == lazy.nvim ]]; then manager_pin="$commit"; fi
done < "$work/pins"
manager="$data/lazy/lazy.nvim"
if [[ ! -e "$manager" ]]; then
  git clone --filter=blob:none https://github.com/folke/lazy.nvim.git "$manager" > "$logs/manager.log" 2>&1 || { tail -60 "$logs/manager.log"; exit 1; }
fi
if [[ "$(git -C "$manager" rev-parse HEAD)" != "$manager_pin" ]]; then
  git -C "$manager" cat-file -e "$manager_pin^{commit}" 2>/dev/null || git -C "$manager" fetch origin "$manager_pin"
  git -C "$manager" checkout --detach "$manager_pin"
fi

export DOTFILES_NVIM_ROOT="$root"
export DOTFILES_NVIM_BOOTSTRAP=1
# Lazy writes its lockfile during installs. Give it a disposable copy so neither
# failures nor repeat installs can dirty the public/shared source checkout.
export DOTFILES_NVIM_LOCKFILE="$work/lazy-lock.json"
for phase in plugins verify; do
  cp "$lock" "$DOTFILES_NVIM_LOCKFILE"
  export DOTFILES_NVIM_PHASE="$phase"
  export DOTFILES_NVIM_SUCCESSFILE="$work/$phase.ok"
  if ! nvim --headless -i NONE -u "$root/.config/nvim/init.lua" \
    --cmd "lua vim.opt.rtp:prepend(vim.env.DOTFILES_NVIM_ROOT .. '/.config/nvim'); dofile(vim.env.DOTFILES_NVIM_ROOT .. '/scripts/nvim-bootstrap.lua')" \
    > "$logs/$phase.log" 2>&1; then
    tail -80 "$logs/$phase.log" >&2
    echo "Neovim provisioning failed; logs: $logs" >&2
    exit 1
  fi
  [[ -f "$DOTFILES_NVIM_SUCCESSFILE" ]] || { echo "Neovim $phase checks did not complete; logs: $logs" >&2; exit 1; }
done
printf 'Neovim plugins, language tools, parsers and startup checks passed. Logs: %s\n' "$logs"
