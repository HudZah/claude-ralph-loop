#!/bin/bash

# Ralph Loop Stop Hook (Enhanced)
# Intercepts session exit and feeds prompt back
# Includes progress tracking, failure detection, and guardrails

set -euo pipefail

# Read hook input from stdin
HOOK_INPUT=$(cat)

RALPH_DIR=".ralph"
CURRENT_LINK="$RALPH_DIR/current"

# Check if there's an active session
if [[ ! -L "$CURRENT_LINK" ]]; then
  # No active loop - allow exit
  exit 0
fi

# Get session directory
SESSION_DIR="$RALPH_DIR/$(readlink "$CURRENT_LINK")"
STATE_FILE="$SESSION_DIR/state.md"

if [[ ! -f "$STATE_FILE" ]]; then
  # State file missing - allow exit
  exit 0
fi

# Parse state file frontmatter
FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE")
ACTIVE=$(echo "$FRONTMATTER" | grep '^active:' | sed 's/active: *//')
ITERATION=$(echo "$FRONTMATTER" | grep '^iteration:' | sed 's/iteration: *//')
MAX_ITERATIONS=$(echo "$FRONTMATTER" | grep '^max_iterations:' | sed 's/max_iterations: *//')
COMPLETION_PROMISE=$(echo "$FRONTMATTER" | grep '^completion_promise:' | sed 's/completion_promise: *//' | sed 's/^"\(.*\)"$/\1/')
SESSION_ID=$(echo "$FRONTMATTER" | grep '^session_id:' | sed 's/session_id: *//' | tr -d '"')

# Check if loop is active
if [[ "$ACTIVE" != "true" ]]; then
  exit 0
fi

# Validate numeric fields
if [[ ! "$ITERATION" =~ ^[0-9]+$ ]]; then
  echo "Ralph loop: State corrupted (iteration=$ITERATION)" >&2
  rm -f "$CURRENT_LINK"
  exit 0
fi

if [[ ! "$MAX_ITERATIONS" =~ ^[0-9]+$ ]]; then
  echo "Ralph loop: State corrupted (max_iterations=$MAX_ITERATIONS)" >&2
  rm -f "$CURRENT_LINK"
  exit 0
fi

# Check if max iterations reached
if [[ $MAX_ITERATIONS -gt 0 ]] && [[ $ITERATION -ge $MAX_ITERATIONS ]]; then
  echo "Ralph loop: Max iterations ($MAX_ITERATIONS) reached."

  # Mark session as completed
  sed -i.bak 's/^active: true/active: false/' "$STATE_FILE"
  rm -f "$STATE_FILE.bak"

  # Log completion
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [session:$SESSION_ID] [iter $ITERATION] Completed (max iterations)" >> "$RALPH_DIR/activity.log"

  # Add to progress
  cat >> "$SESSION_DIR/progress.md" << EOF

---
## Session Complete
**Ended**: $(date -u +%Y-%m-%dT%H:%M:%SZ)
**Reason**: Max iterations reached ($MAX_ITERATIONS)
**Final iteration**: $ITERATION
EOF

  rm -f "$CURRENT_LINK"
  exit 0
fi

# Get transcript path from hook input
TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path')

if [[ ! -f "$TRANSCRIPT_PATH" ]]; then
  echo "Ralph loop: Transcript not found" >&2
  exit 0
fi

# Extract last assistant message
if ! grep -q '"role":"assistant"' "$TRANSCRIPT_PATH"; then
  echo "Ralph loop: No assistant messages in transcript" >&2
  exit 0
fi

LAST_LINE=$(grep '"role":"assistant"' "$TRANSCRIPT_PATH" | tail -1)
LAST_OUTPUT=$(echo "$LAST_LINE" | jq -r '
  .message.content |
  map(select(.type == "text")) |
  map(.text) |
  join("\n")
' 2>/dev/null || echo "")

if [[ -z "$LAST_OUTPUT" ]]; then
  echo "Ralph loop: Empty assistant message" >&2
  exit 0
fi

# Check for completion promise
if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then
  PROMISE_TEXT=$(echo "$LAST_OUTPUT" | perl -0777 -pe 's/.*?<promise>(.*?)<\/promise>.*/$1/s; s/^\s+|\s+$//g; s/\s+/ /g' 2>/dev/null || echo "")

  if [[ -n "$PROMISE_TEXT" ]] && [[ "$PROMISE_TEXT" = "$COMPLETION_PROMISE" ]]; then
    echo "Ralph loop: Detected <promise>$COMPLETION_PROMISE</promise>"

    # Mark session as completed
    sed -i.bak 's/^active: true/active: false/' "$STATE_FILE"
    rm -f "$STATE_FILE.bak"

    # Log completion
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [session:$SESSION_ID] [iter $ITERATION] Completed (promise fulfilled)" >> "$RALPH_DIR/activity.log"

    # Add to progress
    cat >> "$SESSION_DIR/progress.md" << EOF

---
## Session Complete
**Ended**: $(date -u +%Y-%m-%dT%H:%M:%SZ)
**Reason**: Completion promise fulfilled
**Final iteration**: $ITERATION
EOF

    rm -f "$CURRENT_LINK"
    exit 0
  fi
fi

# --- Continue loop ---

NEXT_ITERATION=$((ITERATION + 1))

# Extract prompt from state file
PROMPT_TEXT=$(awk '/^---$/{i++; next} i>=2' "$STATE_FILE")

if [[ -z "$PROMPT_TEXT" ]]; then
  echo "Ralph loop: No prompt in state file" >&2
  rm -f "$CURRENT_LINK"
  exit 0
fi

# Update iteration in state file
TEMP_FILE="${STATE_FILE}.tmp.$$"
sed "s/^iteration: .*/iteration: $NEXT_ITERATION/" "$STATE_FILE" > "$TEMP_FILE"
mv "$TEMP_FILE" "$STATE_FILE"

# Log activity
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [session:$SESSION_ID] [iter $NEXT_ITERATION] Continuing loop" >> "$RALPH_DIR/activity.log"

# Add iteration summary to progress (brief)
cat >> "$SESSION_DIR/progress.md" << EOF

### Iteration $ITERATION - $(date -u +%Y-%m-%dT%H:%M:%SZ)
_Work in progress..._

EOF

# Build system message
GUARDRAILS_MSG=""
if [[ -f "$RALPH_DIR/guardrails.md" ]]; then
  # Extract just the Active Rules section
  RULES=$(sed -n '/^## Active Rules/,/^##/p' "$RALPH_DIR/guardrails.md" | head -20)
  if [[ -n "$RULES" ]]; then
    GUARDRAILS_MSG="

GUARDRAILS:
$RULES"
  fi
fi

if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then
  SYSTEM_MSG="Ralph iteration $NEXT_ITERATION | Complete: <promise>$COMPLETION_PROMISE</promise> (ONLY when TRUE!)$GUARDRAILS_MSG"
else
  SYSTEM_MSG="Ralph iteration $NEXT_ITERATION | No promise set - loop runs infinitely$GUARDRAILS_MSG"
fi

# Output JSON to block stop and feed prompt back
jq -n \
  --arg prompt "$PROMPT_TEXT" \
  --arg msg "$SYSTEM_MSG" \
  '{
    "decision": "block",
    "reason": $prompt,
    "systemMessage": $msg
  }'

exit 0
