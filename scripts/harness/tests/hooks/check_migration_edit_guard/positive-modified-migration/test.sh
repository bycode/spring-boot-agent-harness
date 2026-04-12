#!/usr/bin/env bash
# Positive: commit a migration file, modify it, stage the change, then
# invoke the guard — expect non-zero exit and a stderr mention of the file.
set -euo pipefail

. "$REPO_ROOT_REAL/scripts/harness/lib/hook-checks.sh"

git init -q
git config user.email test@example.com
git config user.name test

mkdir -p src/main/resources/db/migration
echo "-- initial" > src/main/resources/db/migration/V2__create.sql
git add .
git -c commit.gpgsign=false commit -qm "initial" >/dev/null

echo "-- edited" >> src/main/resources/db/migration/V2__create.sql
git add src/main/resources/db/migration/V2__create.sql

# Invoke the guard. Capture stderr separately so we can assert on it.
if stderr=$(check_migration_edit_guard "$PWD" 2>&1 >/dev/null); then
  echo "FAIL: expected non-zero exit from guard on modified migration"
  exit 1
fi

[[ "$stderr" == *"V2__create.sql"* ]] \
  || { echo "FAIL: stderr did not mention V2__create.sql: $stderr"; exit 1; }
[[ "$stderr" == *"BLOCKED"* ]] \
  || { echo "FAIL: stderr did not contain BLOCKED: $stderr"; exit 1; }
