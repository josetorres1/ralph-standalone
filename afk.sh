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
#   RALPH_SPEC         (required - no default)
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
  printf '       %s build opencode tasks/spec.md 20\n' "$0" >&2
  printf '       RALPH_SPEC=<spec_file> %s\n' "$0" >&2
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
# Initialize IMPLEMENTATION_PLAN.md if missing using shared library
# ---------------------------------------------------------------------------
plan_file="IMPLEMENTATION_PLAN.md"
ralph_init_plan_file "$plan_file" "$spec_file"

# ---------------------------------------------------------------------------
# Cleanup trap
# ---------------------------------------------------------------------------
prompt_file=".ralph-prompt.txt"
cleanup() {
  rm -f "$prompt_file"
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

prompt_body=$(ralph_load_prompt_template "$template_file" "$spec_file" "$plan_file")

# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------
ralph_print_afk_header "$mode" "$cli" "$spec_file" "$plan_file" "$max_iterations" "$branch_name"

for i in $(seq 1 "$max_iterations"); do
  ralph_print_afk_iteration "$i" "$max_iterations" "$cli" "$mode"

  printf '%s\n' "$prompt_body" >"$prompt_file"

  # Invoke CLI and capture output for signal detection
  OUTPUT=$(ralph_invoke_cli_capture "$cli" "$mode" "$prompt_file" "$spec_file" "$plan_file")
  printf '%s\n' "$OUTPUT"

  # Check for terminal signals
  ralph_check_signals "$OUTPUT"
  signal_result=$?

  if [ "$signal_result" -eq 1 ]; then
    ralph_print_afk_complete "$i" "$max_iterations" "$branch_name"
    exit 0
  fi

  if [ "$signal_result" -eq 2 ]; then
    ralph_print_afk_blocked "$i" "$max_iterations" "$plan_file"
    exit 2
  fi

  printf '\nIteration %s complete. Continuing in 2s...\n' "$i"
  sleep 2
done

ralph_print_afk_max_iter "$max_iterations" "$branch_name" "$plan_file"
exit 1
