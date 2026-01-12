---
description: "Show Ralph Loop help"
---

# Ralph Loop Plugin Help

Ralph Loop implements iterative development with session persistence and guardrails.

## Concept

```bash
while :; do
  cat PROMPT.md | claude --continue
done
```

The same prompt is fed to Claude repeatedly. Claude sees its previous work in files and git history, allowing iterative improvement until completion.

## Commands

| Command | Description |
|---------|-------------|
| `/ralph-loop:loop PROMPT` | Start a new Ralph loop session |
| `/ralph-loop:cancel` | Cancel active loop (session preserved) |
| `/ralph-loop:sessions` | List all past sessions |
| `/ralph-loop:resume <id>` | Resume a previous session |
| `/ralph-loop:guardrail` | Manage global guardrails |

## Examples

```bash
# Basic loop with iteration limit
/ralph-loop:loop Build a REST API --max-iterations 20

# With completion promise
/ralph-loop:loop "Fix auth bug" --completion-promise "TESTS PASSING"

# Add a guardrail
/ralph-loop:guardrail add "Always run tests before claiming done"

# List sessions
/ralph-loop:sessions

# Resume a session
/ralph-loop:resume 2024-01-12_build-a-rest-api
```

## Features

- **Session persistence**: Sessions saved in `.ralph/sessions/`
- **Global guardrails**: Lessons persist across all sessions
- **Progress tracking**: Each iteration logged to `progress.md`
- **Failure detection**: Stuck patterns trigger guardrail suggestions

## Completion

To complete a loop with a promise, output:
```
<promise>YOUR_PROMISE_TEXT</promise>
```

ONLY output this when the statement is TRUE. Do not lie to escape.

## Learn More

- Original: https://ghuntley.com/ralph/
