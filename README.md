# Claude Code Autopilot

Claude Code Autopilot is a plugin that enables fully autonomous, zero-interrupt task execution inside Claude Code. You enter a prompt, Claude executes the entire task — file edits, shell commands, installs, git operations — without stopping to ask for confirmations. In `normal`/`strict` mode a test gate lets you verify results before closing. In `yolo` mode Claude declares complete and cleans up automatically — zero human interaction from start to finish.

![version](https://img.shields.io/badge/version-1.0.0-blue) ![license](https://img.shields.io/badge/license-MIT-green) ![platform](https://img.shields.io/badge/platform-Claude%20Code-blueviolet)

---

## How It Works

```mermaid
flowchart TD
    A(["/autopilot [mode]"]) --> B["Backup workspace\ncp -r, excludes node_modules / .git / etc"]
    B --> C["Merge permissions template\ninto settings.local.json"]
    C --> D["Inject CLAUDE.md block\nautopilot rules + mode placeholders"]
    D --> E["Write state file\nmode / backupPath / workspacePath / log"]
    E --> F(["Autopilot active — enter your task"])

    F --> G["User enters task prompt"]
    G --> SPLIT{"Mode?"}

    SPLIT -->|"strict / normal"| SUDO{"Needs sudo?\nfirst time"}
    SUDO -->|yes| ASK["Ask ONE question:\nwill you allow sudo?"]
    ASK -->|yes| CONF["Check autopilot-sudo.conf\nread or save password"]
    CONF --> EXEC1
    SUDO -->|"saved / not needed"| EXEC1["Claude executes autonomously\nallowlist-based — logs every tool call"]

    SPLIT -->|yolo| EXEC2["Claude executes autonomously\nbypassPermissions — zero prompts\nlogs every tool call"]

    EXEC1 --> GATE(["Please test what was built.\nOr add/change anything — just type it."])
    GATE --> RESP{"User response"}
    RESP -->|"more requirements"| IMP["Implement autonomously"]
    IMP --> GATE
    RESP -->|"error"| REST["Restore from backup\nautopilot-restore.sh"]
    REST --> REIMP["Re-implement from scratch"]
    REIMP --> GATE
    RESP -->|"success"| CONFIRM(["Complete. Test again or end?"])
    CONFIRM -->|"test again"| GATE
    CONFIRM -->|"end"| CLEAN

    EXEC2 --> CLEAN["Auto-delete backup\nrm -rf backupPath"]
    CLEAN --> TEARDOWN["Remove CLAUDE.md block\nrestore settings.local.json"]
    TEARDOWN --> DONE(["Autopilot OFF"])
```

For terminals that cannot render Mermaid:

```
/autopilot [mode]
      │
      ▼
 Backup workspace ──────────────────────────────────────────────┐
 (cp -r, excludes: node_modules/.git/__pycache__)               │
      │                                                          │
      ▼                                                          │
 Merge permissions ──► settings.local.json                       │
      │                                                          │
      ▼                                                          │
 Inject CLAUDE.md block (<!-- autopilot:start/end -->)           │
      │                                                          │
      ▼                                                          │
 Write state file (~/.claude/autopilot-state.json)              │
      │                                                     BACKUP
      ▼                                                     EXISTS
 USER ENTERS TASK                                                │
      │                                                          │
      ▼                                                          │
 Claude executes ──► zero interrupts ──► logs every tool call    │
      │                                                          │
      ├─── strict/normal ──────────────────────────────────────  │
      │         │                                                │
      │         ▼                                                │
      │    [sudo needed? ask once → save to autopilot-sudo.conf] │
      │         │                                                │
      │         ▼                                                │
      │    "Please test [X]. Add/change anything? Just type it." │
      │         │                                                │
      │         ├─► Error ──► restore from backup ◄─────────────┘
      │         │    auto-debug, re-implement
      │         │
      │         ├─► Additional requirements ──► implement ──► loop
      │         │
      │         └─► Success: "Complete. Test again or end?"
      │                  └─► "end" ──► Delete backup ──► off
      │
      └─── yolo ──────────────────────────────────────────────────
                │
                ▼
           [no sudo consent, no test gate, no end confirmation]
                │
                ▼
           Auto-delete backup ──► /autopilot off
```

---

## Safety Levels

| Mode | Auto-approves | Pauses for | Human interaction |
|------|--------------|------------|-------------------|
| `strict` | git, npm, node, python, basic file ops | `rm -rf`, force push, DROP TABLE, credential writes | Sudo consent (once) + test gate + end confirmation |
| `normal` | Everything in strict + curl, apt, brew, systemctl, chmod, pip, npx, pnpm | Nothing (logs risky ops) | Sudo consent (once) + test gate + end confirmation |
| `yolo` | Everything (`bypassPermissions`) | Nothing | **None** — fully autonomous start to finish |

---

## Installation

### Method 1: Claude Code Plugin System (Recommended)

```bash
# Clone the repo
git clone https://github.com/[USERNAME]/autopilot-plugin ~/.claude/plugins/autopilot-plugin

# Install the plugin
claude plugin install ~/.claude/plugins/autopilot-plugin

# Run install script
bash ~/.claude/plugins/autopilot-plugin/scripts/install.sh
```

### Method 2: Manual

1. Clone repo to `~/.claude/plugins/autopilot-plugin/`
2. Run `bash scripts/install.sh` (patches `settings.json` statusLine)
3. Ensure scripts are executable: `chmod +x scripts/*.sh hooks/*.sh`
4. Restart Claude Code

### Post-Installation Check

```bash
# Verify scripts are executable
ls -la ~/.claude/plugins/autopilot-plugin/scripts/
ls -la ~/.claude/plugins/autopilot-plugin/hooks/

# Check state file was created
cat ~/.claude/autopilot-state.json
```

---

## Usage

### Quick Start

```
/autopilot normal
```

Then just type your task. That's it.

### All Commands

| Command | Description |
|---------|-------------|
| `/autopilot strict` | Safe mode — pauses before destructive ops |
| `/autopilot normal` | Broad auto-approval — most dev tasks |
| `/autopilot yolo` | Full bypass — trust everything |
| `/autopilot off` | Deactivate, delete backup, restore settings |
| `/autopilot status` | Show current mode, backup path, log path |
| `/autopilot-help` | Full reference card |

### The Test Gate (strict / normal only)

Before completing any task, Claude will say:

> "Please test [what was built / how to test it]. If you want to add or change anything before we wrap up, just type it — otherwise confirm test results."

- **Confirm success** → "Complete. Test again or end?"
- **Report an error** → Claude auto-restores from backup and re-fixes
- **Type more requirements** → Claude implements them, re-presents the gate

> **Yolo mode skips the test gate entirely.** Claude declares complete, auto-deletes the backup, and runs `/autopilot off` — no user input needed.

---

## Backup & Restore

### What Gets Backed Up

On `/autopilot [mode]`:

- Full workspace copied to `~/.claude/autopilot-backups/{timestamp}/`
- Excluded: `node_modules/`, `.git/`, `__pycache__/`, `.venv/`, `venv/`, `dist/`, `build/`, `.next/`, `.cache/`, `*.pyc`, `.DS_Store`
- Uses `rsync` (if available) or `cp -r` fallback

### Manual Restore

If you need to restore manually:

```bash
# Find your backup
ls ~/.claude/autopilot-backups/

# Restore
bash ~/.claude/plugins/autopilot-plugin/scripts/autopilot-restore.sh \
  ~/.claude/autopilot-backups/20260428-100000 \
  /path/to/your/project
```

### Backup Lifecycle

```
/autopilot on       → backup created (all modes)
   task runs        → backup preserved throughout
   [strict/normal]  → backup preserved until user says "end"
   user: end        → backup deleted (/autopilot off)
   [yolo]           → backup auto-deleted on task completion
   crash/kill       → backup survives (recoverable manually)
```

---

## Audit Log

Every tool call is logged when autopilot is active:

```
~/.claude/autopilot-sessions/{timestamp}.log
```

Example log:

```
[10:23:01] TOOL:Bash | mode:normal | input:git add -A
[10:23:02] TOOL:Bash | mode:normal | input:git commit -m "feat: add user a
[10:23:04] TOOL:Edit | mode:normal | input:{"file_path":"/home/user/proj/s
[10:23:05] TOOL:Write | mode:normal | input:{"file_path":"/home/user/proj/
```

View live log:

```bash
tail -f $(cat ~/.claude/autopilot-state.json | python3 -c "import json,sys,os; d=json.load(sys.stdin); print(os.path.expanduser(d['sessionLog']))")
```

---

## Sudo Password Persistence

**strict / normal mode:** When autopilot first needs `sudo`, it asks one question:

> "If I require sudo permissions or a password, will you allow me to execute?"

If you allow it, the password is saved to `~/.claude/autopilot-sudo.conf` (chmod 600) for future sessions — you will never be asked again.

**yolo mode:** The consent question is skipped entirely. `bypassPermissions` is active, so sudo commands run directly without prompting.

> **Security warning:** The password is stored in plaintext. `chmod 600` provides user-level protection only. Do not use this feature on shared or multi-user machines.

To clear the saved password:

```bash
rm ~/.claude/autopilot-sudo.conf
```

---

## Status Bar

When autopilot is active, your Claude Code status bar shows:

```
[AP:NORMAL]   [AP:STRICT]   [AP:YOLO]
```

Nothing is shown when autopilot is off.

---

## Architecture Diagram

```mermaid
graph LR
    subgraph Plugin["Plugin Files"]
        MP[".claude-plugin/<br/>marketplace.json"]
        MPJ[".claude-plugin/<br/>plugin.json"]
        PJ["plugin.json"]
        SK["skills/autopilot.md"]
        SH["skills/autopilot-help.md"]
        TM["templates/<br/>strict / normal / yolo"]
        CB["claude-md-blocks/<br/>autopilot-instructions.md"]
        LG["hooks/<br/>autopilot-logger.sh"]
        BK["scripts/<br/>autopilot-backup.sh"]
        RS["scripts/<br/>autopilot-restore.sh"]
        SL["scripts/<br/>autopilot-statusline.sh"]
        IN["scripts/install.sh"]
        UN["scripts/uninstall.sh"]
    end

    subgraph Discovery["Claude Code Discovery"]
        CC["Claude Code UI<br/>slash commands"]
    end

    subgraph Runtime["Runtime State"]
        ST["~/.claude/<br/>autopilot-state.json"]
        SLC["~/.claude/<br/>settings.local.json"]
        SJ["~/.claude/<br/>settings.json"]
        CMD["CLAUDE.md<br/>autopilot block"]
        BKD["~/.claude/<br/>autopilot-backups/"]
        LOG["~/.claude/<br/>autopilot-sessions/"]
        SUP["~/.claude/<br/>autopilot-sudo.conf"]
    end

    MP -- registers --> CC
    MPJ -- metadata --> CC
    CC -- invokes --> SK
    CC -- invokes --> SH
    SK -- reads --> TM
    SK -- reads --> CB
    CB -- injected into --> CMD
    SK -- writes --> SLC
    SK -- runs --> BK
    SK -- runs --> RS
    SK -- writes --> ST
    SK -- modifies --> SJ
    BK -- creates --> BKD
    LG -- appends --> LOG
    SL -- reads --> ST
    IN -- patches --> SJ
    IN -- creates --> ST
    SK -- manages --> SUP
```

---

## Uninstalling

```bash
bash ~/.claude/plugins/autopilot-plugin/scripts/uninstall.sh
```

The uninstall script:

- Warns if autopilot is active (preserves backup)
- Asks before deleting saved sudo password
- Removes statusLine patch
- Removes autopilot-logger hook
- Does NOT delete session logs or backups (manual cleanup)

To fully clean up:

```bash
rm -rf ~/.claude/autopilot-backups/
rm -rf ~/.claude/autopilot-sessions/
rm -f ~/.claude/autopilot-state.json
rm -f ~/.claude/autopilot-sudo.conf
```

---

## File Reference

| File | Purpose |
|------|---------|
| `plugin.json` | Plugin manifest |
| `.claude-plugin/marketplace.json` | Local marketplace registration |
| `.claude-plugin/plugin.json` | Plugin metadata for marketplace |
| `skills/autopilot.md` | `/autopilot` command logic |
| `skills/autopilot/SKILL.md` | Symlink for Claude Code skill discovery |
| `skills/autopilot-help.md` | `/autopilot-help` reference |
| `skills/autopilot-help/SKILL.md` | Symlink for Claude Code skill discovery |
| `templates/strict.json` | Strict mode permission delta |
| `templates/normal.json` | Normal mode permission delta |
| `templates/yolo.json` | Yolo mode (`bypassPermissions`) |
| `claude-md-blocks/autopilot-instructions.md` | CLAUDE.md injection template (mode-conditional rules) |
| `hooks/autopilot-logger.sh` | PostToolUse audit logger |
| `scripts/autopilot-backup.sh` | Workspace backup (cp -r) |
| `scripts/autopilot-restore.sh` | Workspace restore (cp -r) |
| `scripts/autopilot-statusline.sh` | Status bar [AP:MODE] component |
| `scripts/install.sh` | Plugin installation |
| `scripts/uninstall.sh` | Plugin removal |

---

## License

MIT
