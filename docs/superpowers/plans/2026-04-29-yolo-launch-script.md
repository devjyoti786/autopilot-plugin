# YOLO Auto-Launch Script Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When `/autopilot yolo` is activated mid-session, automatically open a NEW terminal window running `claude --dangerously-skip-permissions` in the workspace directory — so `bypassPermissions` activates without requiring the user to manually restart.

**Architecture:** `bypassPermissions` requires `--dangerously-skip-permissions` at session launch — mid-session settings changes have no effect on the running process. A shell script (`autopilot-launch-yolo.sh`) detects the available terminal emulator and opens a new window running `claude --dangerously-skip-permissions "$WORKSPACE_PATH"`. Step 10 in `skills/autopilot.md` is updated: for YOLO mode it runs the script instead of printing a manual restart instruction.

**Tech Stack:** Bash, Markdown (skill file), existing install.sh (chmod step)

---

## File Map

| File | Change |
|------|--------|
| `scripts/autopilot-launch-yolo.sh` | Create — terminal detection + launch |
| `skills/autopilot.md` | Modify Step 10 — YOLO branch runs script |
| `scripts/install.sh` | Already `chmod +x scripts/*.sh` — no change needed |
| `README.md` | Add YOLO launch note to Safety Levels + Usage |

---

## Task 1: Create `scripts/autopilot-launch-yolo.sh`

**Files:**
- Create: `scripts/autopilot-launch-yolo.sh`

The script must:
1. Accept `WORKSPACE_PATH` as `$1`
2. Try terminal emulators in priority order: `xdg-terminal-exec` → `x-terminal-emulator` → `warp-terminal` → `sensible-terminal` → any of: `gnome-terminal`, `xterm`, `konsole`, `kitty`, `alacritty`
3. Launch `claude --dangerously-skip-permissions` in `$WORKSPACE_PATH`
4. If no terminal found: print the fallback manual command and exit 1

Terminal launch commands differ per emulator:
- `xdg-terminal-exec`: `xdg-terminal-exec bash -c "cd '$WS' && claude --dangerously-skip-permissions; exec bash"`
- `x-terminal-emulator`: `x-terminal-emulator -e bash -c "cd '$WS' && claude --dangerously-skip-permissions; exec bash"`
- `warp-terminal`: Warp does not support `-e` flag; use `warp-terminal` alone (opens in last dir) OR use `bash -c` via `--command` if supported — fallback: print instruction
- `sensible-terminal`: `sensible-terminal -- bash -c "cd '$WS' && claude --dangerously-skip-permissions; exec bash"`
- `gnome-terminal`: `gnome-terminal -- bash -c "cd '$WS' && claude --dangerously-skip-permissions; exec bash"`
- `xterm`: `xterm -e bash -c "cd '$WS' && claude --dangerously-skip-permissions; exec bash"`
- `konsole`: `konsole -e bash -c "cd '$WS' && claude --dangerously-skip-permissions; exec bash"`
- `kitty`: `kitty bash -c "cd '$WS' && claude --dangerously-skip-permissions; exec bash"`
- `alacritty`: `alacritty -e bash -c "cd '$WS' && claude --dangerously-skip-permissions; exec bash"`

- [ ] **Step 1: Write `scripts/autopilot-launch-yolo.sh`**

```bash
#!/bin/bash
# autopilot-launch-yolo.sh — open new terminal with claude --dangerously-skip-permissions
# Usage: bash autopilot-launch-yolo.sh <workspace_path>

set -euo pipefail

WS="${1:-$PWD}"
CMD="cd '$WS' && claude --dangerously-skip-permissions; exec bash"

launch_terminal() {
    if command -v xdg-terminal-exec &>/dev/null; then
        xdg-terminal-exec bash -c "$CMD" &
        return 0
    fi
    if command -v x-terminal-emulator &>/dev/null; then
        x-terminal-emulator -e bash -c "$CMD" &
        return 0
    fi
    if command -v gnome-terminal &>/dev/null; then
        gnome-terminal -- bash -c "$CMD" &
        return 0
    fi
    if command -v sensible-terminal &>/dev/null; then
        sensible-terminal -- bash -c "$CMD" &
        return 0
    fi
    if command -v kitty &>/dev/null; then
        kitty bash -c "$CMD" &
        return 0
    fi
    if command -v alacritty &>/dev/null; then
        alacritty -e bash -c "$CMD" &
        return 0
    fi
    if command -v xterm &>/dev/null; then
        xterm -e bash -c "$CMD" &
        return 0
    fi
    if command -v konsole &>/dev/null; then
        konsole -e bash -c "$CMD" &
        return 0
    fi
    if command -v warp-terminal &>/dev/null; then
        # Warp does not support -e; open it and print instruction
        warp-terminal &
        echo "WARP_FALLBACK"
        return 1
    fi
    return 1
}

if launch_terminal; then
    echo "LAUNCHED"
else
    echo "MANUAL"
    echo "cd '$WS' && claude --dangerously-skip-permissions"
fi
```

- [ ] **Step 2: Verify script syntax**

```bash
bash -n /home/hp/autopilot-plugin/scripts/autopilot-launch-yolo.sh
```

Expected: no output (syntax OK).

- [ ] **Step 3: Make executable and smoke-test**

```bash
chmod +x /home/hp/autopilot-plugin/scripts/autopilot-launch-yolo.sh
/home/hp/autopilot-plugin/scripts/autopilot-launch-yolo.sh /home/hp/autopilot-plugin
```

Expected: either opens new terminal with claude, or prints `MANUAL` + the command (if running in headless environment).

- [ ] **Step 4: Commit**

```bash
cd /home/hp/autopilot-plugin
git add scripts/autopilot-launch-yolo.sh
git commit -m "feat(yolo): add autopilot-launch-yolo.sh — opens new terminal with --dangerously-skip-permissions"
```

---

## Task 2: Modify Step 10 in `skills/autopilot.md`

**Files:**
- Modify: `skills/autopilot.md` (Step 10, ~line 174)

Step 10 currently prints the same confirmation for all modes. Replace with a branched version: normal/strict get the existing message; yolo runs the launch script and shows context-aware output.

- [ ] **Step 1: Replace Step 10 in `skills/autopilot.md`**

Find this exact block:

```
### Step 10 — Confirm to user

Say exactly:

> 🤖 Autopilot **{MODE}** active. Workspace backed up to `{BACKUP_PATH}`. Enter your task.

Then immediately begin following the autopilot rules injected into CLAUDE.md (the block you just wrote in Step 7). Do not wait for further setup instructions — the user's next message is their task.
```

Replace with:

```
### Step 10 — Confirm to user

**If mode is `normal` or `strict`:**

Say exactly:

> 🤖 Autopilot **{MODE}** active. Workspace backed up to `{BACKUP_PATH}`. Enter your task.

Then immediately begin following the autopilot rules injected into CLAUDE.md. Do not wait for further setup instructions — the user's next message is their task.

**If mode is `yolo`:**

Run:

```bash
bash "{PLUGIN_PATH}/scripts/autopilot-launch-yolo.sh" "{WORKSPACE_PATH}"
```

Capture stdout. Then:

- If stdout contains `LAUNCHED`: Say exactly:
  > 🤖 Autopilot **YOLO** setup complete. Workspace backed up to `{BACKUP_PATH}`.
  >
  > A new terminal has opened with `claude --dangerously-skip-permissions`. Switch to it and enter your task there — YOLO mode is active in that window.

- If stdout contains `WARP_FALLBACK`: Say exactly:
  > 🤖 Autopilot **YOLO** setup complete. Workspace backed up to `{BACKUP_PATH}`.
  >
  > Warp is open. In the Warp terminal, run:
  > ```bash
  > cd {WORKSPACE_PATH} && claude --dangerously-skip-permissions
  > ```

- If stdout contains `MANUAL` (no supported terminal found): Say exactly:
  > 🤖 Autopilot **YOLO** setup complete. Workspace backed up to `{BACKUP_PATH}`.
  >
  > ⚠️ No supported terminal emulator detected. Run manually:
  > ```bash
  > cd {WORKSPACE_PATH} && claude --dangerously-skip-permissions
  > ```

Do NOT begin following YOLO autopilot rules in this session — they activate automatically when the new session starts.
```

- [ ] **Step 2: Verify edit**

```bash
grep -n "LAUNCHED\|WARP_FALLBACK\|MANUAL\|autopilot-launch-yolo" /home/hp/autopilot-plugin/skills/autopilot.md
```

Expected: 4+ matching lines with line numbers.

- [ ] **Step 3: Commit**

```bash
cd /home/hp/autopilot-plugin
git add skills/autopilot.md
git commit -m "fix(yolo): Step 10 runs autopilot-launch-yolo.sh — opens new terminal instead of printing restart instruction"
```

---

## Task 3: Update README

**Files:**
- Modify: `README.md`

Two places to update:

1. **Safety Levels table — yolo row** (`Auto-unlock` column): note restart happens in new terminal window
2. **Usage table — `/autopilot yolo` row**: note new terminal opens automatically

- [ ] **Step 1: Update Safety Levels table yolo row**

Find:

```
| `yolo` | Everything (`bypassPermissions`) | none | **No classifier** — all tool calls execute immediately | `claude --allow-dangerously-skip-permissions` | **None** — fully autonomous start to finish |
```

Replace with:

```
| `yolo` | Everything (`bypassPermissions`) | none | **No classifier** — all tool calls execute immediately | Opens new terminal with `claude --dangerously-skip-permissions` | **None** — fully autonomous start to finish. New terminal opens automatically on activation. |
```

- [ ] **Step 2: Update Usage table `/autopilot yolo` row**

Find:

```
| `/autopilot yolo` | Full bypass — trust everything |
```

Replace with:

```
| `/autopilot yolo` | Full bypass — trust everything. Opens new terminal with `--dangerously-skip-permissions` automatically. |
```

- [ ] **Step 3: Verify edits**

```bash
grep -n "Opens new terminal\|dangerously-skip-permissions" /home/hp/autopilot-plugin/README.md
```

Expected: 2+ matching lines.

- [ ] **Step 4: Commit and push**

```bash
cd /home/hp/autopilot-plugin
git add README.md
git commit -m "docs: document YOLO auto-launch terminal behavior in Safety Levels and Usage"
git push origin main
```

---

## Notes

- `install.sh` already runs `chmod +x "$PLUGIN_DIR/scripts/"*.sh` — new script picked up automatically.
- `exec bash` at end of terminal command keeps window open after claude exits (avoids flash-close).
- Warp terminal does not support `-e` / `--command` flags for launching with a command — best effort is opening Warp and printing the command to run.
- Script outputs `LAUNCHED`, `WARP_FALLBACK`, or `MANUAL` on stdout so the skill can branch on result without parsing complex output.
