#!/bin/bash
# ABOUTME: PostToolUse hook that writes Claude Code activity to a JSON status file.
# ABOUTME: The Browser Wingman companion page reads this file to show what Claude is doing.

STATUS_FILE="$HOME/.claude/companion/status.json"
TEMP_FILE="$HOME/.claude/companion/status.tmp.json"
MAX_EVENTS=50

# Read hook JSON from stdin
INPUT=$(cat)

# Extract fields — try jq first, fall back to python3
if command -v jq &>/dev/null; then
  TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')
  SESSION=$(echo "$INPUT" | jq -r '.session_id // empty')
  CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

  # Extract detail based on tool type
  case "$TOOL" in
    Read|Write)
      DETAIL=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' | xargs basename 2>/dev/null)
      ;;
    Edit)
      DETAIL=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' | xargs basename 2>/dev/null)
      ;;
    Bash)
      DETAIL=$(echo "$INPUT" | jq -r '.tool_input.description // .tool_input.command // empty' | head -c 60)
      ;;
    Glob)
      DETAIL=$(echo "$INPUT" | jq -r '.tool_input.pattern // empty')
      ;;
    Grep)
      DETAIL=$(echo "$INPUT" | jq -r '.tool_input.pattern // empty')
      ;;
    Agent)
      DETAIL=$(echo "$INPUT" | jq -r '.tool_input.description // empty')
      ;;
    *)
      DETAIL=""
      ;;
  esac
else
  # Python3 fallback
  eval "$(echo "$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
tool = d.get('tool_name', '')
session = d.get('session_id', '')
cwd = d.get('cwd', '')
ti = d.get('tool_input', {})
detail = ''
if tool in ('Read', 'Write', 'Edit'):
    fp = ti.get('file_path', '')
    detail = fp.rsplit('/', 1)[-1] if '/' in fp else fp
elif tool == 'Bash':
    detail = (ti.get('description') or ti.get('command', ''))[:60]
elif tool == 'Glob':
    detail = ti.get('pattern', '')
elif tool == 'Grep':
    detail = ti.get('pattern', '')
elif tool == 'Agent':
    detail = ti.get('description', '')
print(f'TOOL={json.dumps(tool)}')
print(f'SESSION={json.dumps(session)}')
print(f'CWD={json.dumps(cwd)}')
print(f'DETAIL={json.dumps(detail)}')
" 2>/dev/null)"
fi

# Skip if no tool detected
[ -z "$TOOL" ] && exit 0

# Session scoping: only process events from the active Wingman session
ACTIVE_SESSION_FILE="$HOME/.claude/companion/active-session"
if [ -f "$ACTIVE_SESSION_FILE" ] && [ -n "$SESSION" ]; then
  ACTIVE_SESSION=$(cat "$ACTIVE_SESSION_FILE" 2>/dev/null)
  if [ -z "$ACTIVE_SESSION" ]; then
    # First event after launch — lock to this session
    echo -n "$SESSION" > "$ACTIVE_SESSION_FILE"
  elif [ "$SESSION" != "$ACTIVE_SESSION" ]; then
    exit 0
  fi
fi

# Map tool to friendly label and type
case "$TOOL" in
  Read)       LABEL="Reading a file";        TYPE="file_read" ;;
  Write)      LABEL="Creating a new file";   TYPE="file_create" ;;
  Edit)       LABEL="Editing a file";        TYPE="file_edit" ;;
  Bash)       LABEL="Running a command";     TYPE="command" ;;
  Glob)       LABEL="Searching for files";   TYPE="search" ;;
  Grep)       LABEL="Searching inside files"; TYPE="search" ;;
  Agent)      LABEL="Asking a helper";       TYPE="agent" ;;
  Skill)      LABEL="Using a skill";         TYPE="skill" ;;
  WebFetch)   LABEL="Fetching a web page";   TYPE="web" ;;
  WebSearch)  LABEL="Searching the web";     TYPE="web" ;;
  *)          LABEL="Working...";            TYPE="other" ;;
esac

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
PROJECT=$(basename "$CWD" 2>/dev/null)

# Check if a new HTML file was CREATED (Write only — not Read/Edit)
IS_HTML=false
if [ "$TOOL" = "Write" ]; then
  case "$DETAIL" in
    *.html|*.htm) IS_HTML=true ;;
  esac
fi

# Build the new event and merge into status file
if command -v jq &>/dev/null; then
  NEW_EVENT=$(jq -n \
    --arg ts "$TIMESTAMP" \
    --arg tool "$TOOL" \
    --arg label "$LABEL" \
    --arg detail "$DETAIL" \
    --arg type "$TYPE" \
    '{ts: $ts, tool: $tool, label: $label, detail: $detail, type: $type}')

  # Create or update the status file
  if [ -f "$STATUS_FILE" ] && [ -s "$STATUS_FILE" ]; then
    jq --argjson event "$NEW_EVENT" \
       --arg session "$SESSION" \
       --arg project "$PROJECT" \
       --argjson max "$MAX_EVENTS" \
       --arg detail "$DETAIL" \
       --arg is_html "$IS_HTML" \
       --arg tool "$TOOL" '
      .session_id = $session |
      .project = $project |
      .events = ([$event] + .events)[:$max] |
      .files_touched = (
        if ($tool == "Write" or $tool == "Edit") and $detail != ""
        then ([$detail] + (.files_touched // [])) | unique
        else (.files_touched // [])
        end
      ) |
      .has_html = ((.files_touched // []) | any(endswith(".html") or endswith(".htm"))) |
      .stopped = false
    ' "$STATUS_FILE" > "$TEMP_FILE" 2>/dev/null && mv "$TEMP_FILE" "$STATUS_FILE"
  else
    FILES_TOUCHED="[]"
    if [ "$TOOL" = "Write" ] || [ "$TOOL" = "Edit" ]; then
      [ -n "$DETAIL" ] && FILES_TOUCHED="[\"$DETAIL\"]"
    fi
    jq -n \
      --arg session "$SESSION" \
      --arg project "$PROJECT" \
      --argjson event "$NEW_EVENT" \
      --argjson files "$FILES_TOUCHED" \
      --argjson has_html "$IS_HTML" \
      '{session_id: $session, project: $project, events: [$event], files_touched: $files, has_html: $has_html}' \
      > "$STATUS_FILE"
  fi
else
  # Python3 fallback for full merge
  python3 -c "
import json, os
status_file = '$STATUS_FILE'
event = {'ts': '$TIMESTAMP', 'tool': '$TOOL', 'label': '$LABEL', 'detail': '$DETAIL', 'type': '$TYPE'}
try:
    with open(status_file) as f:
        data = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    data = {'session_id': '', 'project': '', 'events': [], 'files_touched': [], 'has_html': False}

data['session_id'] = '$SESSION'
data['project'] = '$PROJECT'
data['events'] = ([event] + data['events'])[:$MAX_EVENTS]

if '$TOOL' in ('Write', 'Edit') and '$DETAIL':
    if '$DETAIL' not in data['files_touched']:
        data['files_touched'].insert(0, '$DETAIL')

data['has_html'] = any(f.endswith(('.html', '.htm')) for f in data['files_touched'])
data['stopped'] = False

with open('$TEMP_FILE', 'w') as f:
    json.dump(data, f)
os.replace('$TEMP_FILE', status_file)
" 2>/dev/null
fi

exit 0
