#!/usr/bin/env bash
# smoke-test.sh — Dry-run validation of create-worktree.sh.
# Tests --help, --version, --validate, and error cases.
# Does NOT create any actual worktree.
#
# Run: bash scripts/smoke-test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
CREATE="$SCRIPT_DIR/create-worktree.sh"

[ -x "$CREATE" ] || { printf 'error: %s is not executable\n' "$CREATE" >&2; exit 2; }

pass=0
fail=0
fails=()

ok() { printf '  \033[32m✓\033[0m %s\n' "$1"; pass=$((pass + 1)); }
ng() { printf '  \033[31m✗\033[0m %s\n' "$1"; fail=$((fail + 1)); fails+=("$1"); }

# Run with args; capture combined output and exit code.
run() {
  local out rc
  out="$("$CREATE" "$@" 2>&1)" && rc=$? || rc=$?
  RUN_OUT="$out"
  RUN_RC=$rc
}

echo "== create-worktree.sh smoke test =="

# --- [1] modes ---
echo
echo "[1] --help"
run --help
[ "$RUN_RC" -eq 0 ] && ok "--help exits 0" || ng "--help exits 0 (got $RUN_RC)"
printf '%s' "$RUN_OUT" | grep -q "feat, fix, opt, docs, refactor, chore, test" \
  && ok "--help lists all 7 keywords" || ng "--help missing keyword list"

echo
echo "[2] --version"
run --version
[ "$RUN_RC" -eq 0 ] && ok "--version exits 0" || ng "--version exits 0 (got $RUN_RC)"

# --- [3] missing / unknown arg ---
echo
echo "[3] missing slug"
run
[ "$RUN_RC" -eq 1 ] && ok "no args exits 1" || ng "no args exits 1 (got $RUN_RC)"

echo
echo "[4] unknown flag"
run --bogus-flag
[ "$RUN_RC" -eq 1 ] && ok "--bogus-flag exits 1" || ng "--bogus-flag exits 1 (got $RUN_RC)"

# --- [5] --validate accepts ---
echo
echo "[5] --validate accepts valid slugs (one per keyword, plus multi-segment)"
for slug in feat-a fix-b opt-c docs-d refactor-e chore-f test-g \
            feat-user-auth fix-typo-in-login refactor-chart-comp-v2 opt-cache-ttl-bump; do
  run --validate "$slug"
  [ "$RUN_RC" -eq 0 ] && ok "--validate $slug" || ng "--validate $slug (rc=$RUN_RC)"
done

# --- [6] --validate rejects ---
echo
echo "[6] --validate rejects invalid slugs"
for slug in "feat" "FEAT-foo" "feat--foo" "feat-Foo" "feature-foo" \
            "feat-1foo" "feat-" "-foo" "feat-foo-"; do
  run --validate "$slug"
  [ "$RUN_RC" -ne 0 ] && ok "rejected: $slug" || ng "should reject: $slug"
done

# --- [7] direct invocation rejects malformed slugs ---
echo
echo "[7] direct invocation rejects malformed slugs (without --validate)"
for slug in "feat" "FEAT-foo" "feature-foo" "feat-Foo" "feat--foo"; do
  run "$slug"
  [ "$RUN_RC" -ne 0 ] && ok "rejected: $slug" || ng "should reject: $slug"
done

# --- [8] length boundary ---
echo
echo "[8] length boundary"
# 5 chars (smallest valid: 'fix-a')
run --validate "fix-a"
[ "$RUN_RC" -eq 0 ] && ok "length 5 (fix-a) accepted" || ng "length 5 should be accepted"

# 50 chars: feat- + 41 a's + -bbb (5 + 41 + 4 = 50)
s50="feat-$(printf 'a%.0s' {1..41})-bbb"
if [ "${#s50}" -eq 50 ]; then
  run --validate "$s50"
  [ "$RUN_RC" -eq 0 ] && ok "length 50 accepted" || ng "length 50 should be accepted (rc=$RUN_RC)"
else
  ng "internal: 50-char test slug has length ${#s50}"
fi

# 51 chars: feat- + 41 a's + -bbbb (5 + 41 + 5 = 51)
s51="feat-$(printf 'a%.0s' {1..41})-bbbb"
if [ "${#s51}" -eq 51 ]; then
  run --validate "$s51"
  [ "$RUN_RC" -ne 0 ] && ok "length 51 rejected" || ng "length 51 should be rejected"
else
  ng "internal: 51-char test slug has length ${#s51}"
fi

# --- summary ---
echo
echo "== Summary =="
echo "  passed: $pass"
echo "  failed: $fail"
if [ "$fail" -gt 0 ]; then
  printf '  failures:\n'
  for m in "${fails[@]}"; do
    printf '    - %s\n' "$m"
  done
  exit 1
fi
