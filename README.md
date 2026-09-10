# xuxzh/skills

[![skills.sh](https://skills.sh/b/xuxzh/skills)](https://skills.sh/xuxzh/skills)

Personal [Agent Skills](https://skills.sh/) collection.

## Included skills

### `creating-worktrees`

Creates a new Git worktree and branch using the `<keyword>-<description>` naming convention. It validates branch names, keeps worktrees under `.worktrees/`, optionally copies paths listed in `.worktreeinclude`, and includes an optional Claude Code `PreToolUse` hook.

## Install

Install the skill interactively:

```bash
npx skills add xuxzh/skills --skill creating-worktrees
```

Install it globally for a specific agent:

```bash
# Pi
npx skills add xuxzh/skills --skill creating-worktrees -g -a pi -y

# Claude Code
npx skills add xuxzh/skills --skill creating-worktrees -g -a claude-code -y
```

After installation, ask your agent to create a worktree, for example:

```text
Create a worktree for feat-user-auth.
```

See [`skills/creating-worktrees/SKILL.md`](skills/creating-worktrees/SKILL.md) for the full behavior and [`references/install-hook.md`](skills/creating-worktrees/references/install-hook.md) for the optional Claude Code hook.

## Development

Run the skill's smoke test without creating a worktree:

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
