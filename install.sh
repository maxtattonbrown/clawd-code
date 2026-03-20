#!/bin/bash
# ABOUTME: One-command installer for Clawd Code — makes Claude Code welcoming for beginners.
# ABOUTME: Installs colour theme, statusline, welcome skill, starter CLAUDE.md, and plugins. Reversible.

set -e

# Colours for installer output
G='\033[0;32m'  # green
Y='\033[0;33m'  # yellow
C='\033[0;36m'  # cyan
D='\033[0;90m'  # dim
R='\033[0m'     # reset

REPO_URL="https://raw.githubusercontent.com/maxtattonbrown/clawd-code/main"
CLAUDE_DIR="$HOME/.claude"
SKILLS_DIR="$CLAUDE_DIR/skills"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
STATUSLINE_FILE="$CLAUDE_DIR/friendly-statusline.sh"
GLOBAL_CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
BACKUP_FILE="$SETTINGS_FILE.clawd-backup"
CLAUDE_MD_BACKUP="$GLOBAL_CLAUDE_MD.clawd-backup"

# ─── Uninstall ──────────────────────────────────────────────
if [[ "$1" == "--uninstall" ]]; then
  echo ""
  echo -e "${C}Uninstalling Clawd Code...${R}"

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
    fi
    echo -e "  ${G}✓${R} Settings cleaned up"
  fi

  # Restore CLAUDE.md backup
  if [[ -f "$CLAUDE_MD_BACKUP" ]]; then
    cp "$CLAUDE_MD_BACKUP" "$GLOBAL_CLAUDE_MD"
    rm "$CLAUDE_MD_BACKUP"
    echo -e "  ${G}✓${R} CLAUDE.md restored from backup"
  elif [[ -f "$GLOBAL_CLAUDE_MD" ]] && grep -q "Installed by Clawd Code" "$GLOBAL_CLAUDE_MD" 2>/dev/null; then
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

  echo -e "  ${G}✓${R} All Clawd Code files removed"
  echo ""
  echo -e "${G}Done.${R} Your original settings are restored."
  echo ""
  exit 0
fi

# ─── Welcome ────────────────────────────────────────────────
echo ""
echo -e "${C}╭────────────────────────────────────────╮${R}"
echo -e "${C}│${R}                                        ${C}│${R}"
echo -e "${C}│${R}  🐾 ${G}Clawd Code${R}                          ${C}│${R}"
echo -e "${C}│${R}  The friendliest way to use Claude Code ${C}│${R}"
echo -e "${C}│${R}                                        ${C}│${R}"
echo -e "${C}╰────────────────────────────────────────╯${R}"
echo ""

# ─── Step 1: Detect terminal ────────────────────────────────
terminal="unknown"
terminal_name="your terminal"

if [[ -d "$HOME/.config/ghostty" ]]; then
  terminal="ghostty"
  terminal_name="Ghostty"
elif pgrep -xq "iTerm2" 2>/dev/null; then
  terminal="iterm2"
  terminal_name="iTerm2"
elif pgrep -xq "Warp" 2>/dev/null; then
  terminal="warp"
  terminal_name="Warp"
elif [[ -d "$HOME/.config/kitty" ]]; then
  terminal="kitty"
  terminal_name="Kitty"
elif [[ -d "$HOME/.config/alacritty" ]]; then
  terminal="alacritty"
  terminal_name="Alacritty"
elif [[ "$(uname)" == "Darwin" ]]; then
  terminal="terminal-app"
  terminal_name="Mac Terminal"
fi

echo -e "  ${D}Detected:${R} $terminal_name"

# ─── Step 2: Install colour theme ───────────────────────────
echo -e "  ${D}Installing theme...${R}"

case "$terminal" in
  ghostty)
    mkdir -p "$HOME/.config/ghostty/themes"
    curl -fsSL "$REPO_URL/themes/friendly-terminal-ghostty" > "$HOME/.config/ghostty/themes/friendly-terminal"
    echo -e "  ${G}✓${R} Theme installed"
    echo -e "  ${Y}→${R} Add ${C}theme = friendly-terminal${R} to ~/.config/ghostty/config"
    ;;
  iterm2)
    curl -fsSL "$REPO_URL/themes/Friendly%20Terminal.itermcolors" > "/tmp/Friendly Terminal.itermcolors"
    open "/tmp/Friendly Terminal.itermcolors" 2>/dev/null || true
    echo -e "  ${G}✓${R} Theme imported into iTerm2"
    echo -e "  ${Y}→${R} Select it in Settings → Profiles → Colors → Color Presets"
    ;;
  terminal-app)
    curl -fsSL "$REPO_URL/themes/Friendly%20Terminal.terminal" > "/tmp/Friendly Terminal.terminal"
    open "/tmp/Friendly Terminal.terminal" 2>/dev/null || true
    echo -e "  ${G}✓${R} Theme imported into Terminal"
    echo -e "  ${Y}→${R} Set as default: Terminal → Settings → Profiles → select Friendly Terminal → Default"
    ;;
  warp)
    mkdir -p "$HOME/.warp/themes"
    curl -fsSL "$REPO_URL/themes/friendly-terminal-warp.yaml" > "$HOME/.warp/themes/friendly-terminal.yaml"
    echo -e "  ${G}✓${R} Theme installed"
    echo -e "  ${Y}→${R} Select it in Settings → Appearance → Themes"
    ;;
  kitty)
    mkdir -p "$HOME/.config/kitty/themes"
    curl -fsSL "$REPO_URL/themes/friendly-terminal-kitty.conf" > "$HOME/.config/kitty/themes/friendly-terminal.conf"
    echo -e "  ${G}✓${R} Theme installed"
    echo -e "  ${Y}→${R} Add ${C}include themes/friendly-terminal.conf${R} to ~/.config/kitty/kitty.conf"
    ;;
  alacritty)
    curl -fsSL "$REPO_URL/themes/friendly-terminal-alacritty.toml" > "$HOME/.config/alacritty/friendly-terminal.toml" 2>/dev/null || \
    curl -fsSL "$REPO_URL/themes/friendly-terminal-alacritty.toml" > "/tmp/friendly-terminal-alacritty.toml"
    echo -e "  ${G}✓${R} Theme downloaded"
    echo -e "  ${Y}→${R} Import it in your alacritty.toml"
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

if [[ -f "$GLOBAL_CLAUDE_MD" ]]; then
  # Back up existing CLAUDE.md
  cp "$GLOBAL_CLAUDE_MD" "$CLAUDE_MD_BACKUP"
  # Append our instructions
  echo "" >> "$GLOBAL_CLAUDE_MD"
  echo "<!-- Installed by Clawd Code -->" >> "$GLOBAL_CLAUDE_MD"
  curl -fsSL "$REPO_URL/claude-md/CLAUDE.md" >> "$GLOBAL_CLAUDE_MD"
  echo -e "  ${G}✓${R} Added beginner instructions to your existing CLAUDE.md"
else
  echo "<!-- Installed by Clawd Code -->" > "$GLOBAL_CLAUDE_MD"
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
echo -e "${G}All done!${R} 🐾"
echo ""
echo -e "  Open Claude Code and you'll see:"
echo -e "  · A status bar with tips and context health"
echo -e "  · Type ${C}/welcome${R} for a friendly introduction"
echo -e "  · Claude will explain what it's doing as it goes"
echo ""
echo -e "  ${D}To undo everything:${R}"
echo -e "  ${C}curl -fsSL $REPO_URL/install.sh | bash -s -- --uninstall${R}"
echo ""
