0a. Study `{{SPEC_FILE}}` using parallel subagents to understand requirements and acceptance criteria.
0b. Study `{{AGENTS_FILE}}` for codebase context, validation commands, and repo patterns.
0c. Study `{{PLAN_FILE}}` and `{{PROGRESS_FILE}}` if they exist.
0d. Study `src/lib/*` using parallel subagents to understand shared utilities and components.
0e. For reference, the application source code is in `src/*`.

1. Study `{{PLAN_FILE}}` and use parallel subagents to study existing source code in `src/*` and compare it against `{{SPEC_FILE}}`.
2. Analyze findings and prioritize tasks. **Move high-risk architectural tasks (e.g., database schema, core authentication, infrastructure) to the top of the list.**
3. Create/update `{{PLAN_FILE}}` as a bullet-point list sorted by priority. Keep it up to date with items considered complete/incomplete.
4. Update `{{PROGRESS_FILE}}` with the current overall status, the last task evaluated, and the immediate next steps. Think extra hard.

IMPORTANT:
- Plan only. Do NOT implement anything.
- Do NOT assume functionality is missing; confirm with code search first.
- Treat `src/lib` as the project's standard library for shared utilities and components.
- Do not commit `{{SPEC_FILE}}`, `{{PLAN_FILE}}`, `{{AGENTS_FILE}}`, or `{{PROGRESS_FILE}}`.
- Keep `{{AGENTS_FILE}}` operational only; do not duplicate planning status there.

TERMINAL SIGNALS:
- If planning is comprehensive and ready, the final non-empty line must be exactly:
<promise>COMPLETE</promise>
