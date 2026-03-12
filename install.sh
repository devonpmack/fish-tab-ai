#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
FISH_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/fish"
INSTALL_DIR="$HOME/.local/share/fish-tab-ai"
MODEL="qwen2.5-coder:1.5b"

echo "Installing fish-tab-ai..."

# --- Prerequisites ---

command -v fish &>/dev/null || { echo "Error: fish not found. Run: brew install fish"; exit 1; }
command -v python3 &>/dev/null || { echo "Error: python3 not found."; exit 1; }
command -v ollama &>/dev/null || { echo "Error: ollama not found. Run: brew install ollama"; exit 1; }

# --- Pull model ---

if ! ollama list 2>/dev/null | grep -q "$MODEL"; then
    echo "Pulling model $MODEL..."
    ollama pull "$MODEL"
fi

# --- Install daemon ---

mkdir -p "$INSTALL_DIR"
cp -r "$REPO_DIR/daemon" "$INSTALL_DIR/"

# --- Symlink fish plugin ---

mkdir -p "$FISH_CONFIG/conf.d" "$FISH_CONFIG/functions"
ln -sf "$REPO_DIR/conf.d/fish_tab_ai.fish" "$FISH_CONFIG/conf.d/fish_tab_ai.fish"

for f in "$REPO_DIR"/functions/*.fish; do
    ln -sf "$f" "$FISH_CONFIG/functions/$(basename "$f")"
done

# --- State directory ---

mkdir -p ~/.local/state/fish-tab-ai

echo "Done! Open a new terminal to start using fish-tab-ai."
