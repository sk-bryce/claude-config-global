#!/usr/bin/env bash
#
# read-only-plan-guard.sh - PreToolUse hook logic backing write-plan's "do not write the plan
# artifact during Plan Mode" rule (decisions/0002-plan-and-execute-framework.md, specs/behaviors.md
# Plan and Execute section).
#
# Per decisions/0003-hooks-and-scripts-authoring-policy.md, this file (hook logic) may be
# model-generated and is reviewed in full before commit; the registration that activates it (a
# `hooks` entry in write-plan/SKILL.md's frontmatter) is a separate, human step - see that
# SKILL.md's body for the exact snippet to add. This script does nothing until a human wires it in.
#
# Why this exists even though native Plan Mode already blocks writes: Claude Code's own
# permission-mode enforcement can degrade to advisory after an ExitPlanMode rejection (the model
# stays in the planning mindset, but the active mode may no longer read "plan" by the time it
# tries to write). A PreToolUse "deny" is evaluated before any permission-mode check and cannot be
# bypassed by a mode change or --dangerously-skip-permissions, so this is a hard backstop, not a
# duplicate of native enforcement.
#
# Usage: register as a PreToolUse hook matching Write|Edit|MultiEdit. Reads the hook's JSON
# payload from stdin (do not call this with a bare file-path argument like the PostToolUse
# scripts in this directory - the shape is different because PreToolUse must emit a structured
# allow/deny decision, not just act on a path).
#
# Behavior: denies Write, Edit, and MultiEdit while permission_mode is "plan". Every other mode
# and every other tool falls through silently (exit 0, no output), so a caller can pipe this
# script's stdout straight back to Claude Code without post-processing.

set -euo pipefail

payload="$(cat)"

mode="$(printf '%s' "$payload" | jq -r '.permission_mode // "default"' 2>/dev/null || echo default)"
tool="$(printf '%s' "$payload" | jq -r '.tool_name // ""' 2>/dev/null || echo "")"

if [[ "$mode" == "plan" ]]; then
  case "$tool" in
    Write|Edit|MultiEdit)
      jq -n '{
        hookSpecificOutput: {
          hookEventName: "PreToolUse",
          permissionDecision: "deny",
          permissionDecisionReason: "write-plan read-only guard: writes are blocked while permission_mode is \"plan\". Finish drafting, exit Plan Mode, then let write-plan write the plan artifact."
        }
      }'
      exit 0
      ;;
  esac
fi

exit 0
