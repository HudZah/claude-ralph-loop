#!/bin/bash

# List all Ralph sessions

set -euo pipefail

RALPH_DIR=".ralph"
SESSIONS_DIR="$RALPH_DIR/sessions"

if [[ ! -d "$SESSIONS_DIR" ]]; then
  echo "No Ralph sessions found."
  echo ""
  echo "Start a new session with:"
  echo "  /ralph-loop:ralph-loop \"Your task here\""
  exit 0
fi

# Get current session if exists
CURRENT_SESSION=""
if [[ -L "$RALPH_DIR/current" ]]; then
  CURRENT_SESSION=$(readlink "$RALPH_DIR/current" | sed 's|sessions/||')
fi

echo "Ralph Sessions"
echo "=============="
echo ""

# Table header
printf "%-35s | %-10s | %-6s | %-20s\n" "Session ID" "Status" "Iter" "Started"
printf "%-35s-+-%-10s-+-%-6s-+-%-20s\n" "-----------------------------------" "----------" "------" "--------------------"

# List sessions (sorted by name, which includes date)
for session_dir in $(ls -1d "$SESSIONS_DIR"/*/ 2>/dev/null | sort -r); do
  session_id=$(basename "$session_dir")
  state_file="$session_dir/state.md"

  if [[ -f "$state_file" ]]; then
    # Parse frontmatter
    frontmatter=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$state_file")
    active=$(echo "$frontmatter" | grep '^active:' | sed 's/active: *//')
    iteration=$(echo "$frontmatter" | grep '^iteration:' | sed 's/iteration: *//')
    started=$(echo "$frontmatter" | grep '^started_at:' | sed 's/started_at: *//' | tr -d '"' | cut -c1-16)

    # Determine status
    if [[ "$active" == "true" ]]; then
      if [[ "$session_id" == "$CURRENT_SESSION" ]]; then
        status="ACTIVE *"
      else
        status="active"
      fi
    else
      status="completed"
    fi

    printf "%-35s | %-10s | %-6s | %-20s\n" "$session_id" "$status" "$iteration" "$started"
  fi
done

echo ""
echo "* = current session"
echo ""
echo "Commands:"
echo "  /ralph-loop:resume <session-id>  Resume a session"
echo "  /ralph-loop:guardrail list       View global guardrails"
