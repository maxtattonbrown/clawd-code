# 🐾 Clawd Code

The friendliest way to use [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/maxtattonbrown/clawd-code/main/install.sh | bash
```

One command. That's it.

## What it does

**1. Warm colour theme** — replaces the black void with a parchment background, soft text, and coral accents. Auto-detects your terminal (Terminal.app, Ghostty, iTerm2, Warp, Kitty, Alacritty).

**2. Helpful status bar** — a traffic light at the bottom that tells you what's going on:

```
🟢 Try: "make me a website about dogs" · my-project
🟡 Context filling up — type /compact · my-project
🔴 Running low on context — type /compact now · my-project
```

When everything's fine, it shows tips and suggestions. When your conversation is getting long, it tells you exactly what to do.

**3. Welcome skill** — type `/welcome` in Claude Code for a friendly introduction. Three things to try, no jargon.

**4. Beginner-friendly instructions** — tells Claude to explain what it's doing, use simple language, and suggest next steps. Automatically applied to every session.

**5. Useful plugins** — enables frontend design (build web pages), document skills (PDFs, docs, spreadsheets), and explanatory mode (Claude narrates its thinking).

## What's the status bar telling me?

When you chat with Claude Code, it keeps track of everything you've said in the conversation. This is called "context." The longer you talk, the more context builds up — and eventually Claude starts to forget the earlier parts.

The status bar watches this for you:

- **🟢 Green** — you're fine. You'll see a rotating tip or suggestion.
- **🟡 Yellow** — conversation is getting long. Type `/compact` to let Claude summarise and free up space.
- **🔴 Red** — you really need to type `/compact` now, or start a new conversation.

You might also see **⚡ Fast mode** — this means Claude is running on a quicker but less capable model. Usually a plan limit thing, nothing you need to fix.

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/maxtattonbrown/clawd-code/main/install.sh | bash -s -- --uninstall
```

Restores your original settings. Nothing permanent.

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed
- macOS or Linux
- `jq` or `python3` (for the status bar — most Macs have python3)

## Credits

Made by [Max Tatton-Brown](https://github.com/maxtattonbrown). The colour theme is [Friendly Terminal](https://github.com/maxtattonbrown/friendly-terminal).
