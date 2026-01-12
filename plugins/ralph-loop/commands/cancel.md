---
description: "Cancel active Ralph Loop"
allowed-tools: ["Bash(test -f .ralph/current:*)", "Bash(rm .ralph/current)", "Read(.ralph/current/state.md)"]
hide-from-slash-command-tool: "true"
---

# Cancel Ralph

To cancel the active Ralph loop:

1. Check if `.ralph/current` exists using Bash: `test -L .ralph/current && echo "EXISTS" || echo "NOT_FOUND"`

2. **If NOT_FOUND**: Say "No active Ralph loop found."

3. **If EXISTS**:
   - Read `.ralph/current/state.md` to get the current iteration and session_id
   - Remove the symlink: `rm .ralph/current`
   - The session is preserved in `.ralph/sessions/` for later resumption
   - Report: "Cancelled Ralph loop (session: SESSION_ID, iteration: N). Session preserved - use /ralph-loop:resume SESSION_ID to continue."
