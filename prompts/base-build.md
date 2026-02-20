0a. Read `{{SPEC_FILE}}` to understand requirements.
0b. Read `AGENTS.md` for validation commands and repo patterns.
0c. Read `{{PLAN_FILE}}` and select the highest-priority incomplete task.

1. Verify the task is actually incomplete by searching code first.
2. Implement one small, focused increment; no placeholders or stubs.
3. Run required feedback loops from `AGENTS.md` (typecheck, lint, tests); fix failures.
4. Update `{{PLAN_FILE}}`: mark progress, record discoveries, add newly found issues.
5. Update `AGENTS.md` with brief operational learnings only.
6. Commit code changes with a clear message.

IMPORTANT:
- Commit code only.
- Never commit `{{SPEC_FILE}}`, `{{PLAN_FILE}}`, `AGENTS.md`, or progress/coordination files.

TERMINAL SIGNALS:
- If blocked by missing credentials, missing dependencies, or external outage, the final non-empty line must be exactly:
<promise>BLOCKED</promise>
- If all planned tasks are complete, the final non-empty line must be exactly:
<promise>COMPLETE</promise>
