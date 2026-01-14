#!/bin/bash

# Ralph Loop Plugin Test Suite
# Tests all scripts and functionality

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
PASSED=0
FAILED=0

# Get the script directory and plugin root
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PLUGIN_ROOT="$PROJECT_ROOT/plugins/ralph-loop"

# Test working directory (isolated)
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

cd "$TEST_DIR"

# Helper functions
log_pass() {
  echo -e "${GREEN}✓ PASS${NC}: $1"
  ((PASSED++))
}

log_fail() {
  echo -e "${RED}✗ FAIL${NC}: $1"
  ((FAILED++))
}

log_info() {
  echo -e "${YELLOW}→${NC} $1"
}

assert_file_exists() {
  if [[ -f "$1" ]]; then
    log_pass "File exists: $1"
    return 0
  else
    log_fail "File does not exist: $1"
    return 1
  fi
}

assert_dir_exists() {
  if [[ -d "$1" ]]; then
    log_pass "Directory exists: $1"
    return 0
  else
    log_fail "Directory does not exist: $1"
    return 1
  fi
}

assert_symlink_exists() {
  if [[ -L "$1" ]]; then
    log_pass "Symlink exists: $1"
    return 0
  else
    log_fail "Symlink does not exist: $1"
    return 1
  fi
}

assert_contains() {
  if grep -q "$2" "$1" 2>/dev/null; then
    log_pass "File '$1' contains '$2'"
    return 0
  else
    log_fail "File '$1' does not contain '$2'"
    return 1
  fi
}

assert_json_valid() {
  if echo "$1" | jq . > /dev/null 2>&1; then
    log_pass "Valid JSON output"
    return 0
  else
    log_fail "Invalid JSON output: $1"
    return 1
  fi
}

assert_json_field() {
  local json="$1"
  local field="$2"
  local expected="$3"
  local actual

  actual=$(echo "$json" | jq -r ".$field" 2>/dev/null || echo "")

  if [[ "$actual" == "$expected" ]]; then
    log_pass "JSON field '$field' = '$expected'"
    return 0
  else
    log_fail "JSON field '$field' expected '$expected', got '$actual'"
    return 1
  fi
}

# ============================================
# Test 1: Setup Script
# ============================================
echo ""
echo "=========================================="
echo "Test 1: Setup Script (setup-ralph-loop.sh)"
echo "=========================================="

log_info "Testing basic session creation..."

export RALPH_ARGS='"Test prompt for unit testing" --max-iterations 5 --completion-promise "DONE"'
"$PLUGIN_ROOT/scripts/setup-ralph-loop.sh" > /dev/null 2>&1 || true

assert_dir_exists ".ralph"
assert_dir_exists ".ralph/sessions"
assert_file_exists ".ralph/guardrails.md"
assert_file_exists ".ralph/activity.log"
assert_symlink_exists ".ralph/current"

# Check session was created
SESSION_DIR=$(find .ralph/sessions -mindepth 1 -maxdepth 1 -type d | head -1)
if [[ -n "$SESSION_DIR" ]]; then
  log_pass "Session directory created: $SESSION_DIR"

  assert_file_exists "$SESSION_DIR/state.md"
  assert_file_exists "$SESSION_DIR/progress.md"
  assert_file_exists "$SESSION_DIR/errors.log"

  # Check state file content
  assert_contains "$SESSION_DIR/state.md" "active: true"
  assert_contains "$SESSION_DIR/state.md" "iteration: 1"
  assert_contains "$SESSION_DIR/state.md" "max_iterations: 5"
  assert_contains "$SESSION_DIR/state.md" "completion_promise: \"DONE\""
  assert_contains "$SESSION_DIR/state.md" "Test prompt for unit testing"
else
  log_fail "No session directory was created"
fi

# ============================================
# Test 2: Stop Hook JSON Output
# ============================================
echo ""
echo "=========================================="
echo "Test 2: Stop Hook JSON Output"
echo "=========================================="

log_info "Testing stop hook JSON output format..."

# Create a mock transcript file
TRANSCRIPT_FILE="$TEST_DIR/transcript.json"
cat > "$TRANSCRIPT_FILE" << 'EOF'
{"role":"user","message":{"content":[{"type":"text","text":"Start working"}]}}
{"role":"assistant","message":{"content":[{"type":"text","text":"I'll start working on the task now."}]}}
EOF

# Feed the transcript path to the stop hook
HOOK_INPUT='{"transcript_path":"'$TRANSCRIPT_FILE'"}'
HOOK_OUTPUT=$(echo "$HOOK_INPUT" | "$PLUGIN_ROOT/hooks/stop-hook.sh" 2>/dev/null || echo "")

if [[ -n "$HOOK_OUTPUT" ]]; then
  assert_json_valid "$HOOK_OUTPUT"
  assert_json_field "$HOOK_OUTPUT" "decision" "block"

  # Check that reason contains the expected parts
  REASON=$(echo "$HOOK_OUTPUT" | jq -r '.reason' 2>/dev/null || echo "")
  if [[ "$REASON" == *"Ralph iteration"* ]]; then
    log_pass "Reason contains iteration info"
  else
    log_fail "Reason missing iteration info"
  fi

  if [[ "$REASON" == *"TASK:"* ]]; then
    log_pass "Reason contains TASK section"
  else
    log_fail "Reason missing TASK section"
  fi

  # Verify NO systemMessage field (the bug we fixed)
  if echo "$HOOK_OUTPUT" | jq -e '.systemMessage' > /dev/null 2>&1; then
    log_fail "JSON contains invalid 'systemMessage' field (BUG!)"
  else
    log_pass "JSON does not contain invalid 'systemMessage' field"
  fi
else
  log_fail "Stop hook produced no output"
fi

# ============================================
# Test 3: Max Iterations Completion
# ============================================
echo ""
echo "=========================================="
echo "Test 3: Max Iterations Completion"
echo "=========================================="

log_info "Testing max iterations completion..."

# Update state to be at max iterations
STATE_FILE="$SESSION_DIR/state.md"
sed -i.bak "s/^iteration: 1/iteration: 5/" "$STATE_FILE"
rm -f "$STATE_FILE.bak"

# Run stop hook - should complete
HOOK_OUTPUT=$(echo "$HOOK_INPUT" | "$PLUGIN_ROOT/hooks/stop-hook.sh" 2>&1 || echo "")

# Check if it completed (should not output JSON, should exit 0)
if [[ "$HOOK_OUTPUT" == *"Max iterations"* ]]; then
  log_pass "Max iterations triggered completion message"
else
  # Check if symlink was removed (indicates completion)
  if [[ ! -L ".ralph/current" ]]; then
    log_pass "Session completed and symlink removed"
  else
    log_fail "Session should have completed at max iterations"
  fi
fi

# Check state file was updated
if grep -q "active: false" "$STATE_FILE"; then
  log_pass "State file marked as inactive after completion"
else
  log_fail "State file should be marked inactive after completion"
fi

# ============================================
# Test 4: Guardrails Management
# ============================================
echo ""
echo "=========================================="
echo "Test 4: Guardrails Management"
echo "=========================================="

log_info "Testing guardrails script..."

# Test list command
export RALPH_ARGS="list"
OUTPUT=$("$PLUGIN_ROOT/scripts/manage-guardrails.sh" 2>&1 || echo "")
if [[ "$OUTPUT" == *"Global Guardrails"* ]]; then
  log_pass "Guardrails list command works"
else
  log_fail "Guardrails list command failed"
fi

# Test add command
export RALPH_ARGS='add "Always test before committing"'
OUTPUT=$("$PLUGIN_ROOT/scripts/manage-guardrails.sh" 2>&1 || echo "")
if [[ "$OUTPUT" == *"Added guardrail"* ]]; then
  log_pass "Guardrails add command works"

  # Verify it was added
  if grep -q "Always test before committing" ".ralph/guardrails.md"; then
    log_pass "New guardrail appears in file"
  else
    log_fail "New guardrail not found in file"
  fi
else
  log_fail "Guardrails add command failed"
fi

# Test clear command
export RALPH_ARGS="clear"
OUTPUT=$("$PLUGIN_ROOT/scripts/manage-guardrails.sh" 2>&1 || echo "")
if [[ "$OUTPUT" == *"reset to defaults"* ]]; then
  log_pass "Guardrails clear command works"
else
  log_fail "Guardrails clear command failed"
fi

# ============================================
# Test 5: List Sessions
# ============================================
echo ""
echo "=========================================="
echo "Test 5: List Sessions"
echo "=========================================="

log_info "Testing list sessions script..."

OUTPUT=$("$PLUGIN_ROOT/scripts/list-sessions.sh" 2>&1 || echo "")
if [[ "$OUTPUT" == *"Ralph Sessions"* ]] || [[ "$OUTPUT" == *"Session ID"* ]]; then
  log_pass "List sessions command works"
else
  log_fail "List sessions command failed"
fi

# ============================================
# Test 6: Resume Session
# ============================================
echo ""
echo "=========================================="
echo "Test 6: Resume Session"
echo "=========================================="

log_info "Testing resume session script..."

# Get the session ID
SESSION_ID=$(basename "$SESSION_DIR")

# First, the session was completed, so we need to verify resume works
export RALPH_ARGS="$SESSION_ID"
OUTPUT=$("$PLUGIN_ROOT/scripts/resume-session.sh" 2>&1 || echo "")

if [[ "$OUTPUT" == *"Resumed Ralph session"* ]] || [[ "$OUTPUT" == *"$SESSION_ID"* ]]; then
  log_pass "Resume session command works"

  # Check symlink was restored
  if [[ -L ".ralph/current" ]]; then
    log_pass "Symlink restored after resume"
  else
    log_fail "Symlink not restored after resume"
  fi
else
  log_fail "Resume session command failed"
fi

# Test invalid session
export RALPH_ARGS="nonexistent-session-id"
OUTPUT=$("$PLUGIN_ROOT/scripts/resume-session.sh" 2>&1 || echo "")
if [[ "$OUTPUT" == *"not found"* ]] || [[ "$OUTPUT" == *"Error"* ]]; then
  log_pass "Resume correctly handles invalid session"
else
  log_fail "Resume should fail for invalid session"
fi

# ============================================
# Test 7: Promise Detection
# ============================================
echo ""
echo "=========================================="
echo "Test 7: Promise Detection"
echo "=========================================="

log_info "Testing promise detection in stop hook..."

# Create a new session with promise
rm -rf .ralph
export RALPH_ARGS='"Promise test" --max-iterations 10 --completion-promise "TESTS PASSING"'
"$PLUGIN_ROOT/scripts/setup-ralph-loop.sh" > /dev/null 2>&1 || true

# Create transcript with matching promise
TRANSCRIPT_FILE="$TEST_DIR/transcript_promise.json"
cat > "$TRANSCRIPT_FILE" << 'EOF'
{"role":"user","message":{"content":[{"type":"text","text":"Continue working"}]}}
{"role":"assistant","message":{"content":[{"type":"text","text":"The work is done. <promise>TESTS PASSING</promise> All tests pass."}]}}
EOF

HOOK_INPUT='{"transcript_path":"'$TRANSCRIPT_FILE'"}'
HOOK_OUTPUT=$(echo "$HOOK_INPUT" | "$PLUGIN_ROOT/hooks/stop-hook.sh" 2>&1 || echo "")

if [[ "$HOOK_OUTPUT" == *"promise fulfilled"* ]] || [[ ! -L ".ralph/current" ]]; then
  log_pass "Promise detection completed session"
else
  log_fail "Promise detection did not complete session"
fi

# ============================================
# Test 8: Special Characters in Prompt
# ============================================
echo ""
echo "=========================================="
echo "Test 8: Special Characters in Prompt"
echo "=========================================="

log_info "Testing prompts with special characters..."

rm -rf .ralph
export RALPH_ARGS='"Fix the bug in \$PATH handling & test \"quotes\"" --max-iterations 3'
OUTPUT=$("$PLUGIN_ROOT/scripts/setup-ralph-loop.sh" 2>&1 || true)

if [[ "$OUTPUT" == *"Ralph loop activated"* ]]; then
  log_pass "Setup handles special characters in prompt"

  # Check prompt was preserved
  SESSION_DIR=$(find .ralph/sessions -mindepth 1 -maxdepth 1 -type d | head -1)
  if grep -q 'Fix the bug' "$SESSION_DIR/state.md"; then
    log_pass "Prompt preserved in state file"
  else
    log_fail "Prompt not found in state file"
  fi
else
  log_fail "Setup failed with special characters"
fi

# ============================================
# Summary
# ============================================
echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"
echo ""

if [[ $FAILED -eq 0 ]]; then
  echo -e "${GREEN}All tests passed!${NC}"
  exit 0
else
  echo -e "${RED}Some tests failed.${NC}"
  exit 1
fi
