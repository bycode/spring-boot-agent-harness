#!/usr/bin/env bash
# Wrong-path: FILE points at a non-pom file. The path guard must short-
# circuit before the diff query runs, and output must be empty.
set -euo pipefail

. "$REPO_ROOT_REAL/scripts/harness/lib/hook-checks.sh"

export TOOL=Edit
export FILE="$PWD/foo.java"
export REPO_ROOT="$PWD"

output=$(check_jacoco_config_guard)

[[ -z "$output" ]] \
  || { echo "FAIL: expected empty output for non-pom path, got: $output"; exit 1; }
