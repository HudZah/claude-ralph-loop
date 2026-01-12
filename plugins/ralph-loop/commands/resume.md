---
description: "Resume a previous Ralph session"
argument-hint: "<session-id>"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/resume-session.sh:*)"]
hide-from-slash-command-tool: "true"
---

# Resume Session

Execute the resume script with the session ID:

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/resume-session.sh" $ARGUMENTS
```

This will:
1. Restore the session as active
2. Show the guardrails and recent progress
3. Continue from where you left off

List available sessions with `/ralph-loop:sessions`
