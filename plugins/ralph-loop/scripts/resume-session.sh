#!/bin/bash

# Resume a previous Ralph session

set -euo pipefail

SESSION_ID="${1:-}"

if [[ -z "$SESSION_ID" ]]; then
  echo "Error: Session ID required" >&2
  echo "" >&2
  echo "Usage: /ralph-loop:resume <session-id>" >&2
  echo "" >&2
  echo "List sessions with: /ralph-loop:sessions" >&2
  exit 1
fi

RALPH_DIR=".ralph"
SESSION_DIR="$RALPH_DIR/sessions/$SESSION_ID"
STATE_FILE="$SESSION_DIR/state.md"

if [[ ! -f "$STATE_FILE" ]]; then
  echo "Error: Session not found: $SESSION_ID" >&2
  echo "" >&2
  echo "List sessions with: /ralph-loop:sessions" >&2
  exit 1
fi

# Parse state file
FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE")
ITERATION=$(echo "$FRONTMATTER" | grep '^iteration:' | sed 's/iteration: *//')
MAX_ITERATIONS=$(echo "$FRONTMATTER" | grep '^max_iterations:' | sed 's/max_iterations: *//')
COMPLETION_PROMISE=$(echo "$FRONTMATTER" | grep '^completion_promise:' | sed 's/completion_promise: *//' | sed 's/^"\(.*\)"$/\1/')

# Extract prompt (everything after second ---)
PROMPT=$(awk '/^---$/{i++; next} i>=2' "$STATE_FILE")

# Update state to active
sed -i.bak 's/^active: false/active: true/' "$STATE_FILE"
rm -f "$STATE_FILE.bak"

# Update current symlink
rm -f "$RALPH_DIR/current"
ln -s "sessions/$SESSION_ID" "$RALPH_DIR/current"

# Log resume
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [session:$SESSION_ID] [iter $ITERATION] Resumed session" >> "$RALPH_DIR/activity.log"

# Add to progress
cat >> "$SESSION_DIR/progress.md" << EOF

---

**Resumed**: $(date -u +%Y-%m-%dT%H:%M:%SZ)

EOF

# Output resume message
cat << EOF
Resumed Ralph session!

Session: $SESSION_ID
Iteration: $ITERATION
Max iterations: $(if [[ "$MAX_ITERATIONS" -gt 0 ]]; then echo $MAX_ITERATIONS; else echo "unlimited"; fi)
Completion promise: $(if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then echo "$COMPLETION_PROMISE"; else echo "none"; fi)

EOF

# Display guardrails
if [[ -f "$RALPH_DIR/guardrails.md" ]]; then
  echo "=== GUARDRAILS ==="
  cat "$RALPH_DIR/guardrails.md"
  echo "=================="
  echo ""
fi

# Display recent progress
echo "=== RECENT PROGRESS ==="
tail -30 "$SESSION_DIR/progress.md"
echo "======================="
echo ""

# Output the prompt
echo "TASK:"
echo "$PROMPT"
echo ""

if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then
  echo "COMPLETION: <promise>$COMPLETION_PROMISE</promise>"
fi
