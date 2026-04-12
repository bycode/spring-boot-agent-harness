#!/usr/bin/env bash
# Content-negative: stage a modification to a non-migration file. Guard must
# pass silently — the path filter on the diff must exclude it.
set -euo pipefail

. "$REPO_ROOT_REAL/scripts/harness/lib/hook-checks.sh"

git init -q
git config user.email test@example.com
git config user.name test

echo "initial" > README.md
# Seed an unrelated migration so the path filter isn't vacuously empty.
mkdir -p src/main/resources/db/migration
echo "-- v1" > src/main/resources/db/migration/V1__init.sql
git add .
git -c commit.gpgsign=false commit -qm "initial" >/dev/null

# Modify README.md (not a migration) and stage it.
echo "more" >> README.md
git add README.md

stderr=$(check_migration_edit_guard "$PWD" 2>&1 >/dev/null) \
  || { echo "FAIL: guard rejected a non-migration edit (should have passed): $stderr"; exit 1; }

[[ -z "$stderr" ]] \
  || { echo "FAIL: expected empty stderr for non-migration edit, got: $stderr"; exit 1; }
