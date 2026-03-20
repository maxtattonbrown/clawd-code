#!/bin/bash
# ABOUTME: Clawd Code status line — traffic light context indicator with rotating tips for beginners.
# ABOUTME: Shows context health, model warnings, project name, and helpful suggestions. No special fonts needed.

input=$(cat)

# Parse JSON — try jq first, fall back to python3
if command -v jq &>/dev/null; then
  pct=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | awk '{printf "%d", $1}')
  raw_model=$(echo "$input" | jq -r 'if .model | type == "object" then .model.display_name else .model end // "unknown"')
  cwd=$(echo "$input" | jq -r '.workspace.current_dir // "."')
elif command -v python3 &>/dev/null; then
  eval "$(echo "$input" | python3 -c "
import sys, json
d = json.load(sys.stdin)
m = d.get('model', 'unknown')
if isinstance(m, dict): m = m.get('display_name', 'unknown')
pct = int(d.get('context_window', {}).get('used_percentage', 0))
cwd = d.get('workspace', {}).get('current_dir', '.')
print(f'pct={pct}')
print(f'raw_model=\"{m}\"')
print(f'cwd=\"{cwd}\"')
")"
else
  printf "📁 Claude Code\n"
  exit 0
fi

project=$(basename "$cwd")

# Model warning — only shown when not on the best model
model_warn=""
if echo "$raw_model" | grep -qi "haiku\|sonnet"; then
  model_warn=" · ⚡ Fast mode"
fi

# Context traffic light
if (( pct >= 60 )); then
  printf "🔴 Running low on context — type /compact now · %s%s\n" "$project" "$model_warn"
elif (( pct >= 40 )); then
  printf "🟡 Context filling up — type /compact · %s%s\n" "$project" "$model_warn"
else
  # Green state — show a rotating tip (changes every 2 minutes)
  tips=(
    "Try: \"explain this code to me\""
    "Try: \"make me a website about dogs\""
    "Type /help to see what you can do"
    "You can ask Claude to fix any error you see"
    "Try: \"what does this project do?\""
    "Say \"undo that\" if something goes wrong"
    "Try: \"add a button that says hello\""
    "Press Escape to stop Claude mid-task"
    "You can paste an error message and ask for help"
    "Try: \"write this in simpler code\""
    "Try: \"what should I do next?\""
    "Type /clear to start a fresh conversation"
  )

  # Rotate based on the minute (changes every 2 min)
  minute=$(date +%M)
  tip_index=$(( (minute / 2) % ${#tips[@]} ))
  tip="${tips[$tip_index]}"

  printf "🟢 %s · %s%s\n" "$tip" "$project" "$model_warn"
fi
