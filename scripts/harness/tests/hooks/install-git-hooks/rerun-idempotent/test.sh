#!/usr/bin/env bash
# Rerun-idempotent: run the installer twice. After the second run the hook
# file must be byte-identical to after the first run, and the marker must
# appear exactly once.
set -euo pipefail

git init -q

HOOK_TARGET_ROOT="$PWD" "$REPO_ROOT_REAL/scripts/harness/install-git-hooks" >/dev/null

hook_file="$PWD/.git/hooks/pre-commit"
first_snapshot="$PWD/.snap-first"
cp "$hook_file" "$first_snapshot"

# Second install — must not change the file.
HOOK_TARGET_ROOT="$PWD" "$REPO_ROOT_REAL/scripts/harness/install-git-hooks" >/dev/null

cmp -s "$first_snapshot" "$hook_file" \
  || { echo "FAIL: hook file changed across re-run (cmp differs)"; diff "$first_snapshot" "$hook_file" || true; exit 1; }

marker_count=$(grep -cF "HARNESS:migration-edit-guard" "$hook_file")
[[ "$marker_count" -eq 1 ]] \
  || { echo "FAIL: marker appears $marker_count times (expected 1)"; exit 1; }
