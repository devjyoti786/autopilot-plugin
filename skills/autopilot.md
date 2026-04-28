# Autopilot Skill

This skill enables and manages autopilot mode for Claude Code. Read and follow the steps below based on which command the user invoked.

---

## Command: `/autopilot [strict|normal|yolo]` — Activate Autopilot

Perform ALL of the following steps in order. Do not skip any step.

### Step 0 — Validate mode

Check that the mode argument the user provided is one of: `strict`, `normal`, `yolo`, `off`, `status`.

If it is not one of those values: say exactly "Invalid mode. Use: /autopilot [strict|normal|yolo|off|status]" and stop. Do not proceed further.

### Step 1 — Determine workspace path

Run:

```bash
pwd
```

Store the output as **WORKSPACE_PATH**.

### Step 2 — Determine PLUGIN_PATH

Resolve PLUGIN_PATH using the following priority order:

1. Try reading `~/.claude/plugins/cache/autopilot/plugin.json`. If the file exists, set `PLUGIN_PATH = ~/.claude/plugins/cache/autopilot` and stop.
2. Check if `~/.claude/plugins/autopilot` exists as a directory. If it does, set `PLUGIN_PATH = ~/.claude/plugins/autopilot` and stop.
3. Check if `/home/$USER/.claude/plugins/cache/autopilot` exists as a directory. If it does, set `PLUGIN_PATH` to that path and stop.
4. If none of the above exist: ask the user "Where is the autopilot plugin installed?" and use their answer as PLUGIN_PATH.

### Step 3 — Create timestamp

Run:

```bash
date +%Y%m%d-%H%M%S
```

Store the output as **TIMESTAMP**.

Also generate **ISO_TIMESTAMP** (for the state file):

```bash
date -u +%Y-%m-%dT%H:%M:%SZ
```

### Step 4 — Back up the workspace

Run:

```bash
bash "{PLUGIN_PATH}/scripts/autopilot-backup.sh" "{WORKSPACE_PATH}" "{TIMESTAMP}"
```

Capture the script's stdout output as **BACKUP_PATH**. This is the path where the backup was created.

> The backup script uses `cp -r` only. Never use `mv` for backups.

After capturing BACKUP_PATH, validate it:

- If BACKUP_PATH is empty: say "Backup failed. Autopilot not activated." and stop.
- Run `test -d "$BACKUP_PATH"`. If the directory does not exist: say "Backup failed. Autopilot not activated." and stop.

### Step 5 — Load permission template

Read the file:

```
{PLUGIN_PATH}/templates/{mode}.json
```

where `{mode}` is the mode the user specified (`strict`, `normal`, or `yolo`).

Store the parsed JSON as **TEMPLATE**.

### Step 6 — Merge permissions into settings.local.json

1. Read `~/.claude/settings.local.json`. If the file does not exist or is empty, treat its current content as `{}`.
2. Before making any changes, read the current value of `permissions.defaultMode` from the existing settings. Store it as **ORIGINAL_DEFAULT_MODE** (store the string value if set, or `null` if the key is absent). This will be saved to the state file in Step 9 so deactivation can restore it.
3. Merge TEMPLATE into the settings:
   - Set `permissions.defaultMode` to the value from TEMPLATE's `permissions.defaultMode`.
   - If TEMPLATE has a `permissions.allow` array: append each entry to the existing `permissions.allow` array in settings (or create it if absent). Deduplicate entries — do not add entries that are already present.
   - Preserve all other existing keys in `settings.local.json` unchanged.
4. Write the merged object back to `~/.claude/settings.local.json`.

### Step 7 — Inject CLAUDE.md block

1. Read the file `{PLUGIN_PATH}/claude-md-blocks/autopilot-instructions.md`.
2. In the content read from that file:
   - Replace every occurrence of `{MODE}` with the mode in UPPERCASE (e.g., `STRICT`, `NORMAL`, `YOLO`).
   - Replace every occurrence of `{BACKUP_PATH}` with the actual BACKUP_PATH value.
3. Find the active CLAUDE.md:
   - If `{WORKSPACE_PATH}/CLAUDE.md` exists: use it.
   - Otherwise: use `~/.claude/CLAUDE.md` (create it if it does not exist).
4. Open the target CLAUDE.md:
   - If it already contains `<!-- autopilot:start -->` … `<!-- autopilot:end -->`: replace that entire block (including the marker lines) with the new block.
   - Otherwise: append the new block to the end of the file (add a blank line before it if the file does not already end with a blank line).

### Step 8 — Register PostToolUse hook

1. Read `~/.claude/settings.json`. If the file does not exist, treat it as `{}`.
2. Navigate to (or create) `hooks.PostToolUse` — it should be an array.
3. Check for an existing autopilot-logger hook by walking the full nested structure:
   - Iterate over every item in `hooks.PostToolUse[]`.
   - For each item, iterate over its `hooks[]` array.
   - For each hook in that inner array, inspect its `command` field.
   - If any `command` value contains the string `"autopilot-logger.sh"`: skip this step entirely (hook already registered).
4. If not already present: append the following object to the `hooks.PostToolUse` array:

```json
{
  "matcher": "*",
  "hooks": [
    {
      "type": "command",
      "command": "bash {PLUGIN_PATH}/hooks/autopilot-logger.sh",
      "timeout": 5
    }
  ]
}
```

Replace `{PLUGIN_PATH}` with the actual PLUGIN_PATH value.

5. Write the updated object back to `~/.claude/settings.json`.

### Step 9 — Write state file

Create the directory `~/.claude/autopilot-sessions/` if it does not exist:

```bash
mkdir -p ~/.claude/autopilot-sessions
```

Write the following JSON to `~/.claude/autopilot-state.json`:

```json
{
  "mode": "{mode}",
  "since": "{ISO_TIMESTAMP}",
  "sessionLog": "$HOME/.claude/autopilot-sessions/{TIMESTAMP}.log",
  "workspacePath": "{WORKSPACE_PATH}",
  "backupPath": "{BACKUP_PATH}",
  "originalDefaultMode": "{ORIGINAL_DEFAULT_MODE}"
}
```

Replace all placeholders with their actual values. For `sessionLog`, use the shell-expanded absolute path (e.g., `/home/alice/.claude/autopilot-sessions/20240101-120000.log`) — never write a literal `~` or `$HOME` into the JSON value. For `originalDefaultMode`, write the string value if ORIGINAL_DEFAULT_MODE was set, or `null` (JSON null, not the string "null") if the key was absent.

### Step 10 — Confirm to user

Say exactly:

> 🤖 Autopilot **{MODE}** active. Workspace backed up to `{BACKUP_PATH}`. Enter your task.

Then immediately begin following the autopilot rules injected into CLAUDE.md (the block you just wrote in Step 7). Do not wait for further setup instructions — the user's next message is their task.

### Step 11 — Sudo Consent Gate

Apply this rule for the rest of the session, before the very first command that requires sudo:

- Ask exactly ONE question: "If I require sudo permissions or a password, will you allow me to execute?"
- If the user says **yes**:
  - Check whether `~/.claude/autopilot-sudo.conf` exists (and has mode 600).
  - If it **exists**: read the password silently from the file; use it for all subsequent sudo commands this session; never ask again.
  - If it **does not exist**: ask for the password once, write it to `~/.claude/autopilot-sudo.conf`, run `chmod 600 ~/.claude/autopilot-sudo.conf`, and use it for the rest of this session and future sessions.
- If the user says **no**: proceed without sudo; do not ask again.
- If any `npm`, `npx`, or `pnpm install` command fails: automatically retry with the saved password (no extra question).

Only ask the one-time consent question once per session. Never re-ask if it has already been answered.

### Step 12 — Task Completion Protocol

After all task work is complete, apply this gate before declaring done:

1. Say: "Please test [what was built / how to test it]. If you want to add or change anything before we wrap up, just type it — otherwise confirm test results."
2. If the user types additional requirements: implement them autonomously, then return to step 1 of this gate.
3. If the user reports an error:
   - Run: `bash {PLUGIN_PATH}/scripts/autopilot-restore.sh "{BACKUP_PATH}" "{WORKSPACE_PATH}"`
   - Re-implement the fixes from scratch.
   - Say: "Fixed. Please test again." and return to step 1 of this gate.
4. If the user confirms success: say "Complete. Test again or end?" and wait.
5. If the user says "end": proceed to `/autopilot off` (run the deactivation flow below).

---

## Command: `/autopilot off` — Deactivate Autopilot

Perform ALL of the following steps in order.

### Step 1 — Read state

Read `~/.claude/autopilot-state.json`. Extract **BACKUP_PATH**. If the file does not exist or mode is already `"off"`, skip steps 2–5 and go directly to step 6.

### Step 2 — Delete backup

```bash
rm -rf "{BACKUP_PATH}"
```

### Step 3 — Remove autopilot block from CLAUDE.md

Find the active CLAUDE.md (same logic as activation step 7: workspace CLAUDE.md if it exists, else `~/.claude/CLAUDE.md`).

Remove the entire block from `<!-- autopilot:start -->` through `<!-- autopilot:end -->` (inclusive, including those marker lines and any blank line immediately preceding the block). Write the file back.

### Step 4 — Remove autopilot-logger hook from settings.json

1. Read `~/.claude/settings.json`.
2. In `hooks.PostToolUse`, remove any hook entry whose `hooks[*].command` contains `autopilot-logger.sh`.
3. Write the file back.

### Step 5 — Strip autopilot permissions from settings.local.json

1. Read `~/.claude/settings.local.json`.
2. Identify which `allow` entries were added by autopilot by reading all three template files (`{PLUGIN_PATH}/templates/strict.json`, `normal.json`, `yolo.json`) and collecting the union of their `allow` arrays. Remove those entries from `settings.local.json`'s `permissions.allow` array.
3. Read the `originalDefaultMode` field from `~/.claude/autopilot-state.json`:
   - If `originalDefaultMode` is `null` (was absent before autopilot ran): remove the `permissions.defaultMode` key entirely from `settings.local.json`.
   - If `originalDefaultMode` is a non-null string: restore `permissions.defaultMode` to that value.
4. Write the file back.

> Note: If you cannot determine which entries were pre-existing, err on the side of caution and only remove entries that exactly match those listed in the template files.

### Step 6 — Write state file

Write to `~/.claude/autopilot-state.json`:

```json
{"mode": "off"}
```

### Step 7 — Confirm to user

Say:

> Autopilot deactivated. Backup deleted.

---

## Command: `/autopilot status` — Show Current State

### Step 1 — Read state file

Read `~/.claude/autopilot-state.json`.

### Step 2 — Report

- If the file does not exist: say **"Autopilot is OFF."**
- If `mode` is `"off"`: say **"Autopilot is OFF."**
- If mode is active (`strict`, `normal`, or `yolo`): display the following:

```
Autopilot Status
────────────────
Mode:         {mode} (UPPERCASE)
Active since: {since}
Workspace:    {workspacePath}
Backup:       {backupPath}
Session log:  {sessionLog}
```

---

## Notes for Skill Authors

- This file is a markdown document that Claude reads and follows — it is NOT an executable shell script.
- All bash commands shown are commands for Claude to run via the Bash tool.
- File paths with `~` refer to the current user's home directory.
- PLUGIN_PATH must be resolved at runtime using the priority order described in activation Step 2 (plugin.json cache → known directories → ask user).
