#!/usr/bin/env bash
# ralph-common.sh — Shared library for Ralph scripts
# Usage: source "$(dirname "$0")/lib/ralph-common.sh"
#
# This library provides common functionality for Ralph automation scripts:
# - Argument parsing with mode support (fixes the shift bug)
# - Input validation
# - Branch name generation
# - Plan file initialization
# - CLI invocation
# - Prompt template loading
#
# All functions use strict quoting and are shellcheck-compliant.
# Compatible with bash 3.2+ (avoids associative arrays).

set -euo pipefail

# Global variables set by ralph_parse_args():
#   RALPH_MODE, RALPH_CLI, RALPH_SPEC_FILE, RALPH_TASK_SLUG, RALPH_MAX_ITER, RALPH_BASE_BRANCH

# ---------------------------------------------------------------------------
# Resolve spec file from explicit arg/env or default local candidates
# ---------------------------------------------------------------------------
ralph_resolve_spec_file() {
  local provided_spec="${1:-}"
  if [ -n "$provided_spec" ]; then
    printf '%s' "$provided_spec"
    return 0
  fi

  local candidate
  for candidate in "tasks/spec.md" "spec.md" "tasks/spec.json" "spec.json"; do
    if [ -f "$candidate" ]; then
      printf '%s' "$candidate"
      return 0
    fi
  done

  printf ''
}

# ---------------------------------------------------------------------------
# Parse arguments with mode support
# Fixes the bug where task_slug was read from wrong position after shift
# ---------------------------------------------------------------------------
# Sets global variables:
#   RALPH_MODE, RALPH_CLI, RALPH_SPEC_FILE, RALPH_TASK_SLUG, RALPH_MAX_ITER, RALPH_BASE_BRANCH
# ---------------------------------------------------------------------------
ralph_parse_args() {
  # Capture all positional params before any shift operations
  local arg_mode="${1:-${RALPH_MODE:-build}}"
  local arg_cli="${2:-${RALPH_CLI:-opencode}}"
  local arg_spec="${3:-${RALPH_SPEC:-}}"
  local arg_task="${4:-${RALPH_TASK_SLUG:-}}"
  local arg_max_iter="${5:-${RALPH_MAX_ITER:-10}}"

  # If first arg is a known mode, reassign remaining args correctly
  if [[ "$arg_mode" =~ ^(plan|build)$ ]]; then
    # Mode was explicitly specified
    arg_cli="${2:-${RALPH_CLI:-opencode}}"
    arg_spec="${3:-${RALPH_SPEC:-}}"
    arg_task="${4:-${RALPH_TASK_SLUG:-}}"
    arg_max_iter="${5:-${RALPH_MAX_ITER:-10}}"
  else
    # First arg was actually CLI, default mode to build
    arg_cli="$arg_mode"
    arg_mode="build"
    arg_spec="${2:-${RALPH_SPEC:-}}"
    arg_task="${3:-${RALPH_TASK_SLUG:-}}"
    arg_max_iter="${4:-${RALPH_MAX_ITER:-10}}"
  fi

  arg_spec="$(ralph_resolve_spec_file "$arg_spec")"

  # Set global variables for caller
  RALPH_MODE="$arg_mode"
  RALPH_CLI="$arg_cli"
  RALPH_SPEC_FILE="$arg_spec"
  RALPH_TASK_SLUG="$arg_task"
  RALPH_MAX_ITER="$arg_max_iter"
  RALPH_BASE_BRANCH="${RALPH_BASE_BRANCH:-$(git branch --show-current)}"
}

# ---------------------------------------------------------------------------
# Validate mode
# ---------------------------------------------------------------------------
ralph_validate_mode() {
  local mode="$1"
  case "$mode" in
  plan | build) ;;
  *)
    printf 'Unsupported mode: %s\n' "$mode" >&2
    printf 'Use one of: plan, build\n' >&2
    return 1
    ;;
  esac
}

# ---------------------------------------------------------------------------
# Validate CLI
# ---------------------------------------------------------------------------
ralph_validate_cli() {
  local cli="$1"
  case "$cli" in
  claude | codex | cursor-agent | gemini | opencode) ;;
  *)
    printf 'Unsupported CLI: %s\n' "$cli" >&2
    printf 'Use one of: opencode, codex, cursor-agent, claude, gemini\n' >&2
    return 1
    ;;
  esac
}

# ---------------------------------------------------------------------------
# Validate max_iterations is a positive integer
# ---------------------------------------------------------------------------
ralph_validate_max_iter() {
  local max_iter="$1"
  if ! [[ "$max_iter" =~ ^[0-9]+$ ]]; then
    printf 'max_iterations must be a positive integer, got: %s\n' "$max_iter" >&2
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Validate required spec_file
# ---------------------------------------------------------------------------
ralph_validate_spec() {
  local spec_file="$1"
  if [ -z "$spec_file" ]; then
    printf 'Error: spec_file is required (arg, RALPH_SPEC, or one of: tasks/spec.md, spec.md, tasks/spec.json, spec.json)\n' >&2
    return 1
  fi

  if [[ ! "$spec_file" =~ \.(md|json)$ ]]; then
    printf 'Error: spec_file must be .md or .json, got: %s\n' "$spec_file" >&2
    return 1
  fi

  if [ ! -f "$spec_file" ]; then
    printf 'Error: spec_file not found: %s\n' "$spec_file" >&2
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Generate branch name
# ---------------------------------------------------------------------------
ralph_generate_branch_name() {
  local mode="$1"
  local spec_file="$2"
  local task_slug="$3"

  local spec_base
  spec_base=$(basename "$spec_file" .md)
  local spec_short
  spec_short=$(printf '%s' "$spec_base" | cut -c1-15)
  local timestamp
  timestamp=$(date +%m%d-%H%M)
  local branch_suffix="${spec_short}-${timestamp}"

  if [ -n "$task_slug" ]; then
    printf 'ralph/%s/%s' "$task_slug" "$branch_suffix"
  else
    printf 'ralph/%s/%s' "$mode" "$branch_suffix"
  fi
}

# ---------------------------------------------------------------------------
# Initialize IMPLEMENTATION_PLAN.md if missing
# ---------------------------------------------------------------------------
ralph_init_plan_file() {
  local plan_file="${1:-IMPLEMENTATION_PLAN.md}"
  local spec_file="${2:-spec.md}"

  if [ ! -f "$plan_file" ]; then
    {
      printf '# Implementation Plan\n\n'
      printf 'Generated: %s\n' "$(date)"
      printf 'Spec: %s\n\n' "$spec_file"
      printf '## Status\n\n'
      printf '%s\n' '- [ ] Gap analysis complete'
      printf '%s\n' '- [ ] Planning phase complete'
      printf '%s\n\n' '- [ ] Build phase'
      printf '## Tasks\n\n'
      printf '## Open Questions / Notes\n\n'
      printf '## Inconsistencies (None Found)\n\n'
    } >"$plan_file"
    printf 'Initialized %s\n' "$plan_file"
  fi
}

# ---------------------------------------------------------------------------
# Initialize progress.txt if missing (high-density context)
# ---------------------------------------------------------------------------
ralph_init_progress_file() {
  local progress_file="${1:-progress.txt}"
  if [ ! -f "$progress_file" ]; then
    {
      printf 'LAST_TASK: None\n'
      printf 'STATUS: Initializing\n'
      printf 'NEXT_STEPS:\n'
      printf '%s\n' '- Initial planning'
    } >"$progress_file"
    printf 'Initialized %s\n' "$progress_file"
  fi
}

# ---------------------------------------------------------------------------
# Initialize AGENTS.md if missing (validation source of truth)
# ---------------------------------------------------------------------------
ralph_init_agents_file() {
  local agents_file="${1:-AGENTS.md}"
  if [ ! -f "$agents_file" ]; then
    {
      printf '# Agent Instructions\n\n'
      printf '## Project Patterns\n\n'
      printf '%s\n' '- Use parallel subagents for research.'
      printf '%s\n\n' '- Follow idiomatic TypeScript/Node patterns.'
      printf '## Validation Commands\n\n'
      printf '```bash\n'
      printf '# Edit these to match your project\n'
      printf 'npm test\n'
      printf 'npm run lint\n'
      printf 'npm run typecheck\n'
      printf '```\n'
    } >"$agents_file"
    printf 'Initialized %s\n' "$agents_file"
  fi
}

# ---------------------------------------------------------------------------
# Load prompt template and substitute placeholders
# ---------------------------------------------------------------------------
# Placeholders supported:
#   {{SPEC_FILE}}      - Replaced with spec file path
#   {{PLAN_FILE}}      - Replaced with plan file path
#   {{PROGRESS_FILE}}  - Replaced with progress file path
#   {{AGENTS_FILE}}    - Replaced with agents file path
# ---------------------------------------------------------------------------
ralph_load_prompt_template() {
  local template_file="$1"
  local spec_file="$2"
  local plan_file="${3:-IMPLEMENTATION_PLAN.md}"
  local progress_file="${4:-progress.txt}"
  local agents_file="${5:-AGENTS.md}"

  if [ ! -f "$template_file" ]; then
    printf 'Error: Template file not found: %s\n' "$template_file" >&2
    return 1
  fi

  # Read template and substitute placeholders using sed
  # Escape special characters in paths for sed
  local spec_escaped plan_escaped progress_escaped agents_escaped
  spec_escaped=$(printf '%s' "$spec_file" | sed 's/[&/\]/\\&/g')
  plan_escaped=$(printf '%s' "$plan_file" | sed 's/[&/\]/\\&/g')
  progress_escaped=$(printf '%s' "$progress_file" | sed 's/[&/\]/\\&/g')
  agents_escaped=$(printf '%s' "$agents_file" | sed 's/[&/\]/\\&/g')

  sed -e "s/{{SPEC_FILE}}/${spec_escaped}/g" \
    -e "s/{{PLAN_FILE}}/${plan_escaped}/g" \
    -e "s/{{PROGRESS_FILE}}/${progress_escaped}/g" \
    -e "s/{{AGENTS_FILE}}/${agents_escaped}/g" \
    "$template_file"
}

# ---------------------------------------------------------------------------
# Invoke CLI with appropriate arguments
# ---------------------------------------------------------------------------
# Arguments:
#   $1 - CLI name (opencode, codex, cursor-agent, claude, gemini)
#   $2 - Mode (plan, build)
#   $3 - Path to prompt file containing the full prompt
#   $4 - spec_file path
#   $5 - plan_file path
#   $6 - progress_file path
#   $7 - agents_file path
# ---------------------------------------------------------------------------
ralph_invoke_cli() {
  local cli="$1"
  local mode="$2"
  local prompt_file="$3"
  local spec_file="$4"
  local plan_file="${5:-IMPLEMENTATION_PLAN.md}"
  local progress_file="${6:-progress.txt}"
  local agents_file="${7:-AGENTS.md}"

  case "$cli" in
  opencode)
    opencode run -m opencode/kimi-k2.5 \
      "Execute Ralph ${mode}. Read spec, ${agents_file}, ${plan_file}, ${progress_file}, and instructions." \
      --file "$spec_file" --file "$agents_file" --file "$plan_file" --file "$progress_file" --file "$prompt_file"
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
    "$cli" --permission-mode acceptEdits "@${spec_file} @${agents_file} @${plan_file} @${progress_file} $(cat "$prompt_file")"
    ;;
  esac
}

# ---------------------------------------------------------------------------
# Invoke CLI with output capture (for AFK loop)
# Same as ralph_invoke_cli but captures output for signal detection
# ---------------------------------------------------------------------------
ralph_invoke_cli_capture() {
  local cli="$1"
  local mode="$2"
  local prompt_file="$3"
  local spec_file="$4"
  local plan_file="${5:-IMPLEMENTATION_PLAN.md}"
  local progress_file="${6:-progress.txt}"
  local agents_file="${7:-AGENTS.md}"

  case "$cli" in
  opencode)
    opencode run -m opencode/kimi-k2.5 \
      "Execute Ralph ${mode}. Read spec, ${agents_file}, ${plan_file}, ${progress_file}, and instructions." \
      --file "$spec_file" --file "$agents_file" --file "$plan_file" --file "$progress_file" --file "$prompt_file" 2>&1 || true
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
    "$cli" --permission-mode acceptEdits "@${spec_file} @${agents_file} @${plan_file} @${progress_file} $(cat "$prompt_file")" 2>&1 || true
    ;;
  esac
}

# ---------------------------------------------------------------------------
# Print execution header
# ---------------------------------------------------------------------------
ralph_print_header() {
  local mode="$1"
  local cli="$2"
  local spec_file="$3"
  local branch_name="$4"

  printf '\n'
  printf '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
  printf 'Mode:   %s\n' "$mode"
  printf 'CLI:    %s\n' "$cli"
  printf 'Spec:   %s\n' "$spec_file"
  printf 'Branch: %s\n' "$branch_name"
  printf '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
  printf '\n'
}

# ---------------------------------------------------------------------------
# Print AFK loop header
# ---------------------------------------------------------------------------
ralph_print_afk_header() {
  local mode="$1"
  local cli="$2"
  local spec_file="$3"
  local plan_file="$4"
  local max_iterations="$5"
  local branch_name="$6"

  printf '\n'
  printf 'Starting Ralph AFK Loop\n'
  printf '  Mode:           %s\n' "$mode"
  printf '  CLI:            %s\n' "$cli"
  printf '  Spec:           %s\n' "$spec_file"
  printf '  Plan:           %s\n' "$plan_file"
  printf '  Max iterations: %s\n' "$max_iterations"
  printf '  Branch:         %s\n' "$branch_name"
  printf '\n'
}

# ---------------------------------------------------------------------------
# Print AFK iteration header
# ---------------------------------------------------------------------------
ralph_print_afk_iteration() {
  local iteration="$1"
  local max_iterations="$2"
  local cli="$3"
  local mode="$4"

  printf '\n'
  printf '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
  printf '  Ralph AFK — Iteration %s of %s (%s) [%s]\n' "$iteration" "$max_iterations" "$cli" "$mode"
  printf '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
  printf '\n'
}

# ---------------------------------------------------------------------------
# Check output for terminal signals
# Returns: 0 = continue, 1 = complete, 2 = blocked
# ---------------------------------------------------------------------------
ralph_check_signals() {
  local output="$1"

  # Treat signals as valid only when they are the final non-empty line.
  # This avoids false positives when tags are mentioned in instructions
  # or quoted mid-response.
  local last_non_empty
  last_non_empty=$(printf '%s\n' "$output" | awk 'NF { line=$0 } END { print line }')

  if [[ "$last_non_empty" == "<promise>COMPLETE</promise>" ]]; then
    return 1
  fi

  if [[ "$last_non_empty" == "<promise>BLOCKED</promise>" ]]; then
    return 2
  fi

  return 0
}

# ---------------------------------------------------------------------------
# Print final status message
# ---------------------------------------------------------------------------
ralph_print_completion() {
  local exit_code="$1"
  local branch_name="$2"

  printf '\n'
  if [ "$exit_code" -eq 0 ]; then
    printf "Task complete. Branch '%s' is ready for PR.\n" "$branch_name"
  else
    printf "Task failed with exit code %s. Branch '%s' may have partial work.\n" "$exit_code" "$branch_name"
  fi
}

# ---------------------------------------------------------------------------
# Print AFK final status messages
# ---------------------------------------------------------------------------
ralph_print_afk_complete() {
  local iteration="$1"
  local max_iterations="$2"
  local branch_name="$3"

  printf '\n'
  printf '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
  printf '  Ralph AFK — ALL TASKS COMPLETE\n'
  printf '  Finished at iteration %s of %s\n' "$iteration" "$max_iterations"
  printf "  Branch '%s' is ready for PR.\n" "$branch_name"
  printf '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
}

ralph_print_afk_blocked() {
  local iteration="$1"
  local max_iterations="$2"
  local plan_file="$3"

  printf '\n'
  printf '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
  printf '  Ralph AFK — BLOCKED\n'
  printf '  Stopped at iteration %s of %s\n' "$iteration" "$max_iterations"
  printf '  Non-recoverable blocker encountered.\n'
  printf '  Check %s for details.\n' "$plan_file"
  printf '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
}

ralph_print_afk_max_iter() {
  local max_iterations="$1"
  local branch_name="$2"
  local plan_file="$3"

  printf '\n'
  printf '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
  printf '  Ralph AFK — Max iterations reached (%s)\n' "$max_iterations"
  printf "  Branch '%s' may have partial work.\n" "$branch_name"
  printf '  Check %s for status.\n' "$plan_file"
  printf '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
}
