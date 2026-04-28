---
name: autopilot-help
description: Quick reference card for Claude Code Autopilot — commands, safety levels, backup/restore, test-gate flow
---

# Autopilot Help — Quick Reference

## What is autopilot mode?

Autopilot mode makes Claude operate autonomously: it executes tasks end-to-end without asking for confirmation, selects tools and approaches on its own, and only pauses at a test gate before declaring a task complete. A workspace backup is taken on activation so work can be restored if something goes wrong.

---

## Commands

| Command | Description |
|---|---|
| `/autopilot strict` | Activate strict mode — broad auto-permissions, but halts before destructive operations (rm -rf, force push, DROP TABLE, writing credentials) |
| `/autopilot normal` | Activate normal mode — same auto-permissions as strict plus package managers, curl, chmod, mv; no halt gate for destructive ops |
| `/autopilot yolo` | Activate yolo mode — bypasses all permission prompts (`bypassPermissions`); no halts, no gates |
| `/autopilot off` | Deactivate autopilot, remove injected settings, and delete the workspace backup |
| `/autopilot status` | Show current mode, activation time, workspace path, backup path, and session log location |

---

## Safety Levels

| Mode | Auto-allowed | Halts before |
|---|---|---|
| **strict** | git, npm, node, python3, uv, ls, find, mkdir, cat, echo, grep, sed, cp, touch, which; Read/Edit/Write all files; all MCP tools | `rm -rf`, force push, `DROP TABLE`, writing credentials/secrets |
| **normal** | Everything in strict plus: curl, pip/pip3, brew, apt/apt-get, systemctl, chmod, mv, tar, unzip, env, npx, pnpm | Nothing — no halt gates |
| **yolo** | Everything (`bypassPermissions`) | Nothing — no halt gates |

---

## Test-Gate Flow

When Claude finishes implementing a task in autopilot mode, it does **not** silently declare done. Instead it says:

> "Please test [what was built / how to test it]. If you want to add or change anything before we wrap up, just type it — otherwise confirm test results."

- If you type additional requirements: Claude implements them and re-presents the gate.
- If you confirm success: Claude says "Complete. Test again or end?" and waits.
- If you say "end": Claude deletes the backup and runs `/autopilot off`.

This gate is the only interruption in an otherwise uninterrupted execution flow.

---

## Backup and Restore

- **On activation**: Claude runs `autopilot-backup.sh`, which copies the workspace with `cp -r` (never `mv`) to a timestamped directory. The backup path is stored in `~/.claude/autopilot-state.json`.
- **Manual restore**: If tests fail and you need to roll back, Claude runs `autopilot-restore.sh` (also `cp -r`, never `mv`), then re-applies fixes from scratch.
- **On `/autopilot off`**: The backup is deleted with `rm -rf`. Make sure you have confirmed the task works before running `/autopilot off`.
- **Backup location**: Defined by `autopilot-backup.sh`; the path is echoed by the script and stored in the state file.

---

## Sudo Password Persistence

Autopilot can store your sudo password for the session (and future sessions) to avoid repeated prompts.

- Before the first sudo-required command in a session, Claude asks exactly **one** question: "If I require sudo permissions or a password, will you allow me to execute?"
- If you say yes: Claude checks `~/.claude/autopilot-sudo.conf` (chmod 600). If it exists, the password is read silently. If not, Claude asks once and saves it.
- All subsequent sudo commands in this and future sessions use the saved password — you are never asked again.
- If `npm`/`npx`/`pnpm install` fails, Claude auto-retries with sudo using the saved password — no extra question.

> **Security warning:** The sudo password is stored in **plaintext** at `~/.claude/autopilot-sudo.conf` with permissions `600` (owner-read-only). Do **not** use this feature on shared or multi-user machines. Delete the file with `rm ~/.claude/autopilot-sudo.conf` to revoke stored access at any time.

---

## Checking the Session Log

The session log path is shown in `/autopilot status` and stored in `~/.claude/autopilot-state.json` under `sessionLog`. Logs are kept at:

```
~/.claude/autopilot-sessions/{TIMESTAMP}.log
```

To view the current session log:

1. Run `/autopilot status` — it will print the exact log path.
2. Open the file at that path.

Each log entry is written by the `autopilot-logger.sh` PostToolUse hook, which fires after every tool call while autopilot is active.
