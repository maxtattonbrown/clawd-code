#!/bin/bash
# ABOUTME: Stop hook that fires when Claude finishes responding.
# ABOUTME: Sets stopped=true in status.json so the WingMax page knows Claude is done.

STATUS_FILE="$HOME/.claude/companion/status.json"
TEMP_FILE="$HOME/.claude/companion/status.tmp.json"

[ ! -f "$STATUS_FILE" ] && exit 0

# Session scoping: only process Stop from the active WingMax session
INPUT=$(cat)
ACTIVE_SESSION_FILE="$HOME/.claude/companion/active-session"
if [ -f "$ACTIVE_SESSION_FILE" ]; then
  if command -v jq &>/dev/null; then
    SESSION=$(echo "$INPUT" | jq -r '.session_id // empty')
  else
    SESSION=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('session_id',''))" 2>/dev/null)
  fi
  ACTIVE_SESSION=$(cat "$ACTIVE_SESSION_FILE" 2>/dev/null)
  [ -n "$ACTIVE_SESSION" ] && [ -n "$SESSION" ] && [ "$SESSION" != "$ACTIVE_SESSION" ] && exit 0
fi

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

if command -v jq &>/dev/null; then
  jq --arg ts "$TIMESTAMP" '.stopped = true | .stopped_ts = $ts' \
    "$STATUS_FILE" > "$TEMP_FILE" 2>/dev/null && mv "$TEMP_FILE" "$STATUS_FILE"
else
  python3 -c "
import json, os
try:
    with open('$STATUS_FILE') as f: data = json.load(f)
except: exit()
data['stopped'] = True
data['stopped_ts'] = '$TIMESTAMP'
with open('$TEMP_FILE', 'w') as f: json.dump(data, f)
os.replace('$TEMP_FILE', '$STATUS_FILE')
" 2>/dev/null
fi

exit 0
