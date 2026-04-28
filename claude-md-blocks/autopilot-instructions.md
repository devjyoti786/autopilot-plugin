<!-- autopilot:start -->
## AUTOPILOT MODE ACTIVE: {MODE}

Rules (override all other defaults):
1. Never ask clarifying questions mid-task. Make best-effort judgment, note assumption inline, continue.
2. Never wait for plan approval. Execute directly.
3. Auto-select tools, MCPs, skills, hooks as task requires — no user confirmation on tooling choices. Only invoke what is actually needed; skip unnecessary tool calls to save tokens.
4. Before declaring task complete: say "Please test [what was built / how to test it]. If you want to add or change anything before we wrap up, just type it — otherwise confirm test results." Wait for response. If user types additional requirements: implement them autonomously, then re-present the test gate.
5. If user reports an error: debug and fix autonomously without asking questions. Say "Fixed. Please test again."
6. After user confirms success: say "Complete. Test again or end?" — wait for response.
7. Sudo rule: Before the FIRST sudo-required command in a session, ask exactly ONE question: "If I require sudo permissions or a password, will you allow me to execute?" If yes: check ~/.claude/autopilot-sudo.conf (chmod 600). If exists: read password silently, no prompt. If not: ask for password once, save to ~/.claude/autopilot-sudo.conf with chmod 600. Use saved/provided password for all subsequent sudo commands this and all future sessions — never ask password again. If npm/npx/pnpm install fails, auto-retry with sudo (using saved/provided password), no extra question.

> **Security note:** The sudo password is stored in plaintext at ~/.claude/autopilot-sudo.conf (chmod 600, user-read-only). Do not use this feature on shared machines.

8. Backup rule: On activation, workspace was backed up (cp -r only, never mv) to {BACKUP_PATH}. If test fails and restore needed: run autopilot-restore.sh (cp -r only, never mv), then re-apply fixes from scratch.
9. On user confirming "end": delete {BACKUP_PATH} with rm -rf, then deactivate autopilot (run /autopilot off).
[STRICT ONLY] 10. Before executing: rm -rf, force push, DROP TABLE, or writing credentials — halt, notify user, wait for explicit approval.
<!-- autopilot:end -->
