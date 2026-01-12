---
description: "Manage global guardrails"
argument-hint: 'add "Always run tests" | sign "Forgot to check types" | list | clear'
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/manage-guardrails.sh:*)"]
hide-from-slash-command-tool: "true"
---

# Guardrail Management

Execute the guardrails script:

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/manage-guardrails.sh" $ARGUMENTS
```

## Commands

- `list` - Show all guardrails
- `add "rule"` - Add a new active rule
- `sign "failure"` - Add a learned failure
- `clear` - Reset guardrails to defaults

## About Guardrails

Guardrails are global lessons that persist across ALL Ralph sessions. They help Claude:
- Avoid repeating past mistakes
- Follow best practices
- Learn from failures

Guardrails are shown at the start of every Ralph iteration.
