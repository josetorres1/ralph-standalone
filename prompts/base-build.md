0a. Study `{{SPEC_FILE}}` using parallel subagents to learn the application specifications.
0b. Study `{{AGENTS_FILE}}` for validation commands, codebase patterns, and operational context.
0c. Read `{{PRD_FILE}}` and `{{PROGRESS_FILE}}`. Find the first entry in `{{PRD_FILE}}` where `"passes": false` — that is your current task. If all entries are `"passes": true`, emit the COMPLETE signal.

1. Implement the selected task using parallel subagents. Before making changes, search the codebase (don't assume not implemented) using subagents. Use a single subagent for build/tests to avoid race conditions. When complex reasoning is needed (debugging, architectural decisions), think extra hard.
2. After implementing, run the feedback loops from `{{AGENTS_FILE}}` (typecheck, lint, tests). If functionality is missing then it's your job to add it as per the specifications. Think extra hard.
3. When you discover issues, immediately update `{{PROGRESS_FILE}}` with your findings.
4. When the tests pass:
   - In `{{PRD_FILE}}`, set `"passes": true` for the completed task. Do not modify any other entries.
   - Update `{{PROGRESS_FILE}}` (update LAST_TASK, STATUS, and NEXT_STEPS).
   - Stage only the files you modified or created (do NOT use `git add -A` or `git add .`).
   - `git commit` with a message describing the changes.

99999. Important: When authoring documentation, capture the why — tests and implementation importance.
999999. Important: Single sources of truth, no migrations/adapters. If tests unrelated to your work fail, resolve them as part of the increment.
9999999. Keep `{{PROGRESS_FILE}}` current with learnings — future iterations depend on this to avoid duplicating effort. Update especially after finishing your turn.
99999999. When you learn something new about how to run the application, update `{{AGENTS_FILE}}` but keep it brief.
999999999. For any bugs you notice that are unrelated to your current task, add them as new entries in `{{PRD_FILE}}` with `"passes": false`, appended at the end.
9999999999. Implement functionality completely. Placeholders and stubs waste effort redoing the same work.
99999999999. Do not set `"passes": true` until tests pass. Do not mark multiple tasks complete in one iteration.
999999999999. IMPORTANT: Keep `{{AGENTS_FILE}}` operational only — status updates and progress notes belong in `{{PROGRESS_FILE}}`. A bloated AGENTS.md pollutes every future loop's context.

IMPORTANT:
- Commit code only.
- Never commit `{{SPEC_FILE}}`, `{{PRD_FILE}}`, `{{AGENTS_FILE}}`, `{{PROGRESS_FILE}}`, or progress/coordination files.
