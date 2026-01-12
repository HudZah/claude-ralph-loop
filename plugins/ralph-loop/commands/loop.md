---
description: "Start Ralph Loop with session persistence and guardrails"
argument-hint: '"Build a REST API" [--max-iterations 20] [--completion-promise "All tests pass"]'
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-loop.sh:*)"]
hide-from-slash-command-tool: "true"
---

# Ralph Loop Command

Execute the setup script to initialize a new Ralph loop session:

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-loop.sh" $ARGUMENTS
```

After initialization, work on the task. When you try to exit, the stop hook will intercept and feed the SAME PROMPT back. You'll see your previous work in files, creating an iterative loop.

## Important Rules

1. **Read guardrails** shown at the start of each iteration
2. **Make incremental progress** - don't try to do everything at once
3. **Commit working changes** to preserve progress
4. **If stuck**, try a different approach rather than repeating the same failed attempt

## Completion

If a completion promise is set, ONLY output it when the statement is completely TRUE:

```
<promise>COMPLETION_PHRASE</promise>
```

Do NOT lie to escape the loop. The loop is designed to continue until genuine completion.
