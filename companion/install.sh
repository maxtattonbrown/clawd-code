#!/bin/bash
# ABOUTME: Standalone installer for Wingmax — browser companion for Claude Code.
# ABOUTME: Downloads files, adds hooks, creates shell alias, and sets mode.

set -e

COMPANION_DIR="$HOME/.claude/companion"
SETTINGS_FILE="$HOME/.claude/settings.json"
REPO_BASE="https://raw.githubusercontent.com/maxtattonbrown/wingmax/main"

# ── Uninstall mode ──
if [ "$1" = "--uninstall" ]; then
  echo "Removing Wingmax..."

  # Stop server if running
  if [ -f "$COMPANION_DIR/server.pid" ]; then
    kill "$(cat "$COMPANION_DIR/server.pid")" 2>/dev/null || true
    rm -f "$COMPANION_DIR/server.pid"
  fi

  # Remove companion directory
  rm -rf "$COMPANION_DIR"

  # Remove shell alias
  for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
    [ -f "$rc" ] && sed -i.bak '/# Wingmax/d;/alias wingmax=/d' "$rc" && rm -f "${rc}.bak"
  done

  # Remove hooks from settings.json (best-effort — leaves file valid)
  if [ -f "$SETTINGS_FILE" ] && command -v python3 &>/dev/null; then
    python3 -c "
import json, sys
with open('$SETTINGS_FILE') as f: s = json.load(f)
hooks = s.get('hooks', {})
for key in ['PostToolUse', 'Stop']:
    if key in hooks:
        hooks[key] = [h for h in hooks[key]
                      if not any('companion/' in (hh.get('command','') )
                                 for hh in h.get('hooks', []))]
        if not hooks[key]: del hooks[key]
with open('$SETTINGS_FILE', 'w') as f: json.dump(s, f, indent=2)
" 2>/dev/null || echo "  (Could not clean hooks from settings.json — do it manually)"
  fi

  echo "Done. Wingmax has been removed."
  exit 0
fi

# ── Install ──
echo ""
echo "  >_  Installing Wingmax — your Claude Code companion"
echo ""

# Create companion directory
mkdir -p "$COMPANION_DIR"

# Download files
FILES="wingmax.html wingmax-hook.sh wingmax-stop-hook.sh wingmax-server.py"
for f in $FILES; do
  echo "  Downloading $f..."
  curl -fsSL "$REPO_BASE/companion/$f" -o "$COMPANION_DIR/$f"
done

# Make scripts executable
chmod +x "$COMPANION_DIR/wingmax-hook.sh" "$COMPANION_DIR/wingmax-stop-hook.sh" "$COMPANION_DIR/wingmax-server.py"

# Create the wingmax launcher script
cat > "$COMPANION_DIR/wingmax.sh" <<'LAUNCHER'
#!/bin/bash
# ABOUTME: Launcher for Wingmax — starts server, opens browser, launches Claude Code.
# ABOUTME: Usage: wingmax [--open|--stop|--mode beginner|intermediate]

COMPANION_DIR="$HOME/.claude/companion"
PID_FILE="$COMPANION_DIR/server.pid"
STATUS_FILE="$COMPANION_DIR/status.json"
PORT=7788

case "$1" in
  --stop)
    if [ -f "$PID_FILE" ]; then
      kill "$(cat "$PID_FILE")" 2>/dev/null
      rm -f "$PID_FILE" "$COMPANION_DIR/active-session"
      echo "Wingmax server stopped."
    else
      echo "No server running."
    fi
    exit 0
    ;;
  --open)
    open "http://localhost:$PORT/wingmax.html" 2>/dev/null || xdg-open "http://localhost:$PORT/wingmax.html" 2>/dev/null
    exit 0
    ;;
  --mode)
    if [ -z "$2" ] || { [ "$2" != "beginner" ] && [ "$2" != "intermediate" ]; }; then
      echo "Usage: wingmax --mode beginner|intermediate"
      exit 1
    fi
    echo "{\"mode\": \"$2\"}" > "$COMPANION_DIR/config.json"
    echo "Mode set to $2."
    exit 0
    ;;
esac

# Clean up server and session lock on exit
cleanup() {
  rm -f "$COMPANION_DIR/active-session"
  if [ -f "$PID_FILE" ]; then
    kill "$(cat "$PID_FILE")" 2>/dev/null
    rm -f "$PID_FILE"
  fi
}
trap cleanup EXIT

# Write initial status with hello event
PROJECT_NAME=$(basename "$(pwd)")
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
cat > "$STATUS_FILE" <<EOJSON
{"session_id":"","project":"$PROJECT_NAME","events":[{"ts":"$TIMESTAMP","tool":"_hello","label":"Connected","detail":"Claude Code is ready","type":"hello"}],"files_touched":[],"has_html":false}
EOJSON

# Session scoping: empty file — first hook event will populate
echo -n "" > "$COMPANION_DIR/active-session"

# Start the server if not already running
if ! lsof -i ":$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  WINGMAX_PROJECT_DIR="$(pwd)" python3 "$COMPANION_DIR/wingmax-server.py" &
  for i in 1 2 3 4 5; do
    sleep 0.3
    lsof -i ":$PORT" -sTCP:LISTEN >/dev/null 2>&1 && break
  done
fi

# Open the companion page
open "http://localhost:$PORT/wingmax.html" 2>/dev/null || xdg-open "http://localhost:$PORT/wingmax.html" 2>/dev/null

# Launch Claude Code
claude "$@"
LAUNCHER
chmod +x "$COMPANION_DIR/wingmax.sh"

# ── Add hooks to settings.json ──
echo "  Configuring hooks..."
if [ ! -f "$SETTINGS_FILE" ]; then
  # No settings file yet — create one with just hooks
  cat > "$SETTINGS_FILE" <<'EOSETTINGS'
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.claude/companion/wingmax-hook.sh",
            "async": true
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.claude/companion/wingmax-stop-hook.sh",
            "async": true
          }
        ]
      }
    ]
  }
}
EOSETTINGS
else
  # Settings file exists — add hooks if not already present
  if command -v python3 &>/dev/null; then
    python3 -c "
import json

with open('$SETTINGS_FILE') as f:
    s = json.load(f)

hooks = s.setdefault('hooks', {})

def has_wingmax_hook(entries):
    for entry in entries:
        for h in entry.get('hooks', []):
            if 'companion/' in h.get('command', ''):
                return True
    return False

ptu = hooks.setdefault('PostToolUse', [])
if not has_wingmax_hook(ptu):
    ptu.append({
        'matcher': '',
        'hooks': [{'type': 'command', 'command': '\$HOME/.claude/companion/wingmax-hook.sh', 'async': True}]
    })

stop = hooks.setdefault('Stop', [])
if not has_wingmax_hook(stop):
    stop.append({
        'matcher': '',
        'hooks': [{'type': 'command', 'command': '\$HOME/.claude/companion/wingmax-stop-hook.sh', 'async': True}]
    })

with open('$SETTINGS_FILE', 'w') as f:
    json.dump(s, f, indent=2)
" 2>/dev/null || echo "  (Could not add hooks automatically — add them manually)"
  fi
fi

# ── Add shell alias ──
ALIAS_LINE='alias wingmax="$HOME/.claude/companion/wingmax.sh"  # Wingmax'
for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
  if [ -f "$rc" ]; then
    if ! grep -q 'alias wingmax=' "$rc" 2>/dev/null; then
      echo "" >> "$rc"
      echo "$ALIAS_LINE" >> "$rc"
    fi
  fi
done

# ── Ask about mode ──
echo ""
printf "  Are you new to Claude Code? (y/n) "
read -r answer
if [ "$answer" = "y" ] || [ "$answer" = "Y" ] || [ "$answer" = "yes" ]; then
  echo '{"mode": "beginner"}' > "$COMPANION_DIR/config.json"
  echo "  Set to beginner mode. You can switch later with: wingmax --mode intermediate"
else
  echo '{"mode": "intermediate"}' > "$COMPANION_DIR/config.json"
  echo "  Set to intermediate mode. You can switch with: wingmax --mode beginner"
fi

echo ""
echo "  >_  Wingmax installed!"
echo ""
echo "  To start: open a terminal, cd to your project, and type: wingmax"
echo "  To remove: curl -fsSL $REPO_BASE/install.sh | bash -s -- --uninstall"
echo ""
