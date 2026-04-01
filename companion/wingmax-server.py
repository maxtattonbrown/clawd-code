#!/usr/bin/env python3
# ABOUTME: Tiny local HTTP server for the Browser WingMax companion page.
# ABOUTME: Serves wingmax.html, status.json, and project file previews on localhost:7788.

import http.server
import json
import os
import signal
import sys
import threading
import time

PORT = 7788
COMPANION_DIR = os.path.expanduser("~/.claude/companion")
PID_FILE = os.path.join(COMPANION_DIR, "server.pid")
IDLE_TIMEOUT = 1800  # 30 minutes

# Track the project directory — set by the launcher via environment variable
PROJECT_DIR = os.environ.get("WINGMAX_PROJECT_DIR", os.getcwd())

last_request_time = time.time()


class WingMaxHandler(http.server.BaseHTTPRequestHandler):
    """Serves companion files and project previews with no-cache headers."""

    def do_GET(self):
        global last_request_time
        last_request_time = time.time()

        if self.path == "/" or self.path == "/wingmax.html":
            self.serve_file(os.path.join(COMPANION_DIR, "wingmax.html"), "text/html")
        elif self.path == "/status.json":
            self.serve_file(os.path.join(COMPANION_DIR, "status.json"), "application/json")
        elif self.path == "/config.json":
            self.serve_file(os.path.join(COMPANION_DIR, "config.json"), "application/json")
        elif self.path.startswith("/preview/"):
            # Serve files from the project directory for live preview
            relative_path = self.path[len("/preview/"):]
            file_path = os.path.normpath(os.path.join(PROJECT_DIR, relative_path))
            # Security: only serve files within the project directory
            if not file_path.startswith(os.path.normpath(PROJECT_DIR)):
                self.send_error(403, "Forbidden")
                return
            content_type = self.guess_type(file_path)
            self.serve_file(file_path, content_type)
        else:
            self.send_error(404, "Not Found")

    def serve_file(self, path, content_type):
        try:
            with open(path, "rb") as f:
                content = f.read()
            self.send_response(200)
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(len(content)))
            self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(content)
        except FileNotFoundError:
            # Return sensible defaults for JSON files that don't exist yet
            if path.endswith("status.json"):
                empty = json.dumps({"session_id": "", "project": "", "events": [], "files_touched": [], "has_html": False})
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Cache-Control", "no-store")
                self.end_headers()
                self.wfile.write(empty.encode())
            elif path.endswith("config.json"):
                default_cfg = json.dumps({"mode": "beginner"})
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Cache-Control", "no-store")
                self.end_headers()
                self.wfile.write(default_cfg.encode())
            else:
                self.send_error(404, "Not Found")

    def guess_type(self, path):
        ext = os.path.splitext(path)[1].lower()
        types = {
            ".html": "text/html", ".htm": "text/html",
            ".css": "text/css", ".js": "application/javascript",
            ".json": "application/json", ".png": "image/png",
            ".jpg": "image/jpeg", ".jpeg": "image/jpeg",
            ".gif": "image/gif", ".svg": "image/svg+xml",
            ".ico": "image/x-icon", ".woff2": "font/woff2",
        }
        return types.get(ext, "application/octet-stream")

    def log_message(self, format, *args):
        # Suppress request logging to keep terminal clean
        pass


def idle_watchdog():
    """Shut down the server if no requests for IDLE_TIMEOUT seconds."""
    while True:
        time.sleep(60)
        if time.time() - last_request_time > IDLE_TIMEOUT:
            cleanup()
            os._exit(0)


def cleanup():
    try:
        os.remove(PID_FILE)
    except FileNotFoundError:
        pass


def main():
    # Write PID file
    os.makedirs(COMPANION_DIR, exist_ok=True)
    with open(PID_FILE, "w") as f:
        f.write(str(os.getpid()))

    # Clean up on signals
    def handle_signal(signum, frame):
        cleanup()
        sys.exit(0)

    signal.signal(signal.SIGTERM, handle_signal)
    signal.signal(signal.SIGINT, handle_signal)

    # Start idle watchdog
    watchdog = threading.Thread(target=idle_watchdog, daemon=True)
    watchdog.start()

    # Start server
    server = http.server.HTTPServer(("127.0.0.1", PORT), WingMaxHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        cleanup()
        server.server_close()


if __name__ == "__main__":
    main()
