#!/bin/bash

# Ralph Loop Setup Script (Enhanced)
# Creates session-based state for Ralph loop with guardrails

set -euo pipefail

# Parse arguments
PROMPT_PARTS=()
MAX_ITERATIONS=0
COMPLETION_PROMISE="null"

# Parse options and positional arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      cat << 'HELP_EOF'
Ralph Loop (Enhanced) - Iterative development with session persistence

USAGE:
  /ralph-loop:ralph-loop [PROMPT...] [OPTIONS]

ARGUMENTS:
  PROMPT...    Initial prompt to start the loop (can be multiple words)

OPTIONS:
  --max-iterations <n>           Maximum iterations before auto-stop (default: unlimited)
  --completion-promise '<text>'  Promise phrase (USE QUOTES for multi-word)
  -h, --help                     Show this help message

DESCRIPTION:
  Starts a Ralph Loop with enhanced features:
  - Session persistence in .ralph/sessions/
  - Global guardrails in .ralph/guardrails.md
  - Progress tracking per iteration
  - Failure detection and learning

  To signal completion, output: <promise>YOUR_PHRASE</promise>

EXAMPLES:
  /ralph-loop:ralph-loop Build a todo API --completion-promise 'DONE' --max-iterations 20
  /ralph-loop:ralph-loop --max-iterations 10 Fix the auth bug
  /ralph-loop:ralph-loop Refactor cache layer  (runs forever)

SESSION MANAGEMENT:
  /ralph-loop:sessions      List all past sessions
  /ralph-loop:resume <id>   Resume a previous session
  /ralph-loop:guardrail     Manage global guardrails

HELP_EOF
      exit 0
      ;;
    --max-iterations)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --max-iterations requires a number argument" >&2
        exit 1
      fi
      if ! [[ "$2" =~ ^[0-9]+$ ]]; then
        echo "Error: --max-iterations must be a positive integer, got: $2" >&2
        exit 1
      fi
      MAX_ITERATIONS="$2"
      shift 2
      ;;
    --completion-promise)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --completion-promise requires a text argument" >&2
        exit 1
      fi
      COMPLETION_PROMISE="$2"
      shift 2
      ;;
    *)
      PROMPT_PARTS+=("$1")
      shift
      ;;
  esac
done

# Join all prompt parts with spaces
PROMPT="${PROMPT_PARTS[*]}"

# Validate prompt
if [[ -z "$PROMPT" ]]; then
  echo "Error: No prompt provided" >&2
  echo "" >&2
  echo "Examples:" >&2
  echo "  /ralph-loop:ralph-loop Build a REST API for todos" >&2
  echo "  /ralph-loop:ralph-loop Fix the auth bug --max-iterations 20" >&2
  exit 1
fi

# Generate session ID: YYYY-MM-DD_<slug>
DATE_PREFIX=$(date +%Y-%m-%d)
# Create slug from prompt: lowercase, replace spaces with hyphens, remove special chars, limit length
SLUG=$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g' | cut -c1-30)
SESSION_ID="${DATE_PREFIX}_${SLUG}"

# Create .ralph directory structure
RALPH_DIR=".ralph"
SESSION_DIR="$RALPH_DIR/sessions/$SESSION_ID"

mkdir -p "$SESSION_DIR"

# Initialize guardrails.md if not exists
if [[ ! -f "$RALPH_DIR/guardrails.md" ]]; then
  cat > "$RALPH_DIR/guardrails.md" << 'GUARDRAILS_EOF'
# Ralph Guardrails

Global lessons learned from past failures. Claude reads these before EVERY iteration.

## Signs (Learned Failures)

<!-- Add entries when failures occur -->
<!-- Format:
### YYYY-MM-DD: Short description
- **Severity**: HIGH/MEDIUM/LOW
- **Context**: What was happening
- **Lesson**: What to do instead
-->

## Active Rules

1. Run tests before claiming completion
2. Check for TypeScript/linting errors before proceeding
3. Commit working changes incrementally
4. Read error messages carefully before retrying
5. If stuck 3+ times on same issue, try a different approach
GUARDRAILS_EOF
  echo "Created $RALPH_DIR/guardrails.md"
fi

# Quote completion promise for YAML
if [[ -n "$COMPLETION_PROMISE" ]] && [[ "$COMPLETION_PROMISE" != "null" ]]; then
  COMPLETION_PROMISE_YAML="\"$COMPLETION_PROMISE\""
else
  COMPLETION_PROMISE_YAML="null"
fi

# Create session state file - use printf to avoid shell expansion of prompt
{
  echo "---"
  echo "active: true"
  echo "iteration: 1"
  echo "max_iterations: $MAX_ITERATIONS"
  echo "completion_promise: $COMPLETION_PROMISE_YAML"
  echo "started_at: \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\""
  echo "session_id: \"$SESSION_ID\""
  echo "---"
  echo ""
  printf '%s\n' "$PROMPT"
} > "$SESSION_DIR/state.md"

# Create session progress file - use printf to avoid shell expansion of prompt
{
  echo "# Session: $SESSION_ID"
  echo ""
  echo "**Started**: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '**Task**: %s\n' "$PROMPT"
  echo ""
  echo "## Iterations"
  echo ""
} > "$SESSION_DIR/progress.md"

# Create session errors log
touch "$SESSION_DIR/errors.log"

# Create/update current symlink
rm -f "$RALPH_DIR/current"
ln -s "sessions/$SESSION_ID" "$RALPH_DIR/current"

# Initialize activity log if not exists
if [[ ! -f "$RALPH_DIR/activity.log" ]]; then
  touch "$RALPH_DIR/activity.log"
fi

# Log session start
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [session:$SESSION_ID] [iter 1] Started session" >> "$RALPH_DIR/activity.log"

# Output setup message
cat << EOF
Ralph loop activated!

Session: $SESSION_ID
Iteration: 1
Max iterations: $(if [[ $MAX_ITERATIONS -gt 0 ]]; then echo $MAX_ITERATIONS; else echo "unlimited"; fi)
Completion promise: $(if [[ "$COMPLETION_PROMISE" != "null" ]]; then echo "$COMPLETION_PROMISE"; else echo "none (runs forever)"; fi)

State: $SESSION_DIR/state.md
Progress: $SESSION_DIR/progress.md
Guardrails: $RALPH_DIR/guardrails.md

The stop hook will intercept exit attempts and feed the SAME PROMPT back.
You'll see your previous work in files, creating an iterative loop.

EOF

# Display guardrails
echo "=== GUARDRAILS (Read before each iteration) ==="
cat "$RALPH_DIR/guardrails.md"
echo "================================================"
echo ""

# Output the prompt - use printf to avoid shell expansion
echo "TASK:"
printf '%s\n' "$PROMPT"
echo ""

# Display completion promise requirements if set
if [[ "$COMPLETION_PROMISE" != "null" ]]; then
  cat << EOF
COMPLETION:
To complete this loop, output: <promise>$COMPLETION_PROMISE</promise>
ONLY output this when the statement is completely TRUE.
Do NOT lie to escape the loop.
EOF
fi
