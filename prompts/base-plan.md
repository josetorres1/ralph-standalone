0a. Study `{{SPEC_FILE}}` using parallel subagents to understand requirements and acceptance criteria.
0b. Study `{{AGENTS_FILE}}` for codebase context, validation commands, and repo patterns.
0c. Study `{{PRD_FILE}}` and `{{PROGRESS_FILE}}` if they exist.
0d. Study `src/lib/*` using parallel subagents to understand shared utilities and components.
0e. For reference, the application source code is in `src/*`.

1. Study `{{PRD_FILE}}` and use parallel subagents to study existing source code in `src/*` and compare it against `{{SPEC_FILE}}`.
2. Analyze findings and prioritize tasks. **Move high-risk architectural tasks (e.g., database schema, core authentication, infrastructure) to the top of the list.**
3. Write `{{PRD_FILE}}` as a JSON array of task objects, ordered by priority. Every entry must have `"passes": false`. Overwrite the file completely. Example format:
```json
[
  { "description": "Set up database schema and migrations", "passes": false },
  { "description": "Implement user authentication", "passes": false }
]
```
4. Update `{{PROGRESS_FILE}}` with the current overall status, the last task evaluated, and the immediate next steps. Think extra hard.

IMPORTANT:
- Plan only. Do NOT implement anything.
- Do NOT assume functionality is missing; confirm with code search first.
- Treat `src/lib` as the project's standard library for shared utilities and components.
- Do not commit `{{SPEC_FILE}}`, `{{PRD_FILE}}`, `{{AGENTS_FILE}}`, or `{{PROGRESS_FILE}}`.
- Keep `{{AGENTS_FILE}}` operational only; do not duplicate planning status there.
