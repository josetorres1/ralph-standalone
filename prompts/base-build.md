0a. Study `{{SPEC_FILE}}` using parallel subagents to learn the application specifications.
0b. Study `{{AGENTS_FILE}}` for validation commands, codebase patterns, and operational context.
0c. Study `{{PLAN_FILE}}` and `{{PROGRESS_FILE}}`. Select the highest-priority incomplete task.

1. Implement the selected task using parallel subagents. Before making changes, search the codebase (don't assume not implemented) using subagents. Use a single subagent for build/tests to avoid race conditions. When complex reasoning is needed (debugging, architectural decisions), think extra hard.
2. After implementing, run the feedback loops from `{{AGENTS_FILE}}` (typecheck, lint, tests). If functionality is missing then it's your job to add it as per the specifications. Think extra hard.
3. When you discover issues, immediately update `{{PLAN_FILE}}` and `{{PROGRESS_FILE}}` with your findings. When resolved, update and remove the item.
4. When the tests pass:
   - Update `{{PLAN_FILE}}` (mark task as complete).
   - Update `{{PROGRESS_FILE}}` (update LAST_TASK, STATUS, and NEXT_STEPS).
   - Stage only the files you modified or created (do NOT use `git add -A` or `git add .`).
   - `git commit` with a message describing the changes.

99999. Important: When authoring documentation, capture the why — tests and implementation importance.
999999. Important: Single sources of truth, no migrations/adapters. If tests unrelated to your work fail, resolve them as part of the increment.
9999999. Keep `{{PLAN_FILE}}` and `{{PROGRESS_FILE}}` current with learnings — future iterations depend on this to avoid duplicating effort. Update especially after finishing your turn.
99999999. When you learn something new about how to run the application, update `{{AGENTS_FILE}}` but keep it brief.
999999999. For any bugs you notice, resolve them or document them in `{{PLAN_FILE}}` even if unrelated to the current task.
9999999999. Implement functionality completely. Placeholders and stubs waste effort redoing the same work.
99999999999. When `{{PLAN_FILE}}` becomes large, periodically clean out completed items.
999999999999. IMPORTANT: Keep `{{AGENTS_FILE}}` operational only — status updates and progress notes belong in `{{PLAN_FILE}}` and `{{PROGRESS_FILE}}`. A bloated AGENTS.md pollutes every future loop's context.

IMPORTANT:
- Commit code only.
- Never commit `{{SPEC_FILE}}`, `{{PLAN_FILE}}`, `{{AGENTS_FILE}}`, `{{PROGRESS_FILE}}`, or progress/coordination files.

TERMINAL SIGNALS:
- If blocked by missing credentials, missing dependencies, or external outage, the final non-empty line must be exactly:
<promise>BLOCKED</promise>
- If all planned tasks are complete, the final non-empty line must be exactly:
<promise>COMPLETE</promise>
