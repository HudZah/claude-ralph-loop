#!/bin/bash

# Manage global guardrails

set -euo pipefail

# Handle arguments passed via RALPH_ARGS environment variable
if [[ -n "${RALPH_ARGS:-}" ]]; then
  eval "set -- $RALPH_ARGS"
fi

ACTION="${1:-list}"
shift || true

RALPH_DIR=".ralph"
GUARDRAILS_FILE="$RALPH_DIR/guardrails.md"

# Ensure .ralph directory exists
mkdir -p "$RALPH_DIR"

# Initialize guardrails if not exists
if [[ ! -f "$GUARDRAILS_FILE" ]]; then
  cat > "$GUARDRAILS_FILE" << 'GUARDRAILS_EOF'
# Ralph Guardrails

Global lessons learned from past failures. Claude reads these before EVERY iteration.

## Signs (Learned Failures)

<!-- Add entries when failures occur -->

## Active Rules

1. Run tests before claiming completion
2. Check for TypeScript/linting errors before proceeding
3. Commit working changes incrementally
4. Read error messages carefully before retrying
5. If stuck 3+ times on same issue, try a different approach
GUARDRAILS_EOF
fi

case "$ACTION" in
  list)
    echo "=== Global Guardrails ==="
    echo ""
    cat "$GUARDRAILS_FILE"
    echo ""
    echo "========================="
    echo ""
    echo "Commands:"
    echo "  /ralph-loop:guardrail add \"New rule\""
    echo "  /ralph-loop:guardrail clear"
    ;;

  add)
    RULE="${*:-}"
    if [[ -z "$RULE" ]]; then
      echo "Error: Rule text required" >&2
      echo "" >&2
      echo "Usage: /ralph-loop:guardrail add \"Never do X without Y\"" >&2
      exit 1
    fi

    # Find the last numbered rule and increment
    LAST_NUM=$(grep -E '^[0-9]+\.' "$GUARDRAILS_FILE" | tail -1 | grep -oE '^[0-9]+' || echo "0")
    NEXT_NUM=$((LAST_NUM + 1))

    # Append the new rule
    echo "$NEXT_NUM. $RULE" >> "$GUARDRAILS_FILE"

    echo "Added guardrail #$NEXT_NUM: $RULE"
    echo ""
    echo "This rule will be shown before every Ralph iteration."
    ;;

  sign|failure)
    # Add a learned failure sign
    DESCRIPTION="${*:-}"
    if [[ -z "$DESCRIPTION" ]]; then
      echo "Error: Failure description required" >&2
      echo "" >&2
      echo "Usage: /ralph-loop:guardrail sign \"Description of failure and lesson\"" >&2
      exit 1
    fi

    DATE=$(date +%Y-%m-%d)

    # Find the Signs section and append
    # This is a bit tricky with sed, so we'll just append after the Signs header
    cat >> "$GUARDRAILS_FILE" << EOF

### $DATE: $DESCRIPTION
- **Severity**: MEDIUM
- **Context**: Added manually
- **Lesson**: Avoid this pattern
EOF

    echo "Added failure sign: $DESCRIPTION"
    echo ""
    echo "Edit $GUARDRAILS_FILE to adjust severity and details."
    ;;

  clear)
    # Reset to default guardrails
    cat > "$GUARDRAILS_FILE" << 'GUARDRAILS_EOF'
# Ralph Guardrails

Global lessons learned from past failures. Claude reads these before EVERY iteration.

## Signs (Learned Failures)

<!-- Cleared - add new entries as failures occur -->

## Active Rules

1. Run tests before claiming completion
2. Check for TypeScript/linting errors before proceeding
3. Commit working changes incrementally
GUARDRAILS_EOF

    echo "Guardrails reset to defaults."
    echo ""
    echo "Previous learned failures have been cleared."
    ;;

  *)
    echo "Unknown action: $ACTION" >&2
    echo "" >&2
    echo "Usage:" >&2
    echo "  /ralph-loop:guardrail list             Show all guardrails" >&2
    echo "  /ralph-loop:guardrail add \"Rule\"       Add a new rule" >&2
    echo "  /ralph-loop:guardrail sign \"Failure\"   Add a learned failure" >&2
    echo "  /ralph-loop:guardrail clear            Reset to defaults" >&2
    exit 1
    ;;
esac
