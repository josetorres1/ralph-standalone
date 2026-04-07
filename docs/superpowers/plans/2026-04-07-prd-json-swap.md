# prd.json Swap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `IMPLEMENTATION_PLAN.md` with `prd.json` for task tracking, adding shell-side completion verification.

**Architecture:** `prd.json` is an ordered JSON array of `{ "description": "...", "passes": false }` objects. Plan mode AI writes it; build mode AI flips entries to `passes: true`. After each build iteration `afk.sh` independently verifies completion via `jq`, providing an external ground-truth check independent of the AI's COMPLETE signal.

**Tech Stack:** bash, jq

---

### Task 1: Replace `ralph_init_plan_file` with `ralph_init_prd_file` in `ralph-common.sh`

**Files:**
- Modify: `lib/ralph-common.sh`

- [ ] **Step 1: Replace the function**

In `lib/ralph-common.sh`, find and replace the entire `ralph_init_plan_file` function (lines ~172–191) with:

```bash
# ---------------------------------------------------------------------------
# Initialize prd.json if missing (empty task array)
# ---------------------------------------------------------------------------
ralph_init_prd_file() {
  local prd_file="${1:-prd.json}"
  if [ ! -f "$prd_file" ]; then
    printf '[]\n' >"$prd_file"
    printf 'Initialized %s\n' "$prd_file"
  fi
}
```

- [ ] **Step 2: Verify the old function is gone and the new one exists**

```bash
grep -n 'ralph_init_plan_file\|ralph_init_prd_file' lib/ralph-common.sh
```

Expected: only `ralph_init_prd_file` lines appear. Zero results for `ralph_init_plan_file`.

- [ ] **Step 3: Commit**

```bash
git add lib/ralph-common.sh
git commit -m "refactor: replace ralph_init_plan_file with ralph_init_prd_file"
```

---

### Task 2: Add `ralph_validate_jq` and `ralph_check_prd_complete` to `ralph-common.sh`

**Files:**
- Modify: `lib/ralph-common.sh`

- [ ] **Step 1: Add `ralph_validate_jq` after `ralph_validate_max_iter`**

Insert after the `ralph_validate_max_iter` function:

```bash
# ---------------------------------------------------------------------------
# Validate jq is installed (required for prd.json parsing)
# ---------------------------------------------------------------------------
ralph_validate_jq() {
  if ! command -v jq &>/dev/null; then
    printf 'Error: jq is required but not installed.\n' >&2
    printf 'Install with: brew install jq\n' >&2
    return 1
  fi
}
```

- [ ] **Step 2: Add `ralph_check_prd_complete` after `ralph_validate_jq`**

```bash
# ---------------------------------------------------------------------------
# Check if all prd.json tasks have passes: true
# Returns 0 if complete (no passes:false entries), 1 if incomplete
# ---------------------------------------------------------------------------
ralph_check_prd_complete() {
  local prd_file="$1"
  local remaining
  remaining=$(jq '[.[] | select(.passes == false)] | length' "$prd_file")
  [ "$remaining" -eq 0 ]
}
```

- [ ] **Step 3: Verify both functions exist**

```bash
grep -n 'ralph_validate_jq\|ralph_check_prd_complete' lib/ralph-common.sh
```

Expected: two function definitions, one each.

- [ ] **Step 4: Smoke-test `ralph_check_prd_complete` locally**

```bash
echo '[]' > /tmp/test-prd.json
source lib/ralph-common.sh
ralph_check_prd_complete /tmp/test-prd.json && echo "PASS: empty array = complete" || echo "FAIL"

echo '[{"description":"task","passes":false}]' > /tmp/test-prd.json
ralph_check_prd_complete /tmp/test-prd.json && echo "FAIL" || echo "PASS: has incomplete task"

echo '[{"description":"task","passes":true}]' > /tmp/test-prd.json
ralph_check_prd_complete /tmp/test-prd.json && echo "PASS: all complete" || echo "FAIL"

rm /tmp/test-prd.json
```

Expected output:
```
Initialized (none — file existed or sourced)
PASS: empty array = complete
PASS: has incomplete task
PASS: all complete
```

- [ ] **Step 5: Commit**

```bash
git add lib/ralph-common.sh
git commit -m "feat: add ralph_validate_jq and ralph_check_prd_complete"
```

---

### Task 3: Rename `plan_file`→`prd_file` throughout `ralph-common.sh` functions

**Files:**
- Modify: `lib/ralph-common.sh`

This task touches `ralph_load_prompt_template`, `ralph_invoke_cli`, `ralph_invoke_cli_capture`, and the three print functions.

- [ ] **Step 1: Replace `ralph_load_prompt_template`**

Find the entire `ralph_load_prompt_template` function and replace with:

```bash
# ---------------------------------------------------------------------------
# Load prompt template and substitute placeholders
# ---------------------------------------------------------------------------
# Placeholders supported:
#   {{SPEC_FILE}}      - Replaced with spec file path
#   {{PRD_FILE}}       - Replaced with prd.json path
#   {{PROGRESS_FILE}}  - Replaced with progress file path
#   {{AGENTS_FILE}}    - Replaced with agents file path
# ---------------------------------------------------------------------------
ralph_load_prompt_template() {
  local template_file="$1"
  local spec_file="$2"
  local prd_file="${3:-prd.json}"
  local progress_file="${4:-progress.txt}"
  local agents_file="${5:-AGENTS.md}"

  if [ ! -f "$template_file" ]; then
    printf 'Error: Template file not found: %s\n' "$template_file" >&2
    return 1
  fi

  local spec_escaped prd_escaped progress_escaped agents_escaped
  spec_escaped=$(printf '%s' "$spec_file" | sed 's/[&/\]/\\&/g')
  prd_escaped=$(printf '%s' "$prd_file" | sed 's/[&/\]/\\&/g')
  progress_escaped=$(printf '%s' "$progress_file" | sed 's/[&/\]/\\&/g')
  agents_escaped=$(printf '%s' "$agents_file" | sed 's/[&/\]/\\&/g')

  sed -e "s/{{SPEC_FILE}}/${spec_escaped}/g" \
    -e "s/{{PRD_FILE}}/${prd_escaped}/g" \
    -e "s/{{PROGRESS_FILE}}/${progress_escaped}/g" \
    -e "s/{{AGENTS_FILE}}/${agents_escaped}/g" \
    "$template_file"
}
```

- [ ] **Step 2: Replace `ralph_invoke_cli`**

Find and replace the entire `ralph_invoke_cli` function with:

```bash
# ---------------------------------------------------------------------------
# Invoke CLI with appropriate arguments
# ---------------------------------------------------------------------------
# Arguments:
#   $1 - CLI name (opencode, codex, cursor-agent, claude, gemini)
#   $2 - Mode (plan, build)
#   $3 - Path to prompt file containing the full prompt
#   $4 - spec_file path
#   $5 - prd_file path
#   $6 - progress_file path
#   $7 - agents_file path
# ---------------------------------------------------------------------------
ralph_invoke_cli() {
  local cli="$1"
  local mode="$2"
  local prompt_file="$3"
  local spec_file="$4"
  local prd_file="${5:-prd.json}"
  local progress_file="${6:-progress.txt}"
  local agents_file="${7:-AGENTS.md}"

  case "$cli" in
  opencode)
    opencode run -m opencode/kimi-k2.5 \
      "Execute Ralph ${mode}. Read spec, ${agents_file}, ${prd_file}, ${progress_file}, and instructions." \
      --file "$spec_file" --file "$agents_file" --file "$prd_file" --file "$progress_file" --file "$prompt_file"
    ;;
  codex)
    codex exec --yolo "$(cat "$prompt_file")"
    ;;
  gemini)
    gemini --approval-mode=yolo -p "$(cat "$prompt_file")"
    ;;
  cursor-agent)
    cursor-agent -p "$(cat "$prompt_file")"
    ;;
  claude)
    claude --dangerously-skip-permissions --print <"$prompt_file"
    ;;
  *)
    "$cli" --permission-mode acceptEdits "@${spec_file} @${agents_file} @${prd_file} @${progress_file} $(cat "$prompt_file")"
    ;;
  esac
}
```

- [ ] **Step 3: Replace `ralph_invoke_cli_capture`**

Find and replace the entire `ralph_invoke_cli_capture` function with:

```bash
# ---------------------------------------------------------------------------
# Invoke CLI with output capture (for AFK loop)
# Same as ralph_invoke_cli but captures output for signal detection
# ---------------------------------------------------------------------------
ralph_invoke_cli_capture() {
  local cli="$1"
  local mode="$2"
  local prompt_file="$3"
  local spec_file="$4"
  local prd_file="${5:-prd.json}"
  local progress_file="${6:-progress.txt}"
  local agents_file="${7:-AGENTS.md}"

  case "$cli" in
  opencode)
    opencode run -m opencode/kimi-k2.5 \
      "Execute Ralph ${mode}. Read spec, ${agents_file}, ${prd_file}, ${progress_file}, and instructions." \
      --file "$spec_file" --file "$agents_file" --file "$prd_file" --file "$progress_file" --file "$prompt_file" 2>&1 || true
    ;;
  codex)
    codex exec --yolo "$(cat "$prompt_file")" 2>&1 || true
    ;;
  gemini)
    gemini --approval-mode=yolo -p "$(cat "$prompt_file")" 2>&1 || true
    ;;
  cursor-agent)
    cursor-agent -p --force "$(cat "$prompt_file")" 2>&1 || true
    ;;
  claude)
    claude --dangerously-skip-permissions --print <"$prompt_file" 2>&1 || true
    ;;
  *)
    "$cli" --permission-mode acceptEdits "@${spec_file} @${agents_file} @${prd_file} @${progress_file} $(cat "$prompt_file")" 2>&1 || true
    ;;
  esac
}
```

- [ ] **Step 4: Update print functions — `ralph_print_afk_header`**

Find:
```bash
ralph_print_afk_header() {
  local mode="$1"
  local cli="$2"
  local spec_file="$3"
  local plan_file="$4"
  local max_iterations="$5"
  local branch_name="$6"
  ...
  printf '  Plan:           %s\n' "$plan_file"
```

Replace the locals and the printf line:
```bash
ralph_print_afk_header() {
  local mode="$1"
  local cli="$2"
  local spec_file="$3"
  local prd_file="$4"
  local max_iterations="$5"
  local branch_name="$6"

  printf '\n'
  printf 'Starting Ralph AFK Loop\n'
  printf '  Mode:           %s\n' "$mode"
  printf '  CLI:            %s\n' "$cli"
  printf '  Spec:           %s\n' "$spec_file"
  printf '  PRD:            %s\n' "$prd_file"
  printf '  Max iterations: %s\n' "$max_iterations"
  printf '  Branch:         %s\n' "$branch_name"
  printf '\n'
}
```

- [ ] **Step 5: Update `ralph_print_afk_blocked`**

Find:
```bash
ralph_print_afk_blocked() {
  local iteration="$1"
  local max_iterations="$2"
  local plan_file="$3"
  ...
  printf '  Check %s for details.\n' "$plan_file"
```

Replace with:
```bash
ralph_print_afk_blocked() {
  local iteration="$1"
  local max_iterations="$2"
  local prd_file="$3"

  printf '\n'
  printf '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
  printf '  Ralph AFK — BLOCKED\n'
  printf '  Stopped at iteration %s of %s\n' "$iteration" "$max_iterations"
  printf '  Non-recoverable blocker encountered.\n'
  printf '  Check %s for details.\n' "$prd_file"
  printf '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
}
```

- [ ] **Step 6: Update `ralph_print_afk_max_iter`**

Find:
```bash
ralph_print_afk_max_iter() {
  local max_iterations="$1"
  local branch_name="$2"
  local plan_file="$3"
  ...
  printf '  Check %s for status.\n' "$plan_file"
```

Replace with:
```bash
ralph_print_afk_max_iter() {
  local max_iterations="$1"
  local branch_name="$2"
  local prd_file="$3"

  printf '\n'
  printf '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
  printf '  Ralph AFK — Max iterations reached (%s)\n' "$max_iterations"
  printf "  Branch '%s' may have partial work.\n" "$branch_name"
  printf '  Check %s for status.\n' "$prd_file"
  printf '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
}
```

- [ ] **Step 7: Verify no remaining `PLAN_FILE` or `plan_file` references in ralph-common.sh**

```bash
grep -n 'PLAN_FILE\|plan_file\|IMPLEMENTATION_PLAN' lib/ralph-common.sh
```

Expected: zero results.

- [ ] **Step 8: Commit**

```bash
git add lib/ralph-common.sh
git commit -m "refactor: rename plan_file to prd_file throughout ralph-common.sh"
```

---

### Task 4: Update `prompts/base-plan.md`

**Files:**
- Modify: `prompts/base-plan.md`

- [ ] **Step 1: Rewrite the file**

Replace the entire contents of `prompts/base-plan.md` with:

```markdown
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
```

- [ ] **Step 2: Verify no `PLAN_FILE` or `IMPLEMENTATION_PLAN` references remain**

```bash
grep -n 'PLAN_FILE\|IMPLEMENTATION_PLAN' prompts/base-plan.md
```

Expected: zero results.

- [ ] **Step 3: Commit**

```bash
git add prompts/base-plan.md
git commit -m "refactor: update base-plan.md to write prd.json instead of IMPLEMENTATION_PLAN.md"
```

---

### Task 5: Update `prompts/base-build.md`

**Files:**
- Modify: `prompts/base-build.md`

- [ ] **Step 1: Rewrite the file**

Replace the entire contents of `prompts/base-build.md` with:

```markdown
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
```

- [ ] **Step 2: Verify no `PLAN_FILE` or `IMPLEMENTATION_PLAN` references remain**

```bash
grep -n 'PLAN_FILE\|IMPLEMENTATION_PLAN' prompts/base-build.md
```

Expected: zero results.

- [ ] **Step 3: Commit**

```bash
git add prompts/base-build.md
git commit -m "refactor: update base-build.md to read/update prd.json instead of IMPLEMENTATION_PLAN.md"
```

---

### Task 6: Update `afk.sh`

**Files:**
- Modify: `afk.sh`

- [ ] **Step 1: Rename `plan_file` variable and swap init call**

Find:
```bash
plan_file="IMPLEMENTATION_PLAN.md"
progress_file="progress.txt"
agents_file="AGENTS.md"

ralph_init_plan_file "$plan_file" "$spec_file"
ralph_init_progress_file "$progress_file"
ralph_init_agents_file "$agents_file"
```

Replace with:
```bash
prd_file="prd.json"
progress_file="progress.txt"
agents_file="AGENTS.md"

ralph_validate_jq || exit 1
ralph_init_prd_file "$prd_file"
ralph_init_progress_file "$progress_file"
ralph_init_agents_file "$agents_file"
```

- [ ] **Step 2: Update `ralph_load_prompt_template` call**

Find:
```bash
prompt_body=$(ralph_load_prompt_template "$template_file" "$spec_file" "$plan_file" "$progress_file" "$agents_file")
```

Replace with:
```bash
prompt_body=$(ralph_load_prompt_template "$template_file" "$spec_file" "$prd_file" "$progress_file" "$agents_file")
```

- [ ] **Step 3: Update AFK-specific terminal signals block**

Find the plan mode prompt_body append block. It currently references no variables but the surrounding code passes `plan_file`. No change needed to the signals text itself — just verify the surrounding `prd_file` variable is available (it is, from Step 1).

- [ ] **Step 4: Update `ralph_print_afk_header` call**

Find:
```bash
ralph_print_afk_header "$mode" "$cli" "$spec_file" "$plan_file" "$max_iterations" "$branch_name"
```

Replace with:
```bash
ralph_print_afk_header "$mode" "$cli" "$spec_file" "$prd_file" "$max_iterations" "$branch_name"
```

- [ ] **Step 5: Update `ralph_invoke_cli_capture` call**

Find:
```bash
ralph_invoke_cli_capture "$cli" "$mode" "$prompt_file" "$spec_file" "$plan_file" "$progress_file" "$agents_file" \
```

Replace with:
```bash
ralph_invoke_cli_capture "$cli" "$mode" "$prompt_file" "$spec_file" "$prd_file" "$progress_file" "$agents_file" \
```

- [ ] **Step 6: Update `ralph_print_afk_blocked` calls (two occurrences)**

Find and replace both occurrences of:
```bash
ralph_print_afk_blocked "$i" "$max_iterations" "$plan_file"
```

With:
```bash
ralph_print_afk_blocked "$i" "$max_iterations" "$prd_file"
```

- [ ] **Step 7: Update `ralph_print_afk_max_iter` call**

Find:
```bash
ralph_print_afk_max_iter "$max_iterations" "$branch_name" "$plan_file"
```

Replace with:
```bash
ralph_print_afk_max_iter "$max_iterations" "$branch_name" "$prd_file"
```

- [ ] **Step 8: Add shell-side completion check after signal check (build mode only)**

After the signal check block:
```bash
  if ralph_check_signals "$OUTPUT"; then
    signal_result=0
  else
    signal_result=$?
  fi
```

Insert immediately after:
```bash
  # Shell-side completion check: independently verify all prd.json tasks pass (build mode only)
  if [ "$mode" = "build" ] && [ -f "$prd_file" ] && ralph_check_prd_complete "$prd_file"; then
    if [ "$saw_complete" -eq 0 ]; then
      saw_complete=1
      complete_iteration="$i"
    fi
    break
  fi
```

- [ ] **Step 9: Verify no `plan_file` or `IMPLEMENTATION_PLAN` references remain in afk.sh**

```bash
grep -n 'plan_file\|IMPLEMENTATION_PLAN' afk.sh
```

Expected: zero results.

- [ ] **Step 10: Commit**

```bash
git add afk.sh
git commit -m "feat: wire prd.json into afk.sh with shell-side completion verification"
```

---

### Task 7: Update `run-once.sh`

**Files:**
- Modify: `run-once.sh`

- [ ] **Step 1: Rename `plan_file` variable and swap init call**

Find:
```bash
plan_file="IMPLEMENTATION_PLAN.md"
progress_file="progress.txt"
agents_file="AGENTS.md"

ralph_init_plan_file "$plan_file" "$spec_file"
ralph_init_progress_file "$progress_file"
ralph_init_agents_file "$agents_file"
```

Replace with:
```bash
prd_file="prd.json"
progress_file="progress.txt"
agents_file="AGENTS.md"

ralph_init_prd_file "$prd_file"
ralph_init_progress_file "$progress_file"
ralph_init_agents_file "$agents_file"
```

- [ ] **Step 2: Update `ralph_load_prompt_template` call**

Find:
```bash
prompt_body=$(ralph_load_prompt_template "$template_file" "$spec_file" "$plan_file" "$progress_file" "$agents_file")
```

Replace with:
```bash
prompt_body=$(ralph_load_prompt_template "$template_file" "$spec_file" "$prd_file" "$progress_file" "$agents_file")
```

- [ ] **Step 3: Update `ralph_invoke_cli` call**

Find:
```bash
ralph_invoke_cli "$cli" "$mode" "$prompt_file" "$spec_file" "$plan_file" "$progress_file" "$agents_file"
```

Replace with:
```bash
ralph_invoke_cli "$cli" "$mode" "$prompt_file" "$spec_file" "$prd_file" "$progress_file" "$agents_file"
```

- [ ] **Step 4: Verify no `plan_file` or `IMPLEMENTATION_PLAN` references remain**

```bash
grep -n 'plan_file\|IMPLEMENTATION_PLAN' run-once.sh
```

Expected: zero results.

- [ ] **Step 5: Commit**

```bash
git add run-once.sh
git commit -m "refactor: rename plan_file to prd_file in run-once.sh"
```

---

### Task 8: Smoke Test

**Files:** none (verification only)

- [ ] **Step 1: Confirm no `IMPLEMENTATION_PLAN` or `PLAN_FILE` references anywhere**

```bash
grep -rn 'IMPLEMENTATION_PLAN\|PLAN_FILE\|plan_file\|ralph_init_plan_file' \
  afk.sh run-once.sh lib/ralph-common.sh prompts/
```

Expected: zero results.

- [ ] **Step 2: Confirm `jq` is installed**

```bash
jq --version
```

Expected: `jq-1.x` or similar. If missing: `brew install jq`.

- [ ] **Step 3: Test `ralph_init_prd_file` creates `[]`**

```bash
cd /tmp && mkdir ralph-smoke && cd ralph-smoke
source /path/to/ralph-standalone/lib/ralph-common.sh
ralph_init_prd_file prd.json
cat prd.json
```

Expected output:
```
Initialized prd.json
[]
```

- [ ] **Step 4: Test `ralph_check_prd_complete` with mixed data**

```bash
echo '[{"description":"done","passes":true},{"description":"todo","passes":false}]' > prd.json
ralph_check_prd_complete prd.json && echo "FAIL: should be incomplete" || echo "PASS"

echo '[{"description":"done","passes":true}]' > prd.json
ralph_check_prd_complete prd.json && echo "PASS" || echo "FAIL: should be complete"

cd /tmp && rm -rf ralph-smoke
```

Expected:
```
PASS
PASS
```

- [ ] **Step 5: Test template substitution replaces `{{PRD_FILE}}`**

```bash
echo 'Read {{PRD_FILE}} for tasks.' > /tmp/test-template.md
source lib/ralph-common.sh
result=$(ralph_load_prompt_template /tmp/test-template.md spec.md prd.json progress.txt AGENTS.md)
echo "$result"
rm /tmp/test-template.md
```

Expected:
```
Read prd.json for tasks.
```

- [ ] **Step 6: Verify `afk.sh` help output still works (parse check)**

```bash
bash -n afk.sh && echo "PASS: syntax ok"
bash -n run-once.sh && echo "PASS: syntax ok"
bash -n lib/ralph-common.sh && echo "PASS: syntax ok"
```

Expected: three PASS lines, no errors.

- [ ] **Step 7: Final commit if any fixups needed, otherwise done**

```bash
git log --oneline -8
```

Verify all tasks have individual commits. Done.
