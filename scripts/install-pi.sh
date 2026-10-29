#!/usr/bin/env bash
set -euo pipefail
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
agent_dir="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
export PI_CODING_AGENT_DIR="$agent_dir"
export PATH="$HOME/.local/bin:$agent_dir/bin:$PATH"
export GIT_TERMINAL_PROMPT=0
# Workspace sync may run without an interactive shell or forwarded socket env.
if [[ ! -S "${SSH_AUTH_SOCK:-}" && -S "$HOME/.ssh/ssh_auth_sock" ]]; then
  export SSH_AUTH_SOCK="$HOME/.ssh/ssh_auth_sock"
fi
command -v node >/dev/null || { echo 'Pi requires Node.js 22.19+ and npm on PATH.' >&2; exit 1; }
node -e 'const [major, minor] = process.versions.node.split(".").map(Number); if (major < 22 || (major === 22 && minor < 19)) { console.error("Pi requires Node.js 22.19+"); process.exit(1); }'

minimum=0.85.1
version=$(pi --version 2>/dev/null || true)
if ! node - "$version" "$minimum" <<'NODE'
const actual = process.argv[2].match(/^(\d+)\.(\d+)\.(\d+)$/)?.slice(1).map(Number);
const minimum = process.argv[3].split('.').map(Number);
if (!actual) process.exit(1);
for (let i = 0; i < 3; i++) {
  if (actual[i] !== minimum[i]) process.exit(actual[i] > minimum[i] ? 0 : 1);
}
NODE
then
  npm install --global --prefix "$HOME/.local" --ignore-scripts "@earendil-works/pi-coding-agent@$minimum"
fi

# Pin the authored package so every workspace gets the reviewed extensions.
source=$(<"$root/config/pi-package.txt")
package_root="$agent_dir/git/github.com/alexanderbianchi/pi-config"
if [[ -d "$package_root/.git" ]] && [[ -n "$(git -C "$package_root" status --porcelain)" ]]; then
  echo "Refusing to overwrite local Pi package edits in $package_root" >&2
  exit 1
fi
# Run from HOME so a project's .pi/settings.json/trust cannot affect provisioning.
(cd "$HOME" && pi install "$source")
# npm can rewrite this tracked lockfile for the workspace's platform/version.
# The checkout was clean above, so preserve this install-generated artifact and
# restore the pinned file; otherwise the next sync mistakes it for user edits.
if ! git -C "$package_root" diff --quiet -- package-lock.json; then
  mkdir -p "$agent_dir/dotfiles-backups"
  backup=$(mktemp -d "$agent_dir/dotfiles-backups/pi-lock.XXXXXX")
  cp "$package_root/package-lock.json" "$backup/package-lock.json"
  git -C "$package_root" restore -- package-lock.json
  printf 'Preserved npm-generated lockfile in %s\n' "$backup"
fi
[[ -x "$package_root/scripts/bootstrap.sh" ]] || { echo "Missing Pi bootstrap: $package_root" >&2; exit 1; }
(cd "$HOME" && "$package_root/scripts/bootstrap.sh")
