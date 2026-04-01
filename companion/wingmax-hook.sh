#!/bin/bash
# ABOUTME: PostToolUse hook that writes Claude Code activity to a JSON status file.
# ABOUTME: Extracts signals from tool_response for rich WingMax commentary.

STATUS_FILE="$HOME/.claude/companion/status.json"
TEMP_FILE="$HOME/.claude/companion/status.tmp.json"
MAX_EVENTS=50

# Read hook JSON from stdin
INPUT=$(cat)

# ── Language detection from file extension ──
detect_lang() {
  case "${1##*.}" in
    py)             echo "python" ;;
    ts|tsx)         echo "typescript" ;;
    js|jsx|mjs)     echo "javascript" ;;
    html|htm)       echo "html" ;;
    css|scss|less)  echo "css" ;;
    md|mdx)         echo "markdown" ;;
    json)           echo "json" ;;
    yaml|yml)       echo "yaml" ;;
    toml)           echo "toml" ;;
    sh|bash|zsh)    echo "shell" ;;
    rs)             echo "rust" ;;
    go)             echo "go" ;;
    rb)             echo "ruby" ;;
    swift)          echo "swift" ;;
    java)           echo "java" ;;
    c|h)            echo "c" ;;
    cpp|hpp|cc)     echo "cpp" ;;
    sql)            echo "sql" ;;
    *)              echo "" ;;
  esac
}

# ── File category from filename patterns ──
detect_file_category() {
  local name="$1"
  case "$name" in
    *test*|*spec*|*_test.*|*.test.*)  echo "test" ;;
    *.config.*|*rc|*rc.js|*rc.ts|*.toml|*.yaml|*.yml|Makefile|Dockerfile|*.lock|package.json|tsconfig*|wrangler.*)  echo "config" ;;
    *.md|*.txt|*.rst|README*|LICENSE*|CHANGELOG*|CLAUDE.md)  echo "doc" ;;
    *.css|*.scss|*.less)  echo "style" ;;
    *)  echo "source" ;;
  esac
}

# ── Bash command category from command string ──
# Uses the first word/binary of the command to avoid false positives
# from arguments or commit messages that mention "test" etc.
detect_bash_category() {
  local cmd="$1"
  # Extract the first token (the binary being run)
  local bin="${cmd%% *}"
  bin="${bin##*/}"  # strip path

  case "$bin" in
    jest|pytest|vitest|mocha)  echo "test" ;;
    npm|npx)
      case "$cmd" in
        *" test"*|*"npx jest"*|*"npx vitest"*|*"npx playwright test"*)  echo "test" ;;
        *" run build"*|*" run dev"*)  echo "build" ;;
        *" install"*|*" i "*)  echo "install" ;;
        *" start"*|*" run dev"*|*" run serve"*)  echo "server" ;;
        *)  echo "general" ;;
      esac ;;
    cargo)
      case "$cmd" in *" test"*) echo "test" ;; *" build"*) echo "build" ;; *) echo "general" ;; esac ;;
    go)
      case "$cmd" in *" test"*) echo "test" ;; *" build"*) echo "build" ;; *) echo "general" ;; esac ;;
    make|webpack|esbuild|tsc|vite)  echo "build" ;;
    pip|pip3)  echo "install" ;;
    brew)
      case "$cmd" in *install*) echo "install" ;; *) echo "general" ;; esac ;;
    git|gh)  echo "git" ;;
    eslint|prettier|ruff|biome)  echo "lint" ;;
    *)  echo "general" ;;
  esac
}

# ── Extract fields — try jq first, fall back to python3 ──
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

  # ── Extract signals from tool_response ──
  LANG=$(detect_lang "$DETAIL")
  FILE_CAT=$(detect_file_category "$DETAIL")
  HAS_RESPONSE=$(echo "$INPUT" | jq 'has("tool_response")')

  case "$TOOL" in
    Bash)
      BASH_CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
      BASH_CAT=$(detect_bash_category "$BASH_CMD")
      if [ "$HAS_RESPONSE" = "true" ]; then
        # tool_response can be a string OR an object with stdout/stderr fields
        SIGNALS=$(echo "$INPUT" | jq -c --arg cat "$BASH_CAT" '
          (if (.tool_response | type) == "object"
           then ((.tool_response.stdout // "") + "\n" + (.tool_response.stderr // ""))
           else (.tool_response // "" | tostring)
           end) as $resp |
          {
            exit_ok: ($resp | test("(?i)(\\berror\\b|\\bFAIL\\b|\\bfatal\\b|\\bpanic\\b|Traceback|command not found|No such file|Permission denied|ENOENT)") | not),
            category: $cat,
            error_hint: (if ($resp | test("(?i)(\\berror\\b|\\bFAIL\\b|\\bfatal\\b|\\bpanic\\b|Traceback)"))
              then ($resp | split("\n") | map(select(test("(?i)(\\berror\\b|\\bfail\\b|\\bpanic\\b|traceback)"))) | first // "" | .[:80])
              else "" end),
            test_summary: (if ($resp | test("(?i)(passed|failed|Tests:|test result)"))
              then ($resp | split("\n") | map(select(test("(?i)(\\d+.*(passed|failed)|Tests:|test result)"))) | first // "" | .[:60])
              else "" end)
          }' 2>/dev/null)
      else
        SIGNALS=$(jq -n --arg cat "$BASH_CAT" '{category: $cat}')
      fi
      ;;
    Read)
      if [ "$HAS_RESPONSE" = "true" ]; then
        LINE_COUNT=$(echo "$INPUT" | jq '
          (if (.tool_response | type) == "object"
           then (.tool_response.content // .tool_response | tostring)
           else (.tool_response // "" | tostring) end)
          | split("\n") | length' 2>/dev/null)
        SIGNALS=$(jq -n --arg lang "$LANG" --arg fcat "$FILE_CAT" --argjson lc "${LINE_COUNT:-0}" \
          '{lang: $lang, file_category: $fcat, line_count: $lc}')
      else
        SIGNALS=$(jq -n --arg lang "$LANG" --arg fcat "$FILE_CAT" '{lang: $lang, file_category: $fcat}')
      fi
      ;;
    Edit)
      if [ "$HAS_RESPONSE" = "true" ]; then
        EDIT_OK=$(echo "$INPUT" | jq '
          (if (.tool_response | type) == "object"
           then (.tool_response.success // true)
           else ((.tool_response // "" | tostring) | test("(?i)(\\berror\\b|failed)") | not) end)' 2>/dev/null)
        SIGNALS=$(jq -n --arg lang "$LANG" --argjson ok "${EDIT_OK:-true}" '{lang: $lang, success: $ok}')
      else
        SIGNALS=$(jq -n --arg lang "$LANG" '{lang: $lang}')
      fi
      ;;
    Write)
      SIGNALS=$(jq -n --arg lang "$LANG" '{lang: $lang}')
      ;;
    Grep|Glob)
      if [ "$HAS_RESPONSE" = "true" ]; then
        SIGNALS=$(echo "$INPUT" | jq -c '
          (if (.tool_response | type) == "object"
           then (.tool_response.content // .tool_response | tostring)
           else (.tool_response // "" | tostring) end) as $resp |
          ($resp | split("\n") | map(select(length > 0)) | length) as $count |
          {match_count: $count, found: ($count > 0)}' 2>/dev/null)
      else
        SIGNALS='{"found": false, "match_count": 0}'
      fi
      ;;
    *)
      SIGNALS='{}'
      ;;
  esac

  # Fallback if signal extraction failed
  [ -z "$SIGNALS" ] && SIGNALS='{}'

else
  # ── Python3 fallback — extracts everything in one pass ──
  eval "$(echo "$INPUT" | python3 -c "
import sys, json, re, os

d = json.load(sys.stdin)
tool = d.get('tool_name', '')
session = d.get('session_id', '')
cwd = d.get('cwd', '')
ti = d.get('tool_input', {})
tr = str(d.get('tool_response', ''))

# Detail extraction
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

# Language detection
ext_map = {
    'py': 'python', 'ts': 'typescript', 'tsx': 'typescript', 'js': 'javascript',
    'jsx': 'javascript', 'html': 'html', 'htm': 'html', 'css': 'css', 'scss': 'css',
    'md': 'markdown', 'mdx': 'markdown', 'json': 'json', 'yaml': 'yaml', 'yml': 'yaml',
    'toml': 'toml', 'sh': 'shell', 'bash': 'shell', 'rs': 'rust', 'go': 'go',
    'rb': 'ruby', 'swift': 'swift', 'java': 'java', 'c': 'c', 'h': 'c',
    'cpp': 'cpp', 'hpp': 'cpp', 'sql': 'sql'
}
ext = detail.rsplit('.', 1)[-1] if '.' in detail else ''
lang = ext_map.get(ext, '')

# File category
fcat = 'source'
dl = detail.lower()
if any(x in dl for x in ('test', 'spec')): fcat = 'test'
elif any(dl.endswith(x) for x in ('.config.js','.config.ts','rc','rc.js','.toml','.yaml','.yml','.lock')) or dl in ('package.json','makefile','dockerfile'): fcat = 'config'
elif any(dl.endswith(x) for x in ('.md','.txt','.rst')) or dl.startswith(('readme','license','changelog','claude')): fcat = 'doc'
elif any(dl.endswith(x) for x in ('.css','.scss','.less')): fcat = 'style'

# Signal extraction
signals = {}
if tool == 'Bash':
    cmd = ti.get('command', '')
    cl = cmd.lower()
    if any(x in cl for x in ('test','jest','pytest','vitest','cargo test','go test')): signals['category'] = 'test'
    elif any(x in cl for x in ('build','webpack','esbuild','tsc','cargo build','make')): signals['category'] = 'build'
    elif any(x in cl for x in ('install','npm i','pip install','brew install')): signals['category'] = 'install'
    elif 'git ' in cl or 'gh ' in cl: signals['category'] = 'git'
    else: signals['category'] = 'general'
    error_pats = re.compile(r'(?i)(error|FAIL|fatal|panic|Traceback|command not found|No such file|Permission denied|ENOENT)')
    signals['exit_ok'] = not bool(error_pats.search(tr))
    if not signals['exit_ok']:
        for line in tr.split(chr(10)):
            if error_pats.search(line):
                signals['error_hint'] = line.strip()[:80]
                break
    test_pat = re.compile(r'(?i)(\d+.*(?:passed|failed)|Tests:|test result)')
    for line in tr.split(chr(10)):
        if test_pat.search(line):
            signals['test_summary'] = line.strip()[:60]
            break
elif tool == 'Read':
    signals = {'lang': lang, 'file_category': fcat, 'line_count': tr.count(chr(10))}
elif tool == 'Edit':
    signals = {'lang': lang, 'success': 'error' not in tr.lower() and 'failed' not in tr.lower()}
elif tool == 'Write':
    signals = {'lang': lang}
elif tool in ('Grep', 'Glob'):
    lines = [l for l in tr.split(chr(10)) if l.strip()]
    signals = {'match_count': len(lines), 'found': len(lines) > 0}

print(f'TOOL={json.dumps(tool)}')
print(f'SESSION={json.dumps(session)}')
print(f'CWD={json.dumps(cwd)}')
print(f'DETAIL={json.dumps(detail)}')
print(f'SIGNALS={json.dumps(json.dumps(signals))}')
" 2>/dev/null)"
fi

# Skip if no tool detected
[ -z "$TOOL" ] && exit 0

# Session scoping: only process events from the active WingMax session
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

# Build the new event with signals and merge into status file
if command -v jq &>/dev/null; then
  NEW_EVENT=$(jq -n \
    --arg ts "$TIMESTAMP" \
    --arg tool "$TOOL" \
    --arg label "$LABEL" \
    --arg detail "$DETAIL" \
    --arg type "$TYPE" \
    --argjson signals "$SIGNALS" \
    '{ts: $ts, tool: $tool, label: $label, detail: $detail, type: $type, signals: $signals}')

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
signals = json.loads('$SIGNALS') if '$SIGNALS' else {}
event = {'ts': '$TIMESTAMP', 'tool': '$TOOL', 'label': '$LABEL', 'detail': '$DETAIL', 'type': '$TYPE', 'signals': signals}
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
