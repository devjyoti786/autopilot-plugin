# Auto-Mode Classifier Integration Design

**Date:** 2026-04-29  
**Status:** Approved  
**Scope:** normal + strict modes only (yolo stays bypassPermissions)

---

## Problem

Normal and strict modes already set `"defaultMode": "auto"` in their templates, but provide no classifier context. The classifier runs with generic defaults, so:

- Strict mode relies on a behavioral CLAUDE.md rule (#10) to halt destructive ops — not enforced at the tool level
- Neither mode teaches the classifier anything about the environment or expected task profile
- No per-mode differentiation in what the classifier allows or blocks

---

## How Auto-Mode Works

```
Tool call attempted
        │
        ▼
┌──────────────────────────────────┐
│  Step 1: permissions.allow/deny  │  ← static rules in settings.local.json
│  (runs BEFORE classifier)        │     hard allow or hard deny, no AI
└──────────┬───────────────────────┘
           │ not matched
        ▼
┌──────────────────────────────────┐
│  Step 2: Read-only + working dir │  ← auto-approved by Claude Code
│  auto-approve                    │
└──────────┬───────────────────────┘
           │ not matched
        ▼
┌──────────────────────────────────┐
│  Step 3: AI Classifier           │  ← reads autoMode.environment,
│                                  │     soft_deny, allow from settings
│  soft_deny → block               │
│  allow → override block          │
│  explicit user intent → override │
└──────────┬───────────────────────┘
           │ blocked 3x in a row / 20x total
        ▼
  Fallback to user prompt
```

**Key schema facts:**
- `permissions.deny` = hard block, runs before classifier, never bypassed
- `autoMode.soft_deny` = AI-evaluated block, can be overridden by explicit user intent
- `autoMode.allow` = AI-evaluated exception, overrides soft_deny matches
- `autoMode.environment` = context fed to classifier (trusted repos, org, use case)
- Use `"$defaults"` in arrays to include built-in defaults + your additions

---

## Changes

### 1. `templates/strict.json`

Add `permissions.deny` for hard blocks (rm -rf, force push). Add `autoMode` block with extra soft_deny rules for things that should prompt user. Remove behavioral HALT rule from CLAUDE.md block since tool-level enforcement replaces it.

**`permissions.deny`** hard blocks (never bypassed, even by user intent in the classifier):
- `Bash(rm -rf *)` / `Bash(rm -Rf *)` / `Bash(rm -rf*)` — mass deletion
- `Bash(git push --force*)` / `Bash(git push -f *)` — force push

**`autoMode.soft_deny`** additions (on top of `$defaults`):
- DROP TABLE / DROP DATABASE without explicit session-level user approval
- Writing plaintext credentials or secrets to tracked files

**`autoMode.environment`**: Declare strict mode profile so classifier has context.

### 2. `templates/normal.json`

Add `autoMode` block with environment context. No extra deny rules — normal mode relies on defaults.

**`autoMode.allow`** additions: Installing packages via apt/brew/pip/npm/pnpm/npx when requested by user (avoids false positives on the broader allowlist).

### 3. `claude-md-blocks/autopilot-instructions-strict.md`

Remove rule 10 (HALT before rm -rf, force push, DROP TABLE, credential writes). The `permissions.deny` and `autoMode.soft_deny` now enforce this at tool level — behavioral instruction is redundant and misleads users into thinking Claude is the enforcement layer.

### 4. `README.md`

- **"How It Works" flowchart**: Add classifier decision step between static allow and execution
- **Safety Levels table**: Update "Pauses for" column to reflect tool-level enforcement
- **New section "Auto-Mode Classifier"**: Explain the 3-step decision flow, what each mode configures, link to `claude auto-mode defaults` CLI command
- **Architecture Diagram**: Add `autoMode` config node in Runtime State subgraph

---

## Decision Flow Per Mode

| Step | Normal | Strict | Yolo |
|------|--------|--------|------|
| Static allow | broad (curl/apt/brew/pip/npm) | narrow (git/npm/node only) | n/a |
| Hard deny (`permissions.deny`) | none | rm -rf, force push | n/a |
| Classifier | default soft_deny + allow exceptions for pkg install | default soft_deny + extra DROP TABLE / credential rules | no classifier (`bypassPermissions`) |
| Fallback prompt | after 3 consecutive / 20 total blocks | same | never |

---

## What Does NOT Change

- Yolo mode: stays `bypassPermissions`, no classifier
- Activation/deactivation flow: unchanged
- Backup/restore logic: unchanged
- Sudo handling: unchanged
- Test gate: unchanged
