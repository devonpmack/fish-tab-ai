"""AI completion engine using Ollama."""

import json
import time
import urllib.request
from collections import OrderedDict
from concurrent.futures import ThreadPoolExecutor

from history import load_history

OLLAMA_CHAT_URL = "http://localhost:11434/api/chat"
CACHE_SIZE = 200
CACHE_TTL = 120


class Completer:
    def __init__(self, model="qwen2.5-coder:1.5b"):
        self.model = model
        self.cache = OrderedDict()
        self.pending = {}
        self.executor = ThreadPoolExecutor(max_workers=2)
        self.history = load_history()
        self.history_loaded_at = time.time()

    def complete(self, buffer, cwd, recent=None):
        """Return a completion suffix for the given buffer, or None."""
        self._reload_history_if_stale()
        self._collect_finished()

        cached = self._check_cache(buffer)
        if cached is not None:
            return cached

        if not buffer:
            # Predictive mode: compute synchronously since context changes each time
            _, suggestion = self._compute(buffer, cwd, recent)
            return suggestion

        self._start_computation(buffer, cwd, recent=recent)
        return None

    def _check_cache(self, buffer):
        if not buffer:
            return None

        now = time.time()
        if buffer in self.cache:
            entry = self.cache[buffer]
            if now - entry["time"] < CACHE_TTL:
                self.cache.move_to_end(buffer)
                return entry["suggestion"]
            else:
                del self.cache[buffer]

        for cached_buf in list(self.cache):
            entry = self.cache[cached_buf]
            if now - entry["time"] >= CACHE_TTL:
                continue
            full_text = cached_buf + entry["suggestion"]
            if full_text.startswith(buffer) and len(buffer) > len(cached_buf):
                remaining = full_text[len(buffer):]
                if remaining:
                    return remaining

        return None

    def _collect_finished(self):
        done_keys = [k for k, fut in self.pending.items() if fut.done()]
        for key in done_keys:
            future = self.pending.pop(key)
            try:
                buf, suggestion = future.result()
                if suggestion:
                    self._put_cache(buf, suggestion)
            except Exception:
                pass

    def _start_computation(self, buffer, cwd, recent=None):
        if buffer in self.pending:
            return
        if len(self.pending) > 3:
            oldest = next(iter(self.pending))
            fut = self.pending.pop(oldest)
            fut.cancel()

        self.pending[buffer] = self.executor.submit(
            self._compute, buffer, cwd, recent
        )

    def _compute(self, buffer, cwd, recent=None):
        relevant, prefix_matches = self._get_relevant_history(buffer, cwd)
        history_text = self._build_prompt(buffer, cwd, relevant, prefix_matches, recent)
        suggestion = self._query_ollama(history_text, buffer)
        return (buffer, suggestion)

    def _put_cache(self, buffer, suggestion):
        self.cache[buffer] = {"suggestion": suggestion, "time": time.time()}
        while len(self.cache) > CACHE_SIZE:
            self.cache.popitem(last=False)

    def _get_relevant_history(self, buffer, cwd, limit=15):
        prefix = buffer.split()[0] if buffer.strip() else ""
        prefix_matches = []
        related = []

        for cmd in reversed(self.history):
            if cmd.startswith(buffer) and cmd != buffer:
                if cmd not in prefix_matches and len(prefix_matches) < 5:
                    prefix_matches.append(cmd)
            elif prefix and cmd.startswith(prefix):
                if cmd not in related and len(related) < limit:
                    related.append(cmd)
            elif cwd and cwd in cmd:
                if cmd not in related and len(related) < limit:
                    related.append(cmd)

        recent = self.history[-10:]
        for cmd in recent:
            if cmd not in related and cmd not in prefix_matches:
                related.append(cmd)

        return related[-limit:], prefix_matches

    def _build_prompt(self, buffer, cwd, history, prefix_matches, recent=None):
        history_lines = []
        for cmd in history:
            history_lines.append(cmd)
        if prefix_matches:
            for cmd in prefix_matches:
                if cmd not in history_lines:
                    history_lines.append(cmd)
        if recent:
            for cmd in recent:
                if cmd not in history_lines:
                    history_lines.append(cmd)
        return "\n".join(history_lines)

    def _query_ollama(self, history_text, buffer):
        try:
            if buffer:
                system = "You are a shell autocomplete. The user gives you their recent commands and a partial command. Return the full completed command. Reply with ONLY the command."
                user_msg = f"Recent:\n{history_text}\n\nComplete: {buffer}"
            else:
                system = "You are a shell autocomplete. The user gives you their recent commands. Predict the most likely productive next command they will run. Reply with ONLY the command. Never suggest exit or clear."
                user_msg = f"Recent:\n{history_text}"

            payload = {
                "model": self.model,
                "messages": [
                    {"role": "system", "content": system},
                    {"role": "user", "content": user_msg},
                ],
                "stream": False,
                "options": {
                    "temperature": 0.1,
                    "num_predict": 60,
                    "stop": ["\n"],
                },
            }

            data = json.dumps(payload).encode()
            req = urllib.request.Request(
                OLLAMA_CHAT_URL,
                data=data,
                headers={"Content-Type": "application/json"},
            )

            with urllib.request.urlopen(req, timeout=10) as resp:
                result = json.loads(resp.read().decode())

            text = result.get("message", {}).get("content", "")
            text = text.strip()
            if text.startswith("`"):
                text = text.lstrip("`")
            if text.endswith("`"):
                text = text.rstrip("`")
            if text.startswith("$ "):
                text = text[2:]

            if buffer:
                if not text.startswith(buffer):
                    return None
                text = text[len(buffer):]

            if len(text) < 1 or len(text) > 200:
                return None
            if not buffer and text.strip() in ("exit", "clear", "q", "quit"):
                return None
            return text

        except Exception:
            return None

    def _reload_history_if_stale(self):
        if time.time() - self.history_loaded_at > 300:
            self.history = load_history()
            self.history_loaded_at = time.time()
