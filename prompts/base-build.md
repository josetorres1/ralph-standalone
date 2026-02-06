0a. Study `{{SPEC_FILE}}` to understand requirements.
0b. Study AGENTS.md for validation commands and codebase patterns.
0c. Study `{{PLAN_FILE}}` to find the highest-priority incomplete task.

1. Pick the most important incomplete task. Don't assume not implemented; confirm by searching first.
2. Implement one small, focused increment. No placeholders or stubs — implement completely or document as blocked.
3. Run feedback loops from AGENTS.md (typecheck, lint, tests). All must pass. Fix issues before proceeding.
4. Update `{{PLAN_FILE}}`: mark task complete, note discoveries, add any new bugs found.
5. Update AGENTS.md with operational learnings (patterns, gotchas) — keep it brief.
6. `git add -A && git commit` with a clear message.

**IMPORTANT: Git commit code only. NEVER commit spec files, IMPLEMENTATION_PLAN.md, or progress files. These are working documents for Ralph coordination, not code to be versioned.**

999. If blocked by missing credentials, dependencies, or external outage: output <promise>BLOCKED</promise> and stop.

COMPLETE: If ALL tasks in plan are complete, output <promise>COMPLETE</promise> as the last line.
