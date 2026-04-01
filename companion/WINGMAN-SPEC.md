# Wingman — Design Spec

## What it is

Wingman is a browser companion for Claude Code. A little character `>_` that sits in a browser window next to the terminal, watches what Claude does, and helps you use it better + more effectively. It teaches you little bits about how coding works, suggests Claude Code features you may not know and helps you get acquainted with what’s possible.

It blinks, it comments, it suggests what to try next. It's the friendly face of the Claude Code.

## Who it's for

**One journey from day one, to day 100:**

### Beginners (Easy Mode users)
People who've never used a terminal. They need comfort, explanation, and a sense that everything is OK. Wingman explains what Claude did in human terms, suggests what to try next, and shows them what they made.

### Intermediate users
As they get going, there’s more and more to learn about working this way. They don't need everything explained, but there are always new things to learn about how you build things reliably, how you use Claude Code to its maximum extent (subagents, Ralph loops, caching, local servers etc etc). 

## The character

Wingman is `>_` — a side on face made from terminal symbols.

- `>` is the eye
- `_` is the mouth
- The eye blinks every 8–20 seconds (briefly becomes `-_`)
- When Claude finishes, Wingman bounces and blinks
- When Claude is working, the mouth wobbles in animated fashion: `>_-`
- The coral square is the face. It's always visible, always watching.

**Personality:** A familiar collaborator who's been using Claude Code since it came out. Not a teacher, not a manual, not an assistant. A mate who has been there, done that, supporting you with encouragement, clarification and suggestions as you get to know it. Warm, brief, occasionally witty. Never patronising. Never verbose.

**Voice rules:**
-
- First person ("I" / "you"), never third person or passive
- Short sentences. One idea per sentence.
- Reacts to what happened with useful info.
- Never uses AI-speak

## How it works

### Architecture

```
Claude Code ──[hooks]──> status.json ──[polling]──> wingman.html
                              ↑
                        wingman-server.py (localhost:7788)
```

- **PostToolUse hook** (async): After each tool call, writes event to `~/.claude/companion/status.json`
- **Stop hook** (async): When Claude finishes responding, sets `stopped: true`
- **Python server**: Serves the HTML page and status file on localhost:7788. Also serves project files for the live preview.
- **wingman.html**: Single self-contained file. Polls status.json, renders the UI.

### What the page shows

One speech bubble from `>_`. Updates after each Claude response. Three things:

1. **Comment** — what Claude just did, in human terms
2. **Files** — names of files created/edited (small, monospace, below the comment)
3. **Suggestion** — what to try next (in a dashed box below the bubble)

Plus:
- **Preview** — when Claude creates HTML files, an iframe shows the result
- **Footer** — "You can't break anything" + link to Claude Code docs

### States

| State | Avatar | Bubble | Suggestion |
|---|---|---|---|
| Welcome | `>_` blinking | "Hey! I'm Wingman..." | "In your terminal, try typing: hello" |
| Ready | `>_` blinking | "Claude Code is ready! Ask it anything..." | First suggestion |
| Working | `>_-_` dots | "Claude's working..." (muted) | Hidden |
| Done | bounce + blink | Comment on what happened | "You could try: ..." |

## Modes

### Beginner mode (default)

- Commentary explains concepts: "Claude always reads files before acting."
- Suggestions are task-oriented: “make it 10x better", "check it for mistakes", "try something completely different"
- Opening suggestions show the range: emails, websites, file organisation, planning, explaining
- Footer says "You can't break anything"
- First-time concepts explained once, then kept short on repeat

### Intermediate mode

- Commentary is action/ decision-led: “Claude will always check files but rarely more or reorganise them - that requires you to ask."
- Suggestions reference Claude Code features: "review the diff", "commit this", "type /compact — context is getting full"
- Will suggest Claude Code features and developer approaches you might not be aware of if it senses they may help you.
- Opening suggestions assume familiarity: "refactor the auth flow", "write tests for the API", "explain this codebase to me"
- Footer links to advanced docs
- No concept explanations — just what happened and what to do next

Mode is set at install time and stored in `~/.claude/companion/config.json`:
```json
{ "mode": "beginner" }
```

Can be changed anytime.

## Install / Uninstall

### Standalone install (not via Easy Mode)

```bash
curl -fsSL https://raw.githubusercontent.com/maxtattonbrown/wingman/main/install.sh | bash
```

The installer:
1. Downloads companion files to `~/.claude/companion/`
2. Adds PostToolUse + Stop hooks to `~/.claude/settings.json`
3. Adds `wingman` shell alias to `~/.zshrc` / `~/.bashrc`
4. Asks: "Are you new to Claude Code?" → sets beginner or intermediate mode

### Via Easy Mode

Easy Mode install includes Wingman in beginner mode automatically. No separate install needed.

### The `wingman` command

```bash
wingman          # Reset status, start server, open browser, launch Claude Code
wingman --open   # Just open the page (server already running)
wingman --stop   # Stop the server
wingman --mode beginner|intermediate   # Switch mode
```

### Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/maxtattonbrown/wingman/main/install.sh | bash -s -- --uninstall
```

Removes all files, hooks, and alias. Restores original settings.json if backed up.

## Technical constraints

- **No npm/node** — Python 3 + bash only (ships with macOS)
- **No build step** — single HTML file with inline CSS/JS
- **Async hooks** — never blocks Claude Code
- **Single status file** — needs session scoping to avoid cross-session bleed
- **Works offline** — no external fonts, CDNs, or API calls
- **macOS primary** — `open` command for browser. Linux support via `xdg-open` fallback.

## Session scoping

Problem: hooks fire across all Claude Code sessions, writing to the same status file.

Solution: The `wingman` launcher writes the launched session's ID to `~/.claude/companion/active-session`. The hook scripts check: if the event's `session_id` doesn't match, skip it. Only the Wingman session's events appear on the page.

## What's NOT in scope (for now)

- Multi-session support (watching multiple Claude sessions)
- Chat-back (typing in Wingman to send to Claude)
- History (previous sessions)
- Mobile/responsive (it's a desktop companion)
- Browser extension version
- Customisable themes or avatar

## Open questions

- **Should intermediate mode show a mini activity log?** A few lines of what happened, not just the summary. Might be useful for long tasks. Could be a collapsible "details" section.
- **Should Wingman have a name beyond "Wingman"?** The `>_` character could have a proper name. Or maybe `>_` IS the name.
- **Could Wingman comment during work, not just after?** E.g. "Ooh, Claude's reading a lot of files — this might take a minute." Needs care to avoid the noise problem we hit earlier.
- **Repo structure**: Separate repo (`wingman`) or stays inside `claude-code-easy-mode`? Leaning separate since it's now a standalone addon.

## Files

```
wingman/
├── install.sh              # Standalone installer
├── companion/
│   ├── wingman.html        # The page
│   ├── wingman-hook.sh     # PostToolUse hook
│   ├── wingman-stop-hook.sh # Stop hook
│   ├── wingman-server.py   # Local HTTP server
│   └── wingman.sh          # Launcher (the `wingman` command)
├── README.md
└── screenshot.png
```

All install to `~/.claude/companion/`.
