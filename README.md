# fish-tab-ai

AI-powered ghost text completions for [fish shell](https://fishshell.com/). Uses a local LLM via [Ollama](https://ollama.com/) for fast, private suggestions.

As you type, the AI predicts the rest of your command and shows it inline after your cursor. Press **Tab** to accept, or keep typing to dismiss. Completions are context-aware -- the model sees your shell history and working directory.

## Requirements

- fish 4.0+
- Python 3.8+
- [Ollama](https://ollama.com/) (`brew install ollama`)

## Install

### With Fisher

```fish
fisher install devonpmack/fish-tab-ai
```

Then install the daemon:

```bash
cd ~/.local/share/fisher/github.com/devonpmack/fish-tab-ai
bash install.sh
```

### Manual

```bash
git clone https://github.com/devonpmack/fish-tab-ai.git
cd fish-tab-ai
chmod +x install.sh
./install.sh
```

## Usage

```fish
# Make sure Ollama is running
brew services start ollama

# Start the completion daemon
fish_tab_ai start

# Use a different model
fish_tab_ai start codellama:7b-code

# Check status
fish_tab_ai status

# Stop
fish_tab_ai stop
```

## Key bindings

| Key | Action |
|-----|--------|
| **Tab** | Accept full suggestion (or normal tab-complete if no suggestion) |
| **Right arrow** / **Ctrl+F** | Accept one character |
| **Ctrl+E** | Accept full suggestion |
| Any other key | Dismiss suggestion and continue typing |

## How it works

1. A Python daemon runs locally, connected to Ollama
2. On each keypress, the fish plugin writes the current buffer to a temp file (<0.1ms, zero process spawning)
3. The daemon's file watcher picks up the buffer, queries the LLM, and writes the result
4. On the next keypress, fish reads the result and displays ghost text
5. Client-side prefix caching gives instant suggestions for follow-up keystrokes (e.g. typing `git comm` → `it -m "..."`, then `git commi` instantly shows `t -m "..."` from cache)

**Key design property**: the fish key handler never spawns processes or makes network calls. All I/O is file reads/writes (<0.1ms). Typing is never blocked.

## Architecture

```
keypress → fish plugin ──write──→ /tmp/fish_tab_ai_buffer
                                      ↓ (daemon polls every 50ms)
keypress → fish plugin ──read───→ /tmp/fish_tab_ai_result
                ↓
        client-side prefix cache (instant)
```

## Configuration

Default model: `qwen2.5-coder:1.5b` (small, fast, good at code). Change with `fish_tab_ai start <model>`.

| Model | Speed | Quality |
|-------|-------|---------|
| `qwen2.5-coder:0.5b` | Fastest | Basic |
| `qwen2.5-coder:1.5b` | Fast | Good (default) |
| `qwen2.5-coder:7b` | Moderate | Better |
| `codellama:7b-code` | Moderate | Good for shell |
