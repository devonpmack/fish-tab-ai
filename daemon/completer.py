"""AI completion engine using Ollama."""

import json
import time
import urllib.request
from collections import OrderedDict
from concurrent.futures import ThreadPoolExecutor

from history import load_history

OLLAMA_URL = "http://localhost:11434/api/generate"
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

    def complete(self, buffer, cwd):
        """Return a completion suffix for the given buffer, or None."""
        self._reload_history_if_stale()
        self._collect_finished()

        cached = self._check_cache(buffer)
        if cached is not None:
            return cached

        self._start_computation(buffer, cwd)
        return None

    def _check_cache(self, buffer):
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

    def _start_computation(self, buffer, cwd):
        if buffer in self.pending:
            return
        if len(self.pending) > 3:
            oldest = next(iter(self.pending))
            fut = self.pending.pop(oldest)
            fut.cancel()

        self.pending[buffer] = self.executor.submit(
            self._compute, buffer, cwd
        )

    def _compute(self, buffer, cwd):
        relevant, prefix_matches = self._get_relevant_history(buffer, cwd)
        prompt = self._build_prompt(buffer, cwd, relevant, prefix_matches)
        suggestion = self._query_ollama(prompt, buffer)
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

    def _build_prompt(self, buffer, cwd, history, prefix_matches):
        lines = [f"$ {cmd}" for cmd in history]
        if prefix_matches:
            lines.append("")
            lines.append("# commands matching current input:")
            for cmd in prefix_matches:
                lines.append(f"$ {cmd}")
            lines.append("")
        lines.append(f"$ {buffer}")
        return "\n".join(lines)

    def _query_ollama(self, prompt, buffer):
        try:
            data = json.dumps({
                "model": self.model,
                "prompt": prompt,
                "raw": True,
                "stream": False,
                "options": {
                    "temperature": 0.1,
                    "num_predict": 60,
                    "stop": ["\n", "$"],
                    "top_p": 0.9,
                },
            }).encode()

            req = urllib.request.Request(
                OLLAMA_URL,
                data=data,
                headers={"Content-Type": "application/json"},
            )

            with urllib.request.urlopen(req, timeout=10) as resp:
                result = json.loads(resp.read().decode())

            text = result.get("response", "")
            text = text.rstrip()
            if text.startswith("`"):
                text = text.lstrip("`")
            if text.endswith("`"):
                text = text.rstrip("`")

            # BPE tokenization causes overlap: buffer "git comm" + model "mit"
            # should be "git commit", not "git commMit". Strip the overlap.
            for overlap_len in range(min(len(buffer), len(text)), 0, -1):
                if buffer.endswith(text[:overlap_len]):
                    text = text[overlap_len:]
                    break

            if len(text) < 1 or len(text) > 200:
                return None
            return text

        except Exception:
            return None

    def _reload_history_if_stale(self):
        if time.time() - self.history_loaded_at > 300:
            self.history = load_history()
            self.history_loaded_at = time.time()
