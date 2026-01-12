# Ralph Loop Marketplace

A Claude Code plugin marketplace for iterative development using the Ralph Wiggum technique.

## What is Ralph Loop?

Ralph Loop implements iterative development based on Geoffrey Huntley's Ralph Wiggum technique. The concept is simple:

```bash
while :; do
  cat PROMPT.md | claude --continue
done
```

The same prompt is fed to Claude repeatedly. Claude sees its previous work in files and git history, allowing iterative improvement until the task is complete.

## Installation

1. Add the marketplace:
```bash
/plugin add-marketplace https://github.com/hudzah/claude-ralph-loop
```

2. Install the plugin:
```bash
/plugin install ralph-loop
```

3. Restart Claude Code

## Commands

| Command | Description |
|---------|-------------|
| `/ralph-loop:loop PROMPT` | Start a new Ralph loop session |
| `/ralph-loop:cancel` | Cancel active loop (session preserved) |
| `/ralph-loop:sessions` | List all past sessions |
| `/ralph-loop:resume <id>` | Resume a previous session |
| `/ralph-loop:guardrail` | Manage global guardrails |
| `/ralph-loop:help` | Show help |

## Features

### Session Persistence
Each Ralph loop creates a session in `.ralph/sessions/`. Sessions are preserved even after cancellation, allowing you to resume later.

### Global Guardrails
Guardrails are lessons learned from past failures. They persist across ALL sessions, helping Claude avoid repeating mistakes.

```bash
# Add a guardrail
/ralph-loop:guardrail add "Always run tests before claiming done"

# View guardrails
/ralph-loop:guardrail list
```

### Progress Tracking
Each iteration is logged to `progress.md`, providing a history of work done.

### Completion Promises
To signal task completion, output a promise tag:

```
<promise>YOUR_PROMISE_TEXT</promise>
```

Only output this when the statement is TRUE. Do not lie to escape the loop.

## Examples

```bash
# Basic loop with iteration limit
/ralph-loop:loop "Build a REST API for todos" --max-iterations 20

# With completion promise
/ralph-loop:loop "Fix the auth bug" --completion-promise "TESTS PASSING"

# Resume a previous session
/ralph-loop:sessions
/ralph-loop:resume 2024-01-12_build-a-rest-api
```

## Project Structure

When running Ralph Loop, a `.ralph/` directory is created in your project:

```
.ralph/
├── sessions/
│   └── 2024-01-12_build-a-rest-api/
│       ├── state.md      # Loop state
│       ├── progress.md   # Iteration history
│       └── errors.log    # Failure records
├── guardrails.md         # Global guardrails
├── current -> sessions/...  # Active session symlink
└── activity.log          # Activity log
```

## Learn More

- Original technique: https://ghuntley.com/ralph/
- Cursor implementation: https://github.com/agrimsingh/ralph-wiggum-cursor

## License

MIT
