#!/usr/bin/env bash
# Pre-existing custom pre-commit: a user's hook already sits at
# .git/hooks/pre-commit. The installer must preserve the existing content
# verbatim and append the guard block exactly once.
set -euo pipefail

git init -q

mkdir -p .git/hooks
cat > .git/hooks/pre-commit <<'HOOK'
#!/usr/bin/env bash
# CUSTOM_USER_HOOK — user-owned pre-commit logic from before the harness.
echo "running the user's custom pre-commit"
HOOK
chmod +x .git/hooks/pre-commit

HOOK_TARGET_ROOT="$PWD" "$REPO_ROOT_REAL/scripts/harness/install-git-hooks" >/dev/null

hook_file="$PWD/.git/hooks/pre-commit"

grep -qF "CUSTOM_USER_HOOK" "$hook_file" \
  || { echo "FAIL: custom user hook content was destroyed"; exit 1; }

marker_count=$(grep -cF "HARNESS:migration-edit-guard" "$hook_file")
[[ "$marker_count" -eq 1 ]] \
  || { echo "FAIL: marker appears $marker_count times (expected 1)"; exit 1; }

# Second install for good measure — still must appear exactly once.
HOOK_TARGET_ROOT="$PWD" "$REPO_ROOT_REAL/scripts/harness/install-git-hooks" >/dev/null
marker_count=$(grep -cF "HARNESS:migration-edit-guard" "$hook_file")
[[ "$marker_count" -eq 1 ]] \
  || { echo "FAIL: after re-run, marker appears $marker_count times (expected 1)"; exit 1; }
grep -qF "CUSTOM_USER_HOOK" "$hook_file" \
  || { echo "FAIL: after re-run, custom user hook content was destroyed"; exit 1; }
