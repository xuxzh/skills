# xuxzh/skills

[![skills.sh](https://skills.sh/b/xuxzh/skills)](https://skills.sh/xuxzh/skills)

Personal [Agent Skills](https://skills.sh/) collection.

## Included skills

### `creating-worktrees`

Creates a new Git worktree and branch using the `<keyword>-<description>` naming convention. It validates branch names, keeps worktrees under `.worktrees/`, optionally copies paths listed in `.worktreeinclude`, and includes an optional Claude Code `PreToolUse` hook.

### `kill-port-process`

Force-kills whatever process is listening on a given TCP port — the two-command recovery from `EADDRINUSE`. Looks up PIDs via `lsof -ti:<port>` (with an `ss` fallback on minimal Linux), confirms before privileged actions, and verifies the port is free afterwards. macOS and Linux only.

## Install

Install a single skill interactively:

```bash
npx skills add xuxzh/skills --skill creating-worktrees
npx skills add xuxzh/skills --skill kill-port-process
```

Install a skill globally for a specific agent:

```bash
# Pi
npx skills add xuxzh/skills --skill creating-worktrees -g -a pi -y
npx skills add xuxzh/skills --skill kill-port-process   -g -a pi -y

# Claude Code
npx skills add xuxzh/skills --skill creating-worktrees -g -a claude-code -y
npx skills add xuxzh/skills --skill kill-port-process   -g -a claude-code -y
```

After installation, ask your agent:

- `Create a worktree for feat-user-auth.` — uses `creating-worktrees`.
- `Free port 5183 — something is in the way.` — uses `kill-port-process`.

See [`skills/creating-worktrees/SKILL.md`](skills/creating-worktrees/SKILL.md) and [`skills/kill-port-process/SKILL.md`](skills/kill-port-process/SKILL.md) for full behavior. The optional Claude Code `PreToolUse` hook for `creating-worktrees` is documented in [`skills/creating-worktrees/references/install-hook.md`](skills/creating-worktrees/references/install-hook.md).

## Development

Run the `creating-worktrees` smoke test without creating a worktree:

```bash
bash skills/creating-worktrees/scripts/smoke-test.sh
```

Validate the repository using GitHub CLI:

```bash
gh skill publish --dry-run
```

## Repository layout

Each directory under `skills/` is an independently installable skill:

```text
skills/
└── <skill-name>/
    └── SKILL.md
```

## License

MIT
