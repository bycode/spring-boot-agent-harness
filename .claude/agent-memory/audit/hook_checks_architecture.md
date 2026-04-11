---
name: Hook checks architecture
description: Structure of the PostToolUse hook system — dispatcher, check functions, shared libs, and fixture-based testing
type: project
---

The PostToolUse hook system at `scripts/harness/` follows a dispatcher pattern:

- `post-tool-hook` is a thin shell dispatcher that parses the tool JSON once, exports contract vars (`TOOL`, `FILE`, `CMD`, `INPUT`, `REPO_ROOT`), then iterates `CHECKS=(...)` calling each check function and merging their output into a single `additionalContext` string.
- `lib/hook-checks.sh` contains every check function (`check_*`) plus private helpers (`_check_*_helper`). Each check returns 0 and prints a `VIOLATION:` line on detection, empty otherwise.
- `lib/module-contract.sh` is a separate sourced library with pure helpers (no check functions) for parsing module contract markdown and Java package-info files. It is re-sourced transitively through `hook-checks.sh`.
- `test-hooks` is a fixture runner that walks `tests/hooks/*` directories. Each fixture has `case.json` (tool input), optional `content` (single edited file), optional `files/` (multi-file seed tree), optional `before` (git HEAD seed), optional `plans/`, and a required `expect.txt` using `+substring`/`-substring`/`EMPTY` assertions.
- `tests/module-contract-lib-test` is a standalone unit test runner for library helpers — invoked at the top of `test-hooks` for fail-fast.

Fixture naming convention: `positive-<scenario>` (expect violation), `content-negative-*` (expect clean), `benign-near-miss-*` (near-miss scenarios expected clean), `wrong-path-*` (out-of-scope paths expected clean).

**Why:** Understanding this layout lets future audits quickly locate where a specific check lives and which fixtures cover it without re-reading the whole harness.

**How to apply:** When auditing hook-related changes, use function name grep (`check_*` or `_check_*_helper`) in `lib/hook-checks.sh`, and check fixture completeness by listing `tests/hooks/<check_name>/` for all 4 categories (positive/negative/benign/wrong-path).
