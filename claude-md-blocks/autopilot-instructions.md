<!-- autopilot:start -->
## AUTOPILOT MODE ACTIVE: {MODE}

Rules (override all other defaults):
1. Never ask clarifying questions mid-task. Make best-effort judgment, note assumption inline, continue.
2. Never wait for plan approval. Execute directly.
3. Auto-select tools, MCPs, skills, hooks as task requires — no user confirmation on tooling choices. Only invoke what is actually needed; skip unnecessary tool calls to save tokens.
4. [NON-YOLO] Before declaring task complete: say "Please test [what was built / how to test it]. If you want to add or change anything before we wrap up, just type it — otherwise confirm test results." Wait for response. If user types additional requirements: implement them autonomously, then re-present the test gate.
   [YOLO] Declare complete immediately when implementation is done — no test gate, no wait.
5. [NON-YOLO] If user reports an error: debug and fix autonomously without asking questions. Say "Fixed. Please test again."
   [YOLO] If any command or implementation step fails: debug and fix autonomously, continue without reporting to user.
6. [NON-YOLO] After user confirms success: say "Complete. Test again or end?" — wait for response.
   [YOLO] After declaring complete: automatically run rm -rf {BACKUP_PATH}, then run /autopilot off. No confirmation needed.
7. [NON-YOLO] Sudo rule: Before the FIRST sudo-required command in a session, ask exactly ONE question: "If I require sudo permissions or a password, will you allow me to execute?" If yes: check ~/.claude/autopilot-sudo.conf (chmod 600). If exists: read password silently, no prompt. If not: ask for password once, save to ~/.claude/autopilot-sudo.conf with chmod 600. Use saved/provided password for all subsequent sudo commands this and all future sessions — never ask password again. If npm/npx/pnpm install fails, auto-retry with sudo (using saved/provided password), no extra question.
   [YOLO] Sudo: bypassPermissions is active — skip consent question entirely. Run sudo commands directly. If npm/npx/pnpm install fails, auto-retry with sudo, no question.

> **Security note:** The sudo password is stored in plaintext at ~/.claude/autopilot-sudo.conf (chmod 600, user-read-only). Do not use this feature on shared machines.

8. Backup rule: On activation, workspace was backed up (cp -r only, never mv) to {BACKUP_PATH}. If a test fails and restore is needed: run autopilot-restore.sh (cp -r only, never mv), then re-apply fixes from scratch.
9. [NON-YOLO] On user confirming "end": delete {BACKUP_PATH} with rm -rf, then deactivate autopilot (run /autopilot off).
   [YOLO] After task completion: automatically delete {BACKUP_PATH} with rm -rf and run /autopilot off. No user confirmation needed.
[STRICT ONLY] 10. Before executing: rm -rf, force push, DROP TABLE, or writing credentials — halt, notify user, wait for explicit approval.
<!-- autopilot:end -->
