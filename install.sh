#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
FISH_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/fish"
INSTALL_DIR="$HOME/.local/share/fish-tab-ai"

echo "=== fish-tab-ai installer ==="

# --- Prerequisites ---

if ! command -v fish &>/dev/null; then
    echo "ERROR: fish shell not found. Install: brew install fish"
    exit 1
fi

if ! command -v python3 &>/dev/null; then
    echo "ERROR: python3 not found."
    exit 1
fi

if ! command -v ollama &>/dev/null; then
    echo "WARNING: Ollama not found. Install it: brew install ollama"
    echo "Continuing anyway..."
fi

# --- Pull model if needed ---

MODEL="${1:-qwen2.5-coder:1.5b}"
if command -v ollama &>/dev/null; then
    if ! ollama list 2>/dev/null | grep -q "$MODEL"; then
        echo "Pulling model $MODEL..."
        ollama pull "$MODEL"
    fi
fi

# --- Install daemon ---

mkdir -p "$INSTALL_DIR"
cp -r "$REPO_DIR/daemon" "$INSTALL_DIR/"
echo "Daemon installed to $INSTALL_DIR/daemon"

# --- Symlink fish plugin ---

mkdir -p "$FISH_CONFIG/conf.d" "$FISH_CONFIG/functions"
ln -sf "$REPO_DIR/conf.d/fish_tab_ai.fish" "$FISH_CONFIG/conf.d/fish_tab_ai.fish"

for f in "$REPO_DIR"/functions/*.fish; do
    ln -sf "$f" "$FISH_CONFIG/functions/$(basename "$f")"
done

echo "Fish plugin linked into $FISH_CONFIG"

# --- State directory ---

mkdir -p ~/.local/state/fish-tab-ai

echo ""
echo "Done! The daemon will auto-start in new Fish terminals."
echo ""
echo "  Manual control:"
echo "    fish_tab_ai start    - Start daemon + activate"
echo "    fish_tab_ai stop     - Stop daemon + deactivate"
echo "    fish_tab_ai restart  - Restart daemon"
echo "    fish_tab_ai status   - Check status"
echo ""
echo "  Usage:"
echo "    Type commands -- ghost text appears as you type"
echo "    Tab            Accept full suggestion"
echo "    Right arrow    Accept one character"
echo "    Ctrl+E         Accept full suggestion"
