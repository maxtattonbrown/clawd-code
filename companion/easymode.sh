#!/bin/bash
# ABOUTME: Launcher for Easy Mode with Browser Wingman.
# ABOUTME: Starts the companion server, opens the browser, and launches Claude Code.

COMPANION_DIR="$HOME/.claude/companion"
PID_FILE="$COMPANION_DIR/server.pid"
STATUS_FILE="$COMPANION_DIR/status.json"
PORT=7788

# Clean up server and session lock on exit
cleanup() {
  rm -f "$COMPANION_DIR/active-session"
  if [ -f "$PID_FILE" ]; then
    kill "$(cat "$PID_FILE")" 2>/dev/null
    rm -f "$PID_FILE"
  fi
}
trap cleanup EXIT

# Write initial status with a hello event — this proves the connection to the browser
PROJECT_NAME=$(basename "$(pwd)")
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
cat > "$STATUS_FILE" <<EOJSON
{"session_id":"","project":"$PROJECT_NAME","events":[{"ts":"$TIMESTAMP","tool":"_hello","label":"Connected","detail":"Claude Code is ready \u2014 try saying something!","type":"hello"}],"files_touched":[],"has_html":false}
EOJSON

# Session scoping: write empty active-session file — first hook event will populate it
ACTIVE_SESSION_FILE="$COMPANION_DIR/active-session"
echo -n "" > "$ACTIVE_SESSION_FILE"

# Start the companion server if not already running
if ! lsof -i ":$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  WINGMAN_PROJECT_DIR="$(pwd)" python3 "$COMPANION_DIR/wingman-server.py" &
  # Wait briefly for the server to start
  for i in 1 2 3 4 5; do
    sleep 0.3
    lsof -i ":$PORT" -sTCP:LISTEN >/dev/null 2>&1 && break
  done
fi

# Open the companion page in the default browser
open "http://localhost:$PORT/wingman.html" 2>/dev/null

# Launch Claude Code in the foreground — pass through any arguments
claude "$@"
