0a. Read `{{SPEC_FILE}}` to understand requirements and acceptance criteria.
0b. Read `AGENTS.md` for codebase context and constraints.
0c. Read `{{PLAN_FILE}}` if it exists (it may be stale or incorrect).

1. Perform gap analysis: compare requirements to current implementation; confirm by searching code.
2. Create or update `{{PLAN_FILE}}` as a prioritized list of remaining implementation tasks.
3. For each task, include the reason and map it to acceptance criteria.
4. Update plan status section only; planning mode only (no implementation).
5. Record any spec/implementation inconsistencies in `{{PLAN_FILE}}`.
6. Keep `AGENTS.md` operational only; do not duplicate planning status there.

IMPORTANT:
- Do not commit `{{SPEC_FILE}}`, `{{PLAN_FILE}}`, or `AGENTS.md`.
- Do not implement code in plan mode.

TERMINAL SIGNALS:
- If planning is comprehensive and ready, the final non-empty line must be exactly:
<promise>COMPLETE</promise>
