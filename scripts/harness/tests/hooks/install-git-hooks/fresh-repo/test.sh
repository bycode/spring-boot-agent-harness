#!/usr/bin/env bash
# Fresh-repo: no .git/hooks/pre-commit exists. The installer must create
# the file, make it executable, and embed the marker string.
set -euo pipefail

git init -q

# Install, pointing at this temp repo via HOOK_TARGET_ROOT.
HOOK_TARGET_ROOT="$PWD" "$REPO_ROOT_REAL/scripts/harness/install-git-hooks" >/dev/null

hook_file="$PWD/.git/hooks/pre-commit"

[[ -f "$hook_file" ]] \
  || { echo "FAIL: pre-commit file was not created"; exit 1; }
[[ -x "$hook_file" ]] \
  || { echo "FAIL: pre-commit file is not executable"; exit 1; }
grep -qF "HARNESS:migration-edit-guard" "$hook_file" \
  || { echo "FAIL: marker not present in hook file"; exit 1; }
grep -qF "check_migration_edit_guard" "$hook_file" \
  || { echo "FAIL: guard invocation not present in hook file"; exit 1; }
