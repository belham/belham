#!/usr/bin/env bash
# Install the commands onto your PATH so they run from any directory:
#   setup-qwen-ollama   download the model into Ollama and test it
#   claude-local        start Claude Code on the local model
#
# Usage: scripts/install.sh [BIN_DIR]   (default: ~/.local/bin)
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${1:-$HOME/.local/bin}"
mkdir -p "$BIN_DIR"

# Copies, not symlinks: the scripts are self-contained, so the repo can be
# moved or deleted afterwards.
install -m 755 "$SRC/setup-qwen-ollama.sh" "$BIN_DIR/setup-qwen-ollama"
install -m 755 "$SRC/claude-local.sh" "$BIN_DIR/claude-local"
echo "Installed setup-qwen-ollama and claude-local to $BIN_DIR"

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *)
    case "${SHELL##*/}" in
      zsh) RC="$HOME/.zshrc" ;;
      bash) [ "$(uname)" = Darwin ] && RC="$HOME/.bash_profile" || RC="$HOME/.bashrc" ;;
      *) RC="$HOME/.profile" ;;
    esac
    LINE="export PATH=\"$BIN_DIR:\$PATH\""
    if ! grep -qsF "$LINE" "$RC"; then
      printf '\n# Added by qwen-ollama install.sh\n%s\n' "$LINE" >>"$RC"
      echo "Added $BIN_DIR to PATH in $RC"
    fi
    echo "Open a new terminal (or run: source $RC) to use the commands."
    ;;
esac
