#!/usr/bin/env bash
# create-worktree.sh — Create a new git worktree + branch following the
# <keyword>-<description> naming convention. Auto-copies files declared
# in .worktreeinclude (project root) if present.
#
# Usage:
#   create-worktree.sh <slug>
#   create-worktree.sh --validate <slug>
#   create-worktree.sh --help
#   create-worktree.sh --version

set -euo pipefail

# --- Constants ---
KEYWORDS="feat fix opt docs refactor chore test"
SLUG_REGEX='^(feat|fix|opt|docs|refactor|chore|test)-[a-z][a-z0-9]{0,40}(-[a-z0-9]{1,40})*$'
SLUG_MIN_LEN=5
SLUG_MAX_LEN=50
INCLUDE_FILE=".worktreeinclude"
VERSION="1.0.0"

# --- Color helpers (only on TTY) ---
if [ -t 1 ]; then
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_RED=$'\033[31m'
  C_BOLD=$'\033[1m'
  C_RESET=$'\033[0m'
else
  C_GREEN=""; C_YELLOW=""; C_RED=""; C_BOLD=""; C_RESET=""
fi

info() { printf '%s\n' "$*"; }
ok()   { printf '%s%s✓%s %s\n' "$C_GREEN" "$C_BOLD" "$C_RESET" "$*"; }
warn() { printf '%s%s!%s  %s\n' "$C_YELLOW" "$C_BOLD" "$C_RESET" "$*" >&2; }
err()  { printf '%s%s✗%s %s\n' "$C_RED" "$C_BOLD" "$C_RESET" "$*" >&2; }
hr()   { printf '%s\n' "----------------------------------------"; }

usage() {
  cat >&2 <<EOF
create-worktree.sh v${VERSION} — creating-worktrees skill

Usage:
  $0 <slug>             Create a new worktree + branch
  $0 --validate <slug>  Validate slug format only (exit 0 if valid)
  $0 --help             Show this help
  $0 --version          Show version

Slug format:
  <keyword>-<description>
  keywords:    feat, fix, opt, docs, refactor, chore, test
  description: lowercase letters/digits joined by single '-'
  length:      ${SLUG_MIN_LEN}-${SLUG_MAX_LEN} characters

Examples:
  $0 feat-user-auth
  $0 fix-typo-in-login
  $0 refactor-chart-comp

Result:
  Worktree path: <main>/.worktrees/<slug>
  Branch:        <slug>
  Include copy:  if <main>/.worktreeinclude exists, copies listed files
EOF
}

# --- Slug validation ---
validate_slug() {
  local s="${1:-}"
  if [ -z "$s" ]; then
    err "slug is empty"
    return 1
  fi
  if ! [[ "$s" =~ $SLUG_REGEX ]]; then
    err "invalid slug: '$s'"
    err "  must match: <keyword>-<description>"
    err "  keywords:    feat, fix, opt, docs, refactor, chore, test"
    err "  description: lowercase letters/digits joined by single '-'"
    return 1
  fi
  local len=${#s}
  if [ "$len" -lt "$SLUG_MIN_LEN" ] || [ "$len" -gt "$SLUG_MAX_LEN" ]; then
    err "slug length $len out of range [$SLUG_MIN_LEN, $SLUG_MAX_LEN]"
    return 1
  fi
  return 0
}

# --- Mode dispatch ---
mode="${1:-}"
case "$mode" in
  --help|-h)
    usage
    exit 0
    ;;
  --version|-V)
    printf 'create-worktree.sh v%s\n' "$VERSION"
    exit 0
    ;;
  --validate)
    shift
    if validate_slug "${1:-}"; then
      ok "slug '${1}' is valid"
      exit 0
    else
      exit 1
    fi
    ;;
  "")
    err "missing slug argument"
    usage
    exit 1
    ;;
  -*)
    err "unknown flag: $mode"
    usage
    exit 1
    ;;
esac

# At this point, $mode is the slug.
slug="$mode"
if ! validate_slug "$slug"; then
  exit 1
fi

# --- Resolve main worktree root ---
# Priority: git worktree list (always gives main) > toplevel (fallback).
repo_root="$(git worktree list --porcelain 2>/dev/null | awk '/^worktree / {print $2; exit}')"
if [ -z "$repo_root" ]; then
  repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
fi
if [ -z "$repo_root" ]; then
  err "not inside a git working tree"
  exit 128
fi

# --- Idempotency check ---
target="$repo_root/.worktrees/$slug"
branch="$slug"

if [ -e "$target" ]; then
  err "worktree path already exists: $target"
  err "  remove it first with: git worktree remove $target"
  exit 1
fi
if git -C "$repo_root" show-ref --verify --quiet "refs/heads/$branch"; then
  err "branch '$branch' already exists"
  err "  remove it first with: git branch -D $branch"
  exit 1
fi

# --- Ensure parent dir exists + check gitignore ---
parent_dir="$(dirname "$target")"
if [ ! -d "$parent_dir" ]; then
  if ! git -C "$repo_root" check-ignore -q "$parent_dir" 2>/dev/null; then
    warn "$parent_dir is not in .gitignore"
    warn "  recommend: echo '.worktrees/' >> .gitignore && commit"
  fi
  mkdir -p "$parent_dir"
fi

# --- Create worktree + branch ---
info "Creating worktree at $target"
info "  branch: $branch (from HEAD)"
hr
if ! git -C "$repo_root" worktree add "$target" -b "$branch" HEAD; then
  err "git worktree add failed"
  exit 1
fi
ok "worktree ready at $target"

# --- Auto-copy from .worktreeinclude (opt-in) ---
include_file="$repo_root/$INCLUDE_FILE"
copied=0
skipped=0
missing_include=0

echo
if [ ! -f "$include_file" ]; then
  missing_include=1
else
  info "Reading $INCLUDE_FILE ..."
  while IFS= read -r line || [ -n "$line" ]; do
    # Trim leading/trailing whitespace.
    f="${line#"${line%%[![:space:]]*}"}"
    f="${f%"${f##*[![:space:]]}"}"
    # Skip blank lines and comments.
    [ -z "$f" ] && continue
    case "$f" in
      \#*) continue ;;
    esac

    src="$repo_root/$f"
    dst="$target/$f"

    if [ ! -e "$src" ]; then
      warn "skip '$f' (source missing in main worktree)"
      skipped=$((skipped + 1))
      continue
    fi

    mkdir -p "$(dirname "$dst")"
    if cp -RP "$src" "$dst" 2>/dev/null; then
      copied=$((copied + 1))
    else
      warn "copy failed for '$f'"
      skipped=$((skipped + 1))
    fi
  done < "$include_file"
fi

# --- Summary ---
echo
hr
ok "summary"
echo "    worktree: $target"
echo "    branch:   $branch"
if [ "$missing_include" -eq 1 ]; then
  warn "no $INCLUDE_FILE at repo root; nothing copied"
  warn "  create one to auto-copy gitignored files (e.g. .env)"
else
  echo "    copied:   $copied file(s) from $INCLUDE_FILE"
  [ "$skipped" -gt 0 ] && echo "    skipped:  $skipped file(s)"
fi
echo
ok "next step:"
echo "    cd \"$target\""
