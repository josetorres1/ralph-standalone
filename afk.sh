#!/usr/bin/env bash
# Ralph AFK Loop — autonomous agent loop until PRD is complete.
# Based on Geoffrey Huntley's ralph pattern: fresh context per iteration,
# progress persists in files/git, backpressure via feedback loops, one task per loop.
#
# Usage: ralph/afk.sh [mode] [cli] <spec_file> [task_slug] [max_iterations]
#   mode: plan | build (default: build)
#
# Environment variable fallbacks:
#   RALPH_MODE         (default: build)
#   RALPH_CLI          (default: opencode)
#   RALPH_SPEC         (optional; auto-detects tasks/spec.md, spec.md, tasks/spec.json, spec.json)
#   RALPH_TASK_SLUG    (optional)
#   RALPH_BASE_BRANCH  (default: current branch)
#   RALPH_MAX_ITER     (default: 10)

set -euo pipefail

# ---------------------------------------------------------------------------
# Source shared library
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/ralph-common.sh
source "${SCRIPT_DIR}/lib/ralph-common.sh"

# ---------------------------------------------------------------------------
# Parse arguments using shared library (fixes shift bug)
# Sets global variables: RALPH_MODE, RALPH_CLI, RALPH_SPEC_FILE, RALPH_TASK_SLUG, RALPH_MAX_ITER, RALPH_BASE_BRANCH
# ---------------------------------------------------------------------------
ralph_parse_args "$@"

mode="${RALPH_MODE}"
cli="${RALPH_CLI}"
spec_file="${RALPH_SPEC_FILE}"
task_slug="${RALPH_TASK_SLUG}"
max_iterations="${RALPH_MAX_ITER}"
base_branch="${RALPH_BASE_BRANCH}"

# ---------------------------------------------------------------------------
# Validate inputs using shared library
# ---------------------------------------------------------------------------
ralph_validate_spec "$spec_file" || {
  printf 'Usage: %s [mode] [cli] <spec_file> [task_slug] [max_iterations]\n' "$0" >&2
  printf '       %s plan opencode tasks/spec.md\n' "$0" >&2
  printf '       %s plan gemini tasks/spec.md\n' "$0" >&2
  printf '       %s build opencode tasks/spec.md 20\n' "$0" >&2
  printf '       %s build codex tasks/spec.md 20\n' "$0" >&2
  printf '       RALPH_SPEC=<spec_file> %s\n' "$0" >&2
  printf '       (or create tasks/spec.md or spec.md)\n' >&2
  exit 1
}

ralph_validate_mode "$mode" || exit 1
ralph_validate_cli "$cli" || exit 1
ralph_validate_max_iter "$max_iterations" || exit 1

# ---------------------------------------------------------------------------
# Branch naming using shared library
# ---------------------------------------------------------------------------
branch_name=$(ralph_generate_branch_name "$mode" "$spec_file" "$task_slug")

printf 'Creating branch: %s from %s\n' "$branch_name" "$base_branch"
git switch -c "$branch_name"

# ---------------------------------------------------------------------------
# Initialize operational files if missing using shared library
# ---------------------------------------------------------------------------
prd_file="prd.json"
progress_file="progress.txt"
agents_file="AGENTS.md"

ralph_validate_jq || exit 1
ralph_init_prd_file "$prd_file"
ralph_init_progress_file "$progress_file"
ralph_init_agents_file "$agents_file"

# ---------------------------------------------------------------------------
# Cleanup trap
# ---------------------------------------------------------------------------
prompt_file=".ralph-prompt.txt"
output_file=".ralph-output.tmp"
cleanup() {
  rm -f "$prompt_file" "$output_file"
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Load prompt template based on mode
# ---------------------------------------------------------------------------
template_dir="${SCRIPT_DIR}/prompts"
if [ "$mode" = "plan" ]; then
  template_file="${template_dir}/base-plan.md"
else
  template_file="${template_dir}/base-build.md"
fi

prompt_body=$(ralph_load_prompt_template "$template_file" "$spec_file" "$prd_file" "$progress_file" "$agents_file")

# ---------------------------------------------------------------------------
# Append AFK-specific terminal signals (not included in base prompts)
# ---------------------------------------------------------------------------
if [ "$mode" = "plan" ]; then
  prompt_body="${prompt_body}

TERMINAL SIGNALS:
- If blocked by missing information or an ambiguous spec, the final non-empty line must be exactly:
${RALPH_SIGNAL_BLOCKED}
- If planning is comprehensive and ready, the final non-empty line must be exactly:
${RALPH_SIGNAL_COMPLETE}"
else
  prompt_body="${prompt_body}

TERMINAL SIGNALS:
- If blocked by missing credentials, missing dependencies, or external outage, the final non-empty line must be exactly:
${RALPH_SIGNAL_BLOCKED}
- If all planned tasks are complete, the final non-empty line must be exactly:
${RALPH_SIGNAL_COMPLETE}"
fi

# Pre-compute sed pattern for stripping signal tags from streamed output
_complete_esc="${RALPH_SIGNAL_COMPLETE//\//\\/}"
_blocked_esc="${RALPH_SIGNAL_BLOCKED//\//\\/}"
_strip_pattern="/^${_complete_esc}$/d; /^${_blocked_esc}$/d"

# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------
ralph_print_afk_header "$mode" "$cli" "$spec_file" "$prd_file" "$max_iterations" "$branch_name"

saw_complete=0
complete_iteration=0
consecutive_no_progress=0
last_commit_hash=$(git rev-parse HEAD)

for i in $(seq 1 "$max_iterations"); do
  ralph_print_afk_iteration "$i" "$max_iterations" "$cli" "$mode"

  printf '%s\n' "$prompt_body" >"$prompt_file"

  # Invoke CLI — stream output in real-time and capture raw output for signal detection.
  # Promise tags are suppressed from streamed output so only afk.sh emits final terminal signals.
  ralph_invoke_cli_capture "$cli" "$mode" "$prompt_file" "$spec_file" "$prd_file" "$progress_file" "$agents_file" \
    | tee "$output_file" \
    | sed "$_strip_pattern"
  OUTPUT=$(cat "$output_file")
  rm -f "$output_file"

  # Check for terminal signals
  if ralph_check_signals "$OUTPUT"; then
    signal_result=0
  else
    signal_result=$?
  fi

  # Shell-side completion check: independently verify all prd.json tasks pass (build mode only)
  if [ "$mode" = "build" ] && [ -f "$prd_file" ] && ralph_check_prd_complete "$prd_file"; then
    if [ "$saw_complete" -eq 0 ]; then
      saw_complete=1
      complete_iteration="$i"
    fi
    break
  fi

  # Track progress via git commits
  current_commit_hash=$(git rev-parse HEAD)
  if [ "$current_commit_hash" = "$last_commit_hash" ] && [ "$signal_result" -eq 0 ]; then
    consecutive_no_progress=$((consecutive_no_progress + 1))
    printf '\nNo progress detected (no commits, no signals) for %s iteration(s).\n' "$consecutive_no_progress"
  else
    consecutive_no_progress=0
    last_commit_hash="$current_commit_hash"
  fi

  if [ "$consecutive_no_progress" -ge 3 ]; then
    printf '\nStuck detected: 3 consecutive iterations without progress. Blocking.\n'
    ralph_print_afk_blocked "$i" "$max_iterations" "$prd_file"
    printf '%s\n' "$RALPH_SIGNAL_BLOCKED"
    exit 2
  fi

  if [ "$signal_result" -eq 1 ]; then
    saw_complete=1
    if [ "$complete_iteration" -eq 0 ]; then
      complete_iteration="$i"
    fi
    # If we saw COMPLETE, we stop the loop immediately to avoid redundant iterations
    break
  fi

  if [ "$signal_result" -eq 2 ]; then
    ralph_print_afk_blocked "$i" "$max_iterations" "$prd_file"
    printf '%s\n' "$RALPH_SIGNAL_BLOCKED"
    exit 2
  fi

  printf '\nIteration %s complete. Continuing in 2s...\n' "$i"
  sleep 2
done

if [ "$saw_complete" -eq 1 ]; then
  ralph_print_afk_complete "$complete_iteration" "$max_iterations" "$branch_name"
  
  # Human-in-the-loop checkpoint for planning
  if [ "$mode" = "plan" ] && [ -t 0 ]; then
    printf '\nPlanning complete. Review %s and %s.\n' "$prd_file" "$progress_file"
    printf 'Press Enter to exit or Ctrl+C to abort...\n'
    read -r _
  fi

  printf '%s\n' "$RALPH_SIGNAL_COMPLETE"
  exit 0
fi

ralph_print_afk_max_iter "$max_iterations" "$branch_name" "$prd_file"
printf '%s\n' "$RALPH_SIGNAL_BLOCKED"
exit 1
