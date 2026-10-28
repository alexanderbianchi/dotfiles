# Use system Node in Linux workspaces; the laptop uses Volta.
if [[ "$(uname -s)" == Darwin ]]; then
  export VOLTA_HOME="$HOME/.volta"
  export PATH="$VOLTA_HOME/bin:$PATH"
fi
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
