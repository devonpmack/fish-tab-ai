# fish-tab-ai

Cursor tab style AI-powered inline completions for [Fish shell](https://fishshell.com/). Ghost text suggestions appear as you type, powered by a local LLM via [Ollama](https://ollama.com/). Fully private -- nothing leaves your machine.

## Install

### With Fisher (recommended)

```fish
brew install ollama
fisher install devonpmack/fish-tab-ai
```

### Manual

```bash
brew install ollama
git clone https://github.com/devonpmack/fish-tab-ai.git
cd fish-tab-ai
bash install.sh
```

Open a new terminal. That's it -- Ollama, the model, and the daemon all start automatically.

## Keys

| Key | Action |
|-----|--------|
| **Tab** | Accept suggestion |
| **Right arrow** | Accept one character |
| **Ctrl+E** | Accept full suggestion |
| Any other key | Dismiss and keep typing |

## What It Does

- **While typing**: completes your partial command based on shell history
- **Empty prompt**: predicts your next command based on what you just ran
- **Failed commands**: tracks exit codes so it can suggest fixes

## Changing the Model

The default model is `qwen2.5-coder:1.5b`. To switch:

```fish
fish_tab_ai restart <model>
```

| Model | Size | Speed | Quality |
|-------|------|-------|---------|
| `qwen2.5-coder:1.5b` | ~1 GB | Fastest | Good for common commands |
| `qwen2.5-coder:3b` | ~2 GB | Fast | Better context understanding |
| `qwen2.5-coder:7b` | ~4 GB | Moderate | Best suggestions |
| `codellama:7b` | ~4 GB | Moderate | Good for general coding |
| `deepseek-coder-v2:lite` | ~9 GB | Slower | High quality completions |

Any [Ollama model](https://ollama.com/library) works -- it will be pulled automatically on first use.

## Commands

```fish
fish_tab_ai status   # Check if running
fish_tab_ai restart  # Restart the daemon
fish_tab_ai stop     # Disable
fish_tab_ai start    # Re-enable
```

## Architecture

```
Fish Plugin  ──── file IPC ────  Python Daemon  ────  Ollama (local LLM)
  (key bindings,   /tmp/fish_tab_*   (async inference,     (qwen2.5-coder:1.5b)
   ghost text)     + SIGUSR1          history context,
                                      prefix caching)
```

Zero process spawning on keypress. Fish writes to a temp file using builtins; the daemon picks it up, queries Ollama in a thread pool, and signals Fish when the result is ready.

## Troubleshooting

```fish
# Not seeing suggestions?
fish_tab_ai status        # Is the daemon running?
ollama list               # Is the model downloaded?
fish_tab_ai restart       # Try restarting

# Slow suggestions?
# The default model (qwen2.5-coder:1.5b) is optimized for speed.
# Ollama starts automatically, but you can check: ollama list
```

## Uninstall

```fish
fish_tab_ai stop
rm -rf ~/.local/share/fish-tab-ai ~/.local/state/fish-tab-ai
rm ~/.config/fish/conf.d/fish_tab_ai.fish
rm ~/.config/fish/functions/*fish_tab_ai*.fish
```

## License

MIT
