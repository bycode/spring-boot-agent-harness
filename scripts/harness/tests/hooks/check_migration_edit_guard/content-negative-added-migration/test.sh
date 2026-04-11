#!/usr/bin/env bash
# Content-negative: commit a baseline, then stage a *new* migration file (A
# row, not M). Guard must pass silently.
set -euo pipefail

. "$REPO_ROOT_REAL/scripts/harness/lib/hook-checks.sh"

git init -q
git config user.email test@example.com
git config user.name test

mkdir -p src/main/resources/db/migration
echo "-- initial" > src/main/resources/db/migration/V1__init.sql
git add .
git -c commit.gpgsign=false commit -qm "initial" >/dev/null

# Add a brand-new migration file and stage it.
echo "-- new migration" > src/main/resources/db/migration/V3__add_column.sql
git add src/main/resources/db/migration/V3__add_column.sql

# Invoke the guard: expect exit 0 and empty stderr.
stderr=$(check_migration_edit_guard "$PWD" 2>&1 >/dev/null) \
  || { echo "FAIL: guard rejected a new migration (should have passed): $stderr"; exit 1; }

[[ -z "$stderr" ]] \
  || { echo "FAIL: expected empty stderr for new migration, got: $stderr"; exit 1; }
