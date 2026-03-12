#!/usr/bin/env python3
"""Fish Tab AI - Local AI completion daemon with file-based IPC."""

import os
import signal
import sys
import threading
import time
from http.server import HTTPServer, BaseHTTPRequestHandler
from socketserver import ThreadingMixIn
from urllib.parse import urlparse, parse_qs, unquote

from completer import Completer

DEFAULT_PORT = 62019
STATE_DIR = os.path.expanduser("~/.local/state/fish-tab-ai")
PID_FILE = os.path.join(STATE_DIR, "daemon.pid")

BUFFER_FILE = "/tmp/fish_tab_ai_buffer"
RESULT_FILE = "/tmp/fish_tab_ai_result"
RECENT_FILE = "/tmp/fish_tab_ai_recent"


class FileWatcher(threading.Thread):
    """Polls the buffer file and writes completion results.

    Fish key handlers write the current commandline to BUFFER_FILE.
    This thread picks it up, queries the completer, and writes the
    result to RESULT_FILE. Fish reads it on the next keypress.
    Zero process spawning on the fish side.
    """

    daemon = True

    def __init__(self, completer):
        super().__init__()
        self.completer = completer
        self.last_buffer = ""
        self.last_handled = ""

    def _read_recent(self):
        try:
            if os.path.exists(RECENT_FILE):
                with open(RECENT_FILE) as f:
                    return [l.strip() for l in f if l.strip()]
        except Exception:
            pass
        return []

    def _write_result(self, buffer, suggestion, fish_pid):
        tmp = RESULT_FILE + ".tmp"
        with open(tmp, "w") as f:
            f.write(f"{buffer}\t{suggestion}")
        os.rename(tmp, RESULT_FILE)
        if fish_pid:
            try:
                os.kill(fish_pid, signal.SIGUSR1)
            except (ProcessLookupError, PermissionError):
                pass

    def run(self):
        self.last_mtime = 0
        pending_buffer = None
        pending_cwd = ""
        pending_pid = 0
        while True:
            try:
                new_input = False
                if os.path.exists(BUFFER_FILE):
                    mtime = os.path.getmtime(BUFFER_FILE)
                    if mtime != self.last_mtime:
                        self.last_mtime = mtime
                        new_input = True
                        with open(BUFFER_FILE) as f:
                            content = f.read().rstrip("\n")
                        if not content:
                            continue
                        parts = content.split("\t", 2)
                        buffer = parts[0]
                        cwd = parts[1] if len(parts) > 1 else ""
                        fish_pid = int(parts[2]) if len(parts) > 2 else 0
                        recent = self._read_recent()

                        if len(buffer) >= 1 or (len(buffer) == 0 and recent):
                            suggestion = self.completer.complete(
                                buffer, cwd, recent=recent
                            )
                            if suggestion:
                                self._write_result(buffer, suggestion, fish_pid)
                                pending_buffer = None
                            else:
                                pending_buffer = buffer
                                pending_cwd = cwd
                                pending_pid = fish_pid

                if not new_input and pending_buffer is not None:
                    suggestion = self.completer.complete(
                        pending_buffer, pending_cwd
                    )
                    if suggestion:
                        self._write_result(
                            pending_buffer, suggestion, pending_pid
                        )
                        pending_buffer = None
            except Exception:
                pass
            time.sleep(0.05)


class ThreadedHTTPServer(ThreadingMixIn, HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


class CompletionHandler(BaseHTTPRequestHandler):
    completer = None

    def do_GET(self):
        parsed = urlparse(self.path)

        if parsed.path == "/health":
            self._respond(200, "ok")
            return

        if parsed.path == "/complete":
            params = parse_qs(parsed.query)
            buffer = unquote(params.get("buffer", [""])[0])
            cwd = unquote(params.get("cwd", [""])[0])

            if not buffer or len(buffer) < 2:
                self._respond(200, "")
                return

            suggestion = self.completer.complete(buffer, cwd)
            self._respond(200, suggestion or "")
            return

        self._respond(404, "not found")

    def _respond(self, code, body):
        self.send_response(code)
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        self.wfile.write(body.encode())

    def log_message(self, format, *args):
        pass


def _write_pid():
    os.makedirs(STATE_DIR, exist_ok=True)
    with open(PID_FILE, "w") as f:
        f.write(str(os.getpid()))


def _remove_pid():
    try:
        os.remove(PID_FILE)
    except FileNotFoundError:
        pass


def _cleanup_files():
    for f in (BUFFER_FILE, RESULT_FILE, RESULT_FILE + ".tmp"):
        try:
            os.remove(f)
        except FileNotFoundError:
            pass


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_PORT
    model = sys.argv[2] if len(sys.argv) > 2 else "qwen2.5-coder:1.5b"

    completer = Completer(model=model)
    CompletionHandler.completer = completer

    watcher = FileWatcher(completer)
    watcher.start()

    server = ThreadedHTTPServer(("127.0.0.1", port), CompletionHandler)
    _write_pid()
    _cleanup_files()

    def shutdown(signum, frame):
        _remove_pid()
        _cleanup_files()
        server.shutdown()
        sys.exit(0)

    signal.signal(signal.SIGTERM, shutdown)
    signal.signal(signal.SIGINT, shutdown)

    print(f"fish-tab-ai daemon on 127.0.0.1:{port} (model: {model})", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
