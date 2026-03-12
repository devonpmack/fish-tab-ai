"""Fish and Bash history parser."""

import os

FISH_HISTORY = os.path.expanduser("~/.local/share/fish/fish_history")
BASH_HISTORY = os.path.expanduser("~/.bash_history")


def load_history():
    """Load and deduplicate commands from fish and bash history."""
    commands = []
    commands.extend(_load_fish_history())
    commands.extend(_load_bash_history())

    seen = set()
    unique = []
    for cmd in commands:
        if cmd not in seen:
            seen.add(cmd)
            unique.append(cmd)
    return unique


def _load_fish_history(limit=5000):
    commands = []
    try:
        with open(FISH_HISTORY, "r", encoding="utf-8", errors="replace") as f:
            for line in f:
                if line.startswith("- cmd: "):
                    cmd = line[7:].strip()
                    if cmd and len(cmd) < 500:
                        commands.append(cmd)
    except FileNotFoundError:
        pass
    return commands[-limit:]


def _load_bash_history(limit=1000):
    commands = []
    try:
        with open(BASH_HISTORY, "r", encoding="utf-8", errors="replace") as f:
            for line in f:
                cmd = line.strip()
                if cmd and not cmd.startswith("#") and len(cmd) < 500:
                    commands.append(cmd)
    except FileNotFoundError:
        pass
    return commands[-limit:]
