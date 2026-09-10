# Installing the worktree-creation hook (per-project, opt-in)

This hook enforces the `<keyword>-<description>` naming convention by intercepting any `git worktree add` invocation in Claude Code and routing it through `create-worktree.sh`. It is **per-project** and **opt-in**: you add it once per project that wants enforcement.

The examples assume a global Claude Code installation at `${HOME}/.claude/skills/creating-worktrees`. For a project-local installation, replace that prefix with `.claude/skills/creating-worktrees`.

## Why per-project opt-in?

The skill is installed globally or per project, while hook registration lives in each project's `.claude/settings.json`, which is committed to that project. Adding the hook is a small but visible project change — so we let each project maintainer decide whether to enforce it.

If you don't add the hook, the skill still works fine (Claude reads `SKILL.md` and invokes the bundled script). The hook is just an extra layer that prevents agents from bypassing the skill by running raw `git worktree add`.

## Installation steps

### 1. Verify the scripts are executable

```bash
chmod +x ${HOME}/.claude/skills/creating-worktrees/scripts/*.sh
```

### 2. Edit the project's `.claude/settings.json`

Add (or merge into) a `hooks.PreToolUse` block:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${HOME}/.claude/skills/creating-worktrees/scripts/rewrite-worktree-add.sh"
          }
        ]
      }
    ]
  }
}
```

If the file already has a `hooks.PreToolUse` array, **merge** your entry into the existing array — don't overwrite it. Other hooks may be present.

### 3. Test in a Claude Code session inside the project

Ask Claude:

> "Create a worktree for `feat-hook-test`."

The agent should invoke the skill directly (via `SKILL.md` description matching). Verify the worktree exists:

```bash
git worktree list
ls .worktrees/feat-hook-test/
```

### 4. Verify the hook rewrites raw invocations

Ask Claude:

> "Run `git worktree add .worktrees/feat-hook-test-2 -b feat-hook-test-2`."

Even though the agent issues a raw `git worktree add`, the hook should rewrite it transparently to `create-worktree.sh feat-hook-test-2`. The worktree should appear in `git worktree list`.

### 5. Verify the hook denies unsafe forms

Ask Claude:

> "Run `git worktree add .worktrees/x && pwd`."

The hook should deny the command and emit a `permissionDecisionReason` explaining how to rewrite the command safely.

## Hook behavior reference

| Invocation | Hook action |
|---|---|
| `git worktree add .worktrees/feat-foo -b feat-foo` | Rewrite → `create-worktree.sh feat-foo` |
| `git worktree add -b feat-foo .worktrees/feat-foo` | Rewrite → `create-worktree.sh feat-foo` |
| `git worktree add .worktrees/feat-foo` (attach existing) | Allow as-is (no `-b`) |
| `git worktree add .worktrees/feat-foo <existing-branch>` | Allow as-is |
| `git worktree add .worktrees/foo --detach` | Allow as-is |
| `git worktree add .worktrees/foo -b feat-foo && pwd` | Deny (compound command) |
| `git -C /tmp/foo worktree add ...` | Deny (`git -C` form) |
| `git worktree list` / `remove` / `prune` | Allow as-is (hook only matches `add`) |
| Anything else | Allow as-is |

## Removing the hook

Delete the `hooks.PreToolUse` entry from the project's `.claude/settings.json` and commit. No other cleanup is needed — the installed skill remains available for direct invocation.

## Troubleshooting

**Hook doesn't fire.** Check that `${HOME}/.claude/skills/creating-worktrees/scripts/rewrite-worktree-add.sh` exists and is executable. The hook fails silently if it can't find itself.

**`jq` missing.** The hook prefers `jq` to parse the Claude Code payload. If `jq` is not installed, it falls back to a regex parse. Install with `brew install jq` (macOS) or `apt install jq` (Linux).

**Hook fires but rewrite doesn't apply.** Claude Code's `updatedInput` mechanism requires the hook to emit the exact JSON structure shown in the script. Run the hook manually with a sample payload to verify:

```bash
echo '{"tool_input":{"command":"git worktree add .worktrees/foo -b foo"}}' \
  | bash ${HOME}/.claude/skills/creating-worktrees/scripts/rewrite-worktree-add.sh
```

You should see JSON output with `"updatedInput"` containing the rewritten command.
