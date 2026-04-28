# Claude Code Autopilot

Claude Code Autopilot is a plugin that enables fully autonomous, zero-interrupt task execution inside Claude Code. You enter a prompt, Claude executes the entire task — file edits, shell commands, installs, git operations — without stopping to ask for confirmations. In `normal`/`strict` mode a test gate lets you verify results before closing. In `yolo` mode Claude declares complete and cleans up automatically — zero human interaction from start to finish.

![version](https://img.shields.io/badge/version-1.0.0-blue) ![license](https://img.shields.io/badge/license-MIT-green) ![platform](https://img.shields.io/badge/platform-Claude%20Code-blueviolet)

---

## How It Works

```mermaid
flowchart TD
    A(["/autopilot [mode]"]) --> B["Backup workspace\ncp -r, excludes node_modules / .git / etc"]
    B --> C["Merge permissions template\ninto settings.local.json\n(includes autoMode config)"]
    C --> D["Inject CLAUDE.md block\nautopilot rules + mode placeholders"]
    D --> E["Write state file\nmode / backupPath / workspacePath / log"]
    E --> F(["Autopilot active — enter your task"])

    F --> G["User enters task prompt"]
    G --> SPLIT{"Mode?"}

    SPLIT -->|"strict / normal"| SUDO{"Needs sudo?\nfirst time"}
    SUDO -->|yes| ASK["Ask ONE question:\nwill you allow sudo?"]
    ASK -->|yes| CONF["Check autopilot-sudo.conf\nread or save password"]
    CONF --> EXEC1
    SUDO -->|"saved / not needed"| EXEC1["Claude attempts tool call"]

    EXEC1 --> PERM{"Permission check"}
    PERM -->|"static allow list"| RUN1["Execute immediately"]
    PERM -->|"permissions.deny match\nstrict only"| BLOCK["Hard block — Claude\ntries alternative approach"]
    PERM -->|"goes to classifier"| CLASS{"AI Classifier\nevaluates action"}
    CLASS -->|"safe"| RUN1
    CLASS -->|"risky — soft_deny"| PROMPT["Block + redirect Claude\nto alternative"]
    CLASS -->|"3x in a row\nor 20x total"| FALLBACK["Fallback to\nuser prompt"]
    PROMPT --> EXEC1
    BLOCK --> EXEC1

    SPLIT -->|yolo| EXEC2["Claude executes autonomously\nbypassPermissions — zero prompts\nlogs every tool call"]

    RUN1 --> GATE(["Please test what was built.\nOr add/change anything — just type it."])
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

| Mode | Static allow list | Hard deny (`permissions.deny`) | Classifier (`autoMode`) | Human interaction |
|------|-------------------|-------------------------------|-------------------------|-------------------|
| `strict` | git, npm, node, python, basic file ops | `rm -rf`, force push (never bypassed) | Default blocks + extra: DROP TABLE, plaintext credential writes | Sudo consent (once) + test gate + end confirmation |
| `normal` | Everything in strict + curl, apt, brew, systemctl, chmod, pip, npx, pnpm | none | Default blocks + extra allow: package installs when user-requested | Sudo consent (once) + test gate + end confirmation |
| `yolo` | Everything (`bypassPermissions`) | none | **No classifier** — all tool calls execute immediately | **None** — fully autonomous start to finish |

---

## Auto-Mode Classifier

Auto mode is Claude Code's built-in AI permission layer. Instead of asking you to approve every tool call, it evaluates each action before it runs and decides automatically.

### Decision flow (normal / strict)

```
Tool call attempted
        │
        ▼
1. Static allow/deny (permissions.allow / permissions.deny in settings.local.json)
   → allow match: execute immediately
   → deny match: hard block, Claude tries alternative  [strict only]
        │ no match
        ▼
2. Read-only + working-directory file edits → auto-approved
        │ everything else
        ▼
3. AI Classifier reads: action + full transcript + autoMode config
   → soft_deny match: block, Claude redirected to try differently
   → allow exception match: override block, execute
   → explicit user intent ("force-push this branch"): override soft_deny
        │ blocked 3× in a row OR 20× total
        ▼
4. Fallback to user prompt (auto mode pauses)
```

### Per-mode configuration

**Strict mode** — `templates/strict.json`
- `permissions.deny` hard-blocks: `rm -rf *`, `git push --force*`, `git push -f *`
- `autoMode.soft_deny` extras: DROP TABLE/DATABASE, plaintext credential writes to tracked files
- `autoMode.environment`: declares strict/cautious dev profile to classifier

**Normal mode** — `templates/normal.json`
- No hard denies
- `autoMode.allow` extras: package installs via apt/brew/pip/npm/pnpm/npx when user-requested
- `autoMode.environment`: declares broad dev environment profile

**Yolo mode** — `templates/yolo.json`
- `bypassPermissions`: classifier does not run, all tool calls execute immediately

### Inspect classifier rules

```bash
# See what the classifier uses in your current session
claude auto-mode config

# See built-in defaults (allow + soft_deny lists)
claude auto-mode defaults

# Get AI critique of your custom rules
claude auto-mode critique
```

> Auto mode requires a Claude Team, Enterprise, Max, or API plan. Not available on Pro. Run `claude --enable-auto-mode` to enable it if you haven't already.

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
        CB["claude-md-blocks/<br/>autopilot-instructions-*.md"]
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
        SLC["~/.claude/<br/>settings.local.json<br/>(permissions + autoMode)"]
        SJ["~/.claude/<br/>settings.json"]
        CMD["CLAUDE.md<br/>autopilot block"]
        BKD["~/.claude/<br/>autopilot-backups/"]
        LOG["~/.claude/<br/>autopilot-sessions/"]
        SUP["~/.claude/<br/>autopilot-sudo.conf"]
        CLS["Auto-Mode Classifier<br/>(Claude Code built-in)"]
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
    SLC -- configures --> CLS
    CLS -- evaluates every tool call --> SLC
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
