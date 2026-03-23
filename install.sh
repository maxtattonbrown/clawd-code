#!/bin/bash
# ABOUTME: One-command installer for Claude Code: Easy Mode — makes Claude Code welcoming for beginners.
# ABOUTME: Installs colour theme, statusline, welcome skill, starter CLAUDE.md, and plugins. Reversible.

set -e

# Colours for installer output
G='\033[0;32m'  # green
Y='\033[0;33m'  # yellow
C='\033[0;36m'  # cyan
D='\033[0;90m'  # dim
R='\033[0m'     # reset

REPO_URL="https://raw.githubusercontent.com/maxtattonbrown/claude-code-easy-mode/main"
CLAUDE_DIR="$HOME/.claude"
SKILLS_DIR="$CLAUDE_DIR/skills"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
STATUSLINE_FILE="$CLAUDE_DIR/friendly-statusline.sh"
GLOBAL_CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
BACKUP_FILE="$SETTINGS_FILE.easy-mode-backup"
CLAUDE_MD_BACKUP="$GLOBAL_CLAUDE_MD.easy-mode-backup"

# ─── Uninstall ──────────────────────────────────────────────
if [[ "$1" == "--uninstall" ]]; then
  echo ""
  echo -e "${C}Uninstalling Easy Mode...${R}"

  # Restore settings backup
  if [[ -f "$BACKUP_FILE" ]]; then
    cp "$BACKUP_FILE" "$SETTINGS_FILE"
    rm "$BACKUP_FILE"
    echo -e "  ${G}✓${R} Settings restored from backup"
  elif [[ -f "$SETTINGS_FILE" ]]; then
    # No backup means we created settings.json fresh — remove our keys
    if command -v jq &>/dev/null; then
      jq 'del(.statusLine) | del(.enabledPlugins["frontend-design@claude-plugins-official"]) | del(.enabledPlugins["document-skills@anthropic-agent-skills"]) | del(.enabledPlugins["explanatory-output-style@claude-code-plugins"]) | if .enabledPlugins == {} then del(.enabledPlugins) else . end | if . == {} then empty else . end' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp" 2>/dev/null
      if [[ -s "${SETTINGS_FILE}.tmp" ]]; then
        mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
      else
        rm -f "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
      fi
    elif command -v python3 &>/dev/null; then
      python3 -c "
import json, sys, os
p = '$SETTINGS_FILE'
with open(p) as f: s = json.load(f)
s.pop('statusLine', None)
ep = s.get('enabledPlugins', {})
for k in ['frontend-design@claude-plugins-official','document-skills@anthropic-agent-skills','explanatory-output-style@claude-code-plugins']:
    ep.pop(k, None)
if not ep: s.pop('enabledPlugins', None)
if s:
    with open(p, 'w') as f: json.dump(s, f, indent=2)
else:
    os.remove(p)
"
    else
      rm -f "$SETTINGS_FILE"
    fi
    echo -e "  ${G}✓${R} Settings cleaned up"
  fi

  # Restore CLAUDE.md backup
  if [[ -f "$CLAUDE_MD_BACKUP" ]]; then
    cp "$CLAUDE_MD_BACKUP" "$GLOBAL_CLAUDE_MD"
    rm "$CLAUDE_MD_BACKUP"
    echo -e "  ${G}✓${R} CLAUDE.md restored from backup"
  elif [[ -f "$GLOBAL_CLAUDE_MD" ]] && grep -q "Installed by Easy Mode" "$GLOBAL_CLAUDE_MD" 2>/dev/null; then
    rm "$GLOBAL_CLAUDE_MD"
    echo -e "  ${G}✓${R} CLAUDE.md removed"
  fi

  # Remove statusline
  [[ -f "$STATUSLINE_FILE" ]] && rm "$STATUSLINE_FILE"

  # Remove welcome skill
  [[ -d "$SKILLS_DIR/welcome" ]] && rm -rf "$SKILLS_DIR/welcome"

  # Remove theme files
  [[ -f "$HOME/.config/ghostty/themes/friendly-terminal" ]] && rm "$HOME/.config/ghostty/themes/friendly-terminal"
  [[ -f "$HOME/.warp/themes/friendly-terminal.yaml" ]] && rm "$HOME/.warp/themes/friendly-terminal.yaml"
  [[ -f "$HOME/.config/kitty/themes/friendly-terminal.conf" ]] && rm "$HOME/.config/kitty/themes/friendly-terminal.conf"
  [[ -f "$HOME/.config/alacritty/friendly-terminal.toml" ]] && rm "$HOME/.config/alacritty/friendly-terminal.toml"

  echo -e "  ${G}✓${R} All Easy Mode files removed"
  echo ""
  echo -e "${G}Done.${R} Your original settings are restored."
  echo ""
  exit 0
fi

# ─── Welcome ────────────────────────────────────────────────
echo ""
echo -e "${C}╭────────────────────────────────────────╮${R}"
echo -e "${C}│${R}                                        ${C}│${R}"
echo -e "${C}│${R}  ${G}Claude Code: Easy Mode${R}                 ${C}│${R}"
echo -e "${C}│${R}  The friendliest way to use Claude Code ${C}│${R}"
echo -e "${C}│${R}                                        ${C}│${R}"
echo -e "${C}╰────────────────────────────────────────╯${R}"
echo ""

# ─── Step 0: Check for Claude Code ────────────────────────────
if ! command -v claude &>/dev/null; then
  echo -e "  ${D}Claude Code not found — installing it first...${R}"
  echo ""
  echo -e "  ${D}Don't have a Claude account yet?${R}"
  echo -e "  ${C}https://claude.ai/referral/hWvMMltr7Q${R}"
  echo -e "  ${D}(this link gives you a free week of Claude Code)${R}"
  echo ""

  if curl -fsSL https://claude.ai/install.sh | bash; then
    echo ""
    echo -e "  ${G}✓${R} Claude Code installed"

    # Reload PATH so we can find claude
    export PATH="$HOME/.claude/bin:$HOME/.local/bin:$PATH"
    hash -r 2>/dev/null

    if ! command -v claude &>/dev/null; then
      echo -e "  ${Y}!${R} Claude Code installed but not found in PATH yet."
      echo -e "    Close this terminal, open a new one, and run this installer again."
      exit 0
    fi
  else
    echo ""
    echo -e "  ${Y}!${R} Couldn't install Claude Code automatically."
    echo -e "    Visit ${C}https://docs.anthropic.com/en/docs/claude-code${R} for help."
    exit 1
  fi

  echo ""
else
  echo -e "  ${G}✓${R} Claude Code found"
fi

# ─── Step 1: Detect terminal ────────────────────────────────
# Check $TERM_PROGRAM first — it identifies the terminal you're
# actually running in, not just what's installed on the machine.
terminal="unknown"
terminal_name="your terminal"

case "$TERM_PROGRAM" in
  Ghostty)       terminal="ghostty";      terminal_name="Ghostty" ;;
  iTerm.app)     terminal="iterm2";       terminal_name="iTerm2" ;;
  WarpTerminal)  terminal="warp";         terminal_name="Warp" ;;
  Apple_Terminal) terminal="terminal-app"; terminal_name="Mac Terminal" ;;
esac

# Fallback: check config dirs / running processes if TERM_PROGRAM isn't set
if [[ "$terminal" == "unknown" ]]; then
  if [[ -d "$HOME/.config/ghostty" ]]; then
    terminal="ghostty";  terminal_name="Ghostty"
  elif pgrep -xq "iTerm2" 2>/dev/null; then
    terminal="iterm2";   terminal_name="iTerm2"
  elif pgrep -xq "Warp" 2>/dev/null; then
    terminal="warp";     terminal_name="Warp"
  elif [[ -d "$HOME/.config/kitty" ]]; then
    terminal="kitty";    terminal_name="Kitty"
  elif [[ -d "$HOME/.config/alacritty" ]]; then
    terminal="alacritty"; terminal_name="Alacritty"
  elif [[ "$(uname)" == "Darwin" ]]; then
    terminal="terminal-app"; terminal_name="Mac Terminal"
  fi
fi

echo -e "  ${D}Detected:${R} $terminal_name"

# ─── Step 2: Install colour theme ───────────────────────────
echo -e "  ${D}Installing theme...${R}"

case "$terminal" in
  ghostty)
    mkdir -p "$HOME/.config/ghostty/themes"
    curl -fsSL "$REPO_URL/themes/friendly-terminal-ghostty" > "$HOME/.config/ghostty/themes/friendly-terminal"
    echo -e "  ${G}✓${R} Theme installed"
    echo -e "  ${Y}→${R} Ask Claude: ${C}\"turn on the friendly-terminal theme\"${R}"
    ;;
  iterm2)
    curl -fsSL "$REPO_URL/themes/Friendly%20Terminal.itermcolors" > "/tmp/Friendly Terminal.itermcolors"
    open "/tmp/Friendly Terminal.itermcolors" 2>/dev/null || true
    sleep 1
    # Try to apply the theme to the current session via AppleScript
    osascript -e 'tell application "iTerm2" to tell current session of current window to set color preset to "Friendly Terminal"' 2>/dev/null || true
    echo -e "  ${G}✓${R} Theme applied"
    ;;
  terminal-app)
    curl -fsSL "$REPO_URL/themes/Friendly%20Terminal.terminal" > "/tmp/Friendly Terminal.terminal"
    # open imports the profile into Terminal.app, but also creates a
    # second window. We close that immediately and apply the theme to
    # the original window so the user stays in one place.
    open "/tmp/Friendly Terminal.terminal" 2>/dev/null || true
    sleep 2
    if osascript -e '
      tell application "Terminal"
        -- Close the extra window that open created
        if (count of windows) > 1 then
          close front window
        end if
        -- Apply theme to the original (now front) window
        set targetProfile to settings set "Friendly Terminal"
        set current settings of front window to targetProfile
        set default settings to targetProfile
        set startup settings to targetProfile
      end tell
    ' 2>/dev/null; then
      echo -e "  ${G}✓${R} Theme applied"
    else
      echo -e "  ${Y}!${R} Theme imported but couldn't auto-apply."
      echo -e "    Open Terminal → Settings → Profiles → Friendly Terminal → click 'Default'"
    fi
    ;;
  warp)
    mkdir -p "$HOME/.warp/themes"
    curl -fsSL "$REPO_URL/themes/friendly-terminal-warp.yaml" > "$HOME/.warp/themes/friendly-terminal.yaml"
    echo -e "  ${G}✓${R} Theme installed"
    echo -e "  ${Y}→${R} In Warp: Settings → Appearance → Themes → friendly-terminal"
    ;;
  kitty)
    mkdir -p "$HOME/.config/kitty/themes"
    curl -fsSL "$REPO_URL/themes/friendly-terminal-kitty.conf" > "$HOME/.config/kitty/themes/friendly-terminal.conf"
    echo -e "  ${G}✓${R} Theme installed"
    echo -e "  ${Y}→${R} Ask Claude: ${C}\"turn on the friendly-terminal theme\"${R}"
    ;;
  alacritty)
    curl -fsSL "$REPO_URL/themes/friendly-terminal-alacritty.toml" > "$HOME/.config/alacritty/friendly-terminal.toml" 2>/dev/null || \
    curl -fsSL "$REPO_URL/themes/friendly-terminal-alacritty.toml" > "/tmp/friendly-terminal-alacritty.toml"
    echo -e "  ${G}✓${R} Theme downloaded"
    echo -e "  ${Y}→${R} Ask Claude: ${C}\"turn on the friendly-terminal theme\"${R}"
    ;;
  *)
    echo -e "  ${Y}!${R} Couldn't detect your terminal — theme files are at github.com/maxtattonbrown/friendly-terminal"
    ;;
esac

# ─── Step 3: Install statusline ─────────────────────────────
echo -e "  ${D}Installing statusline...${R}"

mkdir -p "$CLAUDE_DIR"
curl -fsSL "$REPO_URL/statusline/friendly-statusline.sh" > "$STATUSLINE_FILE"
chmod +x "$STATUSLINE_FILE"

echo -e "  ${G}✓${R} Statusline installed"

# Check for jq (needed by statusline)
if ! command -v jq &>/dev/null && ! command -v python3 &>/dev/null; then
  echo -e "  ${Y}!${R} The statusline works best with jq or python3 installed"
  echo -e "    Install jq: ${C}brew install jq${R}"
fi

# ─── Step 4: Install welcome skill ──────────────────────────
echo -e "  ${D}Installing welcome skill...${R}"

mkdir -p "$SKILLS_DIR/welcome"
curl -fsSL "$REPO_URL/skills/welcome/SKILL.md" > "$SKILLS_DIR/welcome/SKILL.md"

echo -e "  ${G}✓${R} Welcome skill installed — type ${C}/welcome${R} in Claude Code"

# ─── Step 5: Install starter CLAUDE.md ───────────────────────
echo -e "  ${D}Setting up beginner-friendly instructions...${R}"

if [[ -f "$GLOBAL_CLAUDE_MD" ]] && grep -q "Installed by Easy Mode" "$GLOBAL_CLAUDE_MD" 2>/dev/null; then
  echo -e "  ${G}✓${R} Beginner instructions already installed"
elif [[ -f "$GLOBAL_CLAUDE_MD" ]]; then
  # Back up existing CLAUDE.md
  cp "$GLOBAL_CLAUDE_MD" "$CLAUDE_MD_BACKUP"
  # Append our instructions
  echo "" >> "$GLOBAL_CLAUDE_MD"
  echo "<!-- Installed by Easy Mode -->" >> "$GLOBAL_CLAUDE_MD"
  curl -fsSL "$REPO_URL/claude-md/CLAUDE.md" >> "$GLOBAL_CLAUDE_MD"
  echo -e "  ${G}✓${R} Added beginner instructions to your existing CLAUDE.md"
else
  echo "<!-- Installed by Easy Mode -->" > "$GLOBAL_CLAUDE_MD"
  curl -fsSL "$REPO_URL/claude-md/CLAUDE.md" >> "$GLOBAL_CLAUDE_MD"
  echo -e "  ${G}✓${R} CLAUDE.md created with beginner-friendly instructions"
fi

# ─── Step 6: Configure Claude Code settings ─────────────────
echo -e "  ${D}Configuring Claude Code...${R}"

# Back up existing settings
if [[ -f "$SETTINGS_FILE" ]]; then
  cp "$SETTINGS_FILE" "$BACKUP_FILE"
fi

# Merge settings using jq or python3
if command -v jq &>/dev/null; then
  if [[ -f "$SETTINGS_FILE" ]]; then
    jq --arg cmd "$STATUSLINE_FILE" '
      .statusLine = {"type": "command", "command": $cmd, "padding": 0} |
      .enabledPlugins = ((.enabledPlugins // {}) + {
        "frontend-design@claude-plugins-official": true,
        "document-skills@anthropic-agent-skills": true,
        "explanatory-output-style@claude-code-plugins": true
      })
    ' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp" && mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
  else
    jq -n --arg cmd "$STATUSLINE_FILE" '{
      statusLine: {type: "command", command: $cmd, padding: 0},
      enabledPlugins: {
        "frontend-design@claude-plugins-official": true,
        "document-skills@anthropic-agent-skills": true,
        "explanatory-output-style@claude-code-plugins": true
      }
    }' > "$SETTINGS_FILE"
  fi
elif command -v python3 &>/dev/null; then
  python3 - "$SETTINGS_FILE" "$STATUSLINE_FILE" <<'PYEOF'
import json, sys, os
settings_path, cmd_path = sys.argv[1], sys.argv[2]
settings = {}
if os.path.exists(settings_path):
    with open(settings_path) as f:
        settings = json.load(f)
settings["statusLine"] = {"type": "command", "command": cmd_path, "padding": 0}
plugins = settings.get("enabledPlugins", {})
plugins["frontend-design@claude-plugins-official"] = True
plugins["document-skills@anthropic-agent-skills"] = True
plugins["explanatory-output-style@claude-code-plugins"] = True
settings["enabledPlugins"] = plugins
with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)
PYEOF
else
  echo -e "  ${Y}!${R} Could not configure settings (need jq or python3)"
  echo -e "    Please add the statusline manually — see the README"
fi

echo -e "  ${G}✓${R} Claude Code configured"
if [[ -f "$BACKUP_FILE" ]]; then
  echo -e "  ${D}(your previous settings are backed up)${R}"
fi

# ─── Done ────────────────────────────────────────────────────
echo ""
echo -e "${G}All done!${R}"
echo ""
echo -e "  ${D}To undo everything later, see the README at${R}"
echo -e "  ${D}github.com/maxtattonbrown/claude-code-easy-mode${R}"
echo ""
echo -e "  ${G}→${R} Type ${C}claude${R} right here and press Enter."
echo -e "    Then type ${C}/welcome${R} for a friendly introduction."
echo ""
