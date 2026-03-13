#!/usr/bin/env bash
# Claude Cowork Linux — install / update
#
# First run: bootstraps from GitHub.
# Subsequent runs: updates the existing clone and re-runs the installer.
#
# All runtime dependencies (electron, asar, 7z, node, bwrap, python3)
# are provided by the skynet claude-cowork Nix module.

set -euo pipefail

INSTALL_DIR="$HOME/.local/share/claude-desktop"
SESSIONS_TARGET="$HOME/Library/Application Support/Claude/LocalAgentModeSessions/sessions"

if [[ -f "$INSTALL_DIR/install.sh" ]]; then
  echo "Existing installation found — updating…"
  git -C "$INSTALL_DIR" pull --ff-only 2>/dev/null \
    || echo "(local modifications present, skipping git pull)"
  bash "$INSTALL_DIR/install.sh" "$@"
else
  echo "No existing installation found — bootstrapping from GitHub…"
  bash <(curl -fsSL "https://raw.githubusercontent.com/johnzfitch/claude-cowork-linux/master/install.sh") "$@"
fi

# Remove the install.sh-generated launcher so the Nix profile one ($HOME/.nix-profile/bin/claude-desktop)
# takes precedence. The Nix wrapper does a proper `exec` into launch.sh rather than nohup+disown,
# which is required for Electron's single-instance IPC to work (OAuth callback routing).
echo "[INFO] Removing install.sh launchers — Nix wrapper will be used instead…"
rm -f "$HOME/.local/bin/claude-desktop"
rm -f "$HOME/.local/bin/claude-cowork"
echo "[OK] Done — use 'claude-desktop' from your Nix profile"

# Create /sessions symlink (required by Claude Code binary)
if [[ -L /sessions ]]; then
  echo "[OK] /sessions symlink already exists"
elif [[ -d /sessions ]]; then
  echo "[WARN] /sessions exists as a directory — skipping (expected a symlink)"
else
  echo "[INFO] Creating /sessions symlink (requires sudo)…"
  mkdir -p "$SESSIONS_TARGET"
  sudo ln -s "$SESSIONS_TARGET" /sessions
  echo "[OK] /sessions → $SESSIONS_TARGET"
fi
