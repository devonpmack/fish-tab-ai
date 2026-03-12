# fish-tab-ai

AI-powered inline completions for [Fish shell](https://fishshell.com/), similar to Cursor/Copilot ghost text in your terminal. Uses a local LLM via [Ollama](https://ollama.com/) for fast, private suggestions.

![demo](https://img.shields.io/badge/shell-fish-blue)

## Features

- **Inline ghost text** -- dimmed suggestions appear as you type, just like native Fish autosuggestions
- **Next-command prediction** -- predicts what you'll run next on an empty prompt, based on recent commands
- **Local & private** -- runs entirely on your machine via Ollama, no data leaves your computer
- **Non-blocking** -- file-based IPC with async inference; never freezes your terminal
- **History-aware** -- uses your Fish and Bash history for smarter completions
- **Error-aware** -- tracks failed commands (exit codes) to suggest fixes
- **Auto-start** -- daemon starts automatically in new terminals
- **Zero dependencies** -- only requires Python 3 and Ollama (no pip packages)

## How It Works

```
You type:  git co
Ghost text:        mmit -m "
           ^^^^^^^^^^^^^^^^ dimmed gray text
Press Tab to accept, or keep typing to dismiss.
```

After running a command, a prediction for the next command appears on the fresh prompt:

```
$ git status
$ git add .
$ git commit -m "fix bug"   <-- prediction appears here (dimmed)
```

## Requirements

- **Fish** >= 4.0
- **Python** >= 3.8
- **Ollama** with a code model (default: `qwen2.5-coder:1.5b`)
- **macOS** or Linux

## Installation

### Quick Install

```bash
git clone https://github.com/devonpmack/fish-tab-ai.git
cd fish-tab-ai
bash install.sh
```

The installer will:
1. Check prerequisites (Fish, Python, Ollama)
2. Pull the AI model if needed
3. Install the daemon to `~/.local/share/fish-tab-ai/`
4. Symlink the Fish plugin into your Fish config
5. Set up auto-start

Open a new terminal and start using it -- the daemon auto-starts.

### Custom Model

```bash
bash install.sh qwen2.5-coder:7b
```

Or change the model at runtime:

```fish
fish_tab_ai restart qwen2.5-coder:7b
```

## Usage

### Key Bindings

| Key | Action |
|-----|--------|
| **Tab** | Accept full AI suggestion (falls back to normal tab complete) |
| **Right arrow** | Accept one character |
| **Ctrl+F** | Accept one character |
| **Ctrl+E** | Accept full suggestion (falls back to end-of-line) |
| Any key | Dismiss suggestion and continue typing |

### Commands

```fish
fish_tab_ai start           # Start daemon and activate
fish_tab_ai stop            # Stop daemon and deactivate
fish_tab_ai restart         # Restart daemon (picks up code changes)
fish_tab_ai restart <model> # Restart with a different model
fish_tab_ai status          # Check if daemon is running
```

### How Suggestions Work

1. **While typing**: The AI completes your partial command based on your shell history
2. **Empty prompt**: After running a command, the AI predicts what you'll run next based on your recent command sequence and whether previous commands succeeded or failed

## Architecture

```
┌─────────────────────┐     file IPC      ┌──────────────────┐
│  Fish Shell Plugin  │ ───────────────── │  Python Daemon   │
│                     │  /tmp/fish_tab_*  │                  │
│  - Key bindings     │ ◄──── SIGUSR1 ──── │  - FileWatcher   │
│  - Ghost text       │                   │  - Completer     │
│  - Accept/dismiss   │                   │  - History parser│
└─────────────────────┘                   │  - Ollama client │
                                          └──────────────────┘
                                                  │
                                                  ▼
                                          ┌──────────────────┐
                                          │  Ollama (local)  │
                                          │  LLM inference   │
                                          └──────────────────┘
```

- **Zero process spawning on keypress**: Fish writes to a temp file using builtins (`printf`), no `curl` or subprocess calls
- **Async inference**: The daemon runs Ollama queries in a thread pool; results arrive via `SIGUSR1` signal
- **Prefix caching**: If you typed `git co` and got a suggestion, typing `git com` instantly shows the cached remainder
- **History context**: The LLM sees relevant commands from your Fish/Bash history for better predictions

## Configuration

The default model is `qwen2.5-coder:1.5b` (fast, ~1GB RAM). For better suggestions at the cost of speed:

```fish
fish_tab_ai restart qwen2.5-coder:7b    # Better quality, slower
fish_tab_ai restart qwen2.5-coder:3b    # Middle ground
```

The daemon runs on port **62019** on localhost.

## Files

| Path | Purpose |
|------|---------|
| `~/.local/share/fish-tab-ai/daemon/` | Python daemon (server, completer, history parser) |
| `~/.config/fish/conf.d/fish_tab_ai.fish` | Auto-loaded config (key bindings, auto-start) |
| `~/.config/fish/functions/fish_tab_ai.fish` | Management command |
| `~/.config/fish/functions/_fish_tab_ai_*.fish` | Internal plugin functions |
| `~/.local/state/fish-tab-ai/daemon.pid` | Daemon PID file |
| `/tmp/fish_tab_ai_buffer` | IPC: Fish writes current input here |
| `/tmp/fish_tab_ai_result` | IPC: Daemon writes suggestions here |
| `/tmp/fish_tab_ai_recent` | IPC: Recent command history for predictions |

## Troubleshooting

**No suggestions appearing?**
```fish
fish_tab_ai status        # Check if daemon is running
fish_tab_ai restart       # Restart the daemon
ollama list               # Verify model is downloaded
```

**Suggestions are slow?**
- Use a smaller model: `fish_tab_ai restart qwen2.5-coder:1.5b`
- Ensure Ollama is running: `ollama serve`

**Ghost text overlaps with native Fish suggestions?**
- The plugin suppresses native autosuggestions when an AI suggestion is shown. If you see overlap, restart: `fish_tab_ai restart`

**Want to disable auto-start?**
- Remove or comment out the auto-start block at the bottom of `~/.config/fish/conf.d/fish_tab_ai.fish`

## Uninstall

```fish
fish_tab_ai stop
rm -rf ~/.local/share/fish-tab-ai
rm -rf ~/.local/state/fish-tab-ai
rm ~/.config/fish/conf.d/fish_tab_ai.fish
rm ~/.config/fish/functions/fish_tab_ai.fish
rm ~/.config/fish/functions/_fish_tab_ai_*.fish
```

## License

MIT
