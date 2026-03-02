#!/usr/bin/env bash
# Ralph Run-Once — HITL single execution for one task.
# Usage: ralph/run-once.sh [mode] [cli] <spec_file> [task_slug]
#   mode: plan | build (default: build)
#
# Environment variable fallbacks:
#   RALPH_MODE         (default: build)
#   RALPH_CLI          (default: opencode)
#   RALPH_SPEC         (optional; auto-detects tasks/spec.md, spec.md, tasks/spec.json, spec.json)
#   RALPH_TASK_SLUG    (optional)
#   RALPH_BASE_BRANCH  (default: current branch)

set -euo pipefail

# ---------------------------------------------------------------------------
# Source shared library
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/ralph-common.sh
source "${SCRIPT_DIR}/lib/ralph-common.sh"

# ---------------------------------------------------------------------------
# Parse arguments using shared library (fixes shift bug)
# Sets global variables: RALPH_MODE, RALPH_CLI, RALPH_SPEC_FILE, RALPH_TASK_SLUG, RALPH_BASE_BRANCH
# ---------------------------------------------------------------------------
ralph_parse_args "$@"

mode="${RALPH_MODE}"
cli="${RALPH_CLI}"
spec_file="${RALPH_SPEC_FILE}"
task_slug="${RALPH_TASK_SLUG}"
base_branch="${RALPH_BASE_BRANCH}"

# ---------------------------------------------------------------------------
# Validate inputs using shared library
# ---------------------------------------------------------------------------
ralph_validate_spec "$spec_file" || {
  printf 'Usage: %s [mode] [cli] <spec_file> [task_slug]\n' "$0" >&2
  printf '       %s plan opencode tasks/spec.md\n' "$0" >&2
  printf '       %s plan gemini tasks/spec.md\n' "$0" >&2
  printf '       %s build opencode tasks/spec.md\n' "$0" >&2
  printf '       %s build codex tasks/spec.md\n' "$0" >&2
  printf '       RALPH_SPEC=<spec_file> %s\n' "$0" >&2
  printf '       (or create tasks/spec.md or spec.md)\n' >&2
  exit 1
}

ralph_validate_mode "$mode" || exit 1
ralph_validate_cli "$cli" || exit 1

# ---------------------------------------------------------------------------
# Branch naming using shared library
# ---------------------------------------------------------------------------
branch_name=$(ralph_generate_branch_name "$mode" "$spec_file" "$task_slug")

printf 'Creating branch: %s from %s\n' "$branch_name" "$base_branch"
git switch -c "$branch_name"

# ---------------------------------------------------------------------------
# Initialize operational files if missing using shared library
# ---------------------------------------------------------------------------
plan_file="IMPLEMENTATION_PLAN.md"
progress_file="progress.txt"
agents_file="AGENTS.md"

ralph_init_plan_file "$plan_file" "$spec_file"
ralph_init_progress_file "$progress_file"
ralph_init_agents_file "$agents_file"

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

prompt_body=$(ralph_load_prompt_template "$template_file" "$spec_file" "$plan_file" "$progress_file" "$agents_file")

# ---------------------------------------------------------------------------
# Execute using shared library
# ---------------------------------------------------------------------------
ralph_print_header "$mode" "$cli" "$spec_file" "$branch_name"

printf '%s\n' "$prompt_body" >"$prompt_file"

ralph_invoke_cli "$cli" "$mode" "$prompt_file" "$spec_file" "$plan_file" "$progress_file" "$agents_file"
exit_code=$?

ralph_print_completion "$exit_code" "$branch_name"

exit "$exit_code"
