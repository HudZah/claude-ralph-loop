---
description: "Resume a previous Ralph session"
argument-hint: "2024-01-12_build-a-rest-api"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/resume-session.sh:*)"]
hide-from-slash-command-tool: "true"
---

# Resume Session

Execute the resume script with the session ID:

```!
RALPH_ARGS=$ARGUMENTS "${CLAUDE_PLUGIN_ROOT}/scripts/resume-session.sh"
```

This will:
1. Restore the session as active
2. Show the guardrails and recent progress
3. Continue from where you left off

List available sessions with `/ralph-loop:sessions`
