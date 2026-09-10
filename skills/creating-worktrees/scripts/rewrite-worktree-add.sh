#!/usr/bin/env bash
# rewrite-worktree-add.sh — Claude Code PreToolUse hook that intercepts
# `git worktree add ...` invocations and routes them through
# create-worktree.sh, enforcing the <keyword>-<description> naming
# convention and .worktreeinclude copy step.
#
# Install per-project: add to .claude/settings.json. For a global Claude Code
# installation, use ${HOME}/.claude/skills/creating-worktrees/scripts/rewrite-worktree-add.sh.
# For a project-local installation, use .claude/skills/creating-worktrees/scripts/...
#
# See references/install-hook.md for full instructions.

set -euo pipefail

# --- Read hook payload from stdin ---
input="$(cat)" || exit 0

# --- Extract the command string ---
# Prefer jq; fall back to grep+sed if jq is missing.
if command -v jq >/dev/null 2>&1; then
  cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // ""' 2>/dev/null || true)"
else
  cmd="$(printf '%s' "$input" \
    | grep -oE '"command"[[:space:]]*:[[:space:]]*"[^"]*"' \
    | head -1 \
    | sed -E 's/.*"command"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/' \
    || true)"
fi

# Nothing to inspect → silent passthrough.
[ -z "$cmd" ] && exit 0

# --- Normalize: strip leading whitespace and `rtk ` proxy tokens ---
norm="$(printf '%s' "$cmd" | sed -E 's/^[[:space:]]*((rtk[[:space:]]+)*)//')"

# --- Bail early if this command isn't a `git ... worktree add` invocation ---
# Pattern: `git` ... `worktree add`, allowing `git -C <dir>` between them.
if ! printf '%s' "$norm" | grep -qE '(^|[[:space:]])git([[:space:]]+worktree|[[:space:]]+-C[[:space:]]+[^[:space:]]+[[:space:]]+worktree)[[:space:]]+add([[:space:]]|$)'; then
  exit 0
fi

# --- Deny unsafe forms (compound commands, git -C, subshells, redirects) ---
if printf '%s' "$norm" | grep -qE '(\$\(|`|\&\&|\|\||;|\|[^|]|[<>]|(^|[[:space:]])git[[:space:]]+-C[[:space:]])'; then
  reason='Detected `git worktree add` in an unsafe form (compound command like `&&` or `;`, `git -C <dir>`, or subshell `$(...)` / backticks). Rewrite as a plain `git worktree add .worktrees/<keyword>-<slug> -b <keyword>-<slug>` so this hook can route it through create-worktree.sh. Attach-existing and --detach forms (no `-b`) are allowed as-is.'
  if command -v jq >/dev/null 2>&1; then
    escaped="$(printf '%s' "$reason" | jq -Rsa .)"
  else
    escaped="\"$(printf '%s' "$reason" | sed 's/"/\\"/g')\""
  fi
  cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": $escaped
  }
}
EOF
  exit 0
fi

# --- Now handle the rewrite path: only the plain `git worktree add ...` form ---
case "$norm" in
  "git worktree add "*)
    rest="${norm#git worktree add }"
    ;;
  *)
    # `git worktree add` detected but in some odd form we can't safely rewrite.
    # Allow passthrough so git handles it (and surfaces its own error if any).
    exit 0
    ;;
esac

# --- Look for `-b <slug>` to determine branch name ---
slug=""
# Pattern A: `git worktree add <path> -b <branch> ...`
# Pattern B: `git worktree add -b <branch> <path>`
# Both reduce to: "first -b token after `git worktree add`"
slug="$(printf '%s' "$rest" | sed -nE 's/.*-b[[:space:]]+([^[:space:]]+).*/\1/p' || true)"

# --- If no -b found (attach existing or detach), allow passthrough ---
if [ -z "$slug" ]; then
  exit 0
fi

# --- Rewrite to call create-worktree.sh ---
skill_dir="$(cd "$(dirname "$0")/.." && pwd -P)"
new_cmd="bash '$skill_dir/scripts/create-worktree.sh' '$slug'"

# JSON-escape the inner command (escape backslashes and double quotes).
escaped_cmd="$(printf '%s' "$new_cmd" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')"

cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "updatedInput": {
      "command": "$escaped_cmd"
    }
  }
}
EOF
