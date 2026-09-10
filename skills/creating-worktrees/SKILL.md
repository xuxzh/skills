---
name: creating-worktrees
description: 'Create a new git worktree + branch following the `<keyword>-<description>` naming convention (worktree path under `.worktrees/<slug>`). Use when the user wants to start isolated work — e.g. `/creating-worktrees fix the login bug` (slash-style with optional task), `/creating-worktrees 修复登录bug`, "建个 worktree 改登录页 bug", "start a feature in isolation", or any time you (the agent) are about to run `git worktree add`. If the user describes a task along with the invocation, auto-derive a slug from the task (e.g. "修复登录bug" → `fix-login-bug`), create the worktree, then continue with the task in the new worktree. Auto-copies files declared in `.worktreeinclude` (typically gitignored `.env`) into the new worktree. Not for: listing, removing, or attaching existing worktrees — those use raw `git worktree` commands.'
license: MIT
---

# Creating Worktrees

A self-contained skill that runs a bundled shell script to create a new git worktree + branch with strict naming validation and optional include-file copy.

## When to use

Trigger this skill when:

- **The user explicitly asks to create a worktree** for some isolated work, e.g.:
  - "create a worktree for X"
  - "开 worktree / 建个分支 / 切分支改 X"
  - "start a feature branch in isolation"
  - "我需要隔离环境修 bug / 改东西"
- **Slash-style invocation with optional task**: `/creating-worktrees 修复登录bug` or `/skill:creating-worktrees fix the login bug` — the agent should create the worktree and continue with the described task.
- **You (the agent) are about to run `git worktree add ...`** for any reason.

## Usage patterns

In the examples below, `<skill-root>` means the directory containing this `SKILL.md`. Use the installed copy of the skill rather than assuming a particular agent's global installation path.

### Pattern 1: explicit slug

User: "Create a worktree for `feat-user-auth`"

Agent runs the bundled script from the installed skill directory:

`bash <skill-root>/scripts/create-worktree.sh feat-user-auth`

### Pattern 2: slash-style with task (no explicit slug)

User: `/creating-worktrees 修复登录页的 bug` (or `/skill:creating-worktrees 修复登录页的 bug`)

Agent should:
1. Derive a slug from the task description (see Slug derivation below).
2. Confirm the slug briefly with the user (one-liner: "I'll create `fix-login-bug` and fix the login bug. Proceed?").
3. Run `create-worktree.sh <slug>`.
4. `cd` into the new worktree.
5. Continue with the user's described task.

If the user skips the confirmation step ("don't ask, just do it"), skip step 2.

### Pattern 3: explicit slug + task

User: `/creating-worktrees fix-login-bug 修复登录页的 bug`

Agent uses the explicit `fix-login-bug` (skip derivation, skip confirmation), creates the worktree, continues with the task.

### Pattern 4: prose with embedded task

User: "建个 worktree，然后优化 cache ttl"

Agent derives `opt-cache-ttl`, runs the script, optimizes cache TTL in the new worktree.

### Slug derivation hints

When auto-deriving from a task description:

| Task signal | Keyword |
|---|---|
| 修 / fix / bug / 错误 | `fix-` |
| 加 / feature / add / 新增 | `feat-` |
| 改 / refactor / 重构 | `refactor-` |
| 优化 / optimize / 性能 | `opt-` |
| 文档 / docs / readme | `docs-` |
| 测试 / test | `test-` |
| 杂事 / chore / 依赖 | `chore-` |

Then translate the rest to English (lowercase, single-word entities preferred), join with `-`. Examples:

- "修复登录页的 bug" → `fix-login-bug`
- "加一个 csv 导出功能" → `feat-csv-export`
- "优化 cache ttl" → `opt-cache-ttl`
- "refactor the chart component" → `refactor-chart-component`
- "update the readme" → `docs-readme-update`

If you can't derive a reasonable slug, ask the user.

## When NOT to use

- **Listing worktrees** → `git worktree list`
- **Removing a worktree** → `git worktree remove <path>`
- **Attaching to an existing branch** → `git worktree add <path> <existing-branch>` (raw git; path must still be under `.worktrees/`)
- **Detached HEAD** → `git worktree add --detach <path>` (raw git)
- **"Should I isolate at all?"** → consult `using-git-worktrees` first; it covers isolation detection and native-tool preference

## Naming convention

Both the worktree directory and the branch share one name: `<keyword>-<description>`.

| Part | Rule |
|---|---|
| `<keyword>` | One of: `feat`, `fix`, `opt`, `docs`, `refactor`, `chore`, `test` |
| `<description>` | Lowercase letters and digits, joined by single `-` |
| Total length | 5–50 characters |

**Examples**

- ✅ `feat-user-auth`, `fix-typo-in-login`, `refactor-chart-comp`, `opt-cache-ttl-v2`
- ❌ `feat-Foo` (uppercase), `feat--bar` (double dash), `feature-baz` (wrong keyword), `feat-` (no description), `feat-1foo` (digit prefix)

The bundled script enforces this regex and refuses malformed slugs with a clear error.

## Auto-copied files (`.worktreeinclude`)

If the project root has a `.worktreeinclude` file, each line is a repo-relative path that's `cp`'d from the main worktree into the new one. Typical use: copying gitignored `.env` files.

```
# .worktreeinclude
apps/api/.env
apps/web/.env
apps/e2e/.env
```

If the file does not exist, the skill creates the worktree without any copy step and prints a one-line hint suggesting the file.

## How to use

Run the bundled script directly with the desired slug. The script handles slug validation, main-worktree resolution, git invocation, and include-file copying.

```bash
bash <skill-root>/scripts/create-worktree.sh feat-user-auth
```

The script:

1. Validates the slug against the naming regex.
2. Resolves the main worktree root via `git worktree list --porcelain`.
3. Refuses if the worktree path or branch already exists (with guidance on how to remove).
4. Ensures `.worktrees/` exists; warns if it isn't gitignored.
5. Runs `git worktree add <main>/.worktrees/<slug> -b <slug> HEAD`.
6. If `.worktreeinclude` exists at main root, copies each listed path to the new worktree (skipping missing sources with a warning).
7. Prints a summary and `cd` hint.

### Slug validation only

```bash
bash <skill-root>/scripts/create-worktree.sh --validate feat-user-auth
```

Exits 0 if valid, 1 if not. Useful in pre-flight scripts.

## Project opt-in: PreToolUse hook

To prevent agents from bypassing this skill by running raw `git worktree add`, Claude Code users can install the bundled hook in the project's `.claude/settings.json`. The example below assumes a global Claude Code installation; adjust the skill path if the skill was installed locally or for another agent:

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

The hook:

- Detects plain `git worktree add ...` invocations and rewrites them to call `create-worktree.sh` (transparently).
- Allows `git worktree add <path> <existing-branch>` (attach) and `--detach` (raw git is fine for these).
- Denies unsafe forms (compound commands, `git -C`, subshells) with guidance to use the plain form.

For step-by-step instructions and full rationale, see `references/install-hook.md`.

## Related skills

- `using-git-worktrees` — meta-skill for "should I create a worktree at all?" — covers isolation detection, native tool preference, and fallback to git. **Consult this first** to decide whether to invoke `creating-worktrees`.
- `git-commit`, `finishing-a-development-branch` — downstream skills for committing and merging once work in the new worktree is done.

## Bundled files

| Path | Purpose |
|---|---|
| `scripts/create-worktree.sh` | Main entry point — validate, create worktree, copy include files |
| `scripts/rewrite-worktree-add.sh` | Optional Claude Code PreToolUse hook |
| `scripts/smoke-test.sh` | Dry-run validation (no actual worktree creation) |
| `references/install-hook.md` | Step-by-step hook installation guide |
