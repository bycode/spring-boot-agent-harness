---
status: completed
epic: EPIC-0001
---

# PLAN-0005: safety guard hooks

## Goal
Ship the destructive-action and secret-leak guards: a secret scrubber in `scripts/harness/run-cmd` that redacts credential patterns from all subprocess output before it reaches the agent, a blocking git pre-commit guard that prevents editing already-applied Flyway migrations, and a strong warning when `pom.xml` edits touch the JaCoCo plugin configuration.

## Non-goals
- Per-file regex hooks (PLAN-0003) and cross-file sync hooks (PLAN-0004) — must be shipped first (shared library lives there)
- Full secret scanning of the working tree / git history (gitleaks-style) — that's a separate concern with its own tool; this plan scopes the scrubber to subprocess output only, because that's where the Claude Code conversation context actually picks up text
- Enforcing `NOT_SUPPORTED` transaction propagation for external calls — requires call-graph analysis, out of scope
- Blocking edits to `pom.xml` sections other than the JaCoCo plugin — would be over-reach; other sections are legitimately edited often
- Replacing the existing `run-cmd` output-minimization logic — the scrubber is an additional filter stage, not a rewrite

## Approach
1. **Secret scrubber first (Block 1)** because it's the independent piece — a library function + `run-cmd` integration point. Verify it works in isolation before moving to the guards. The scrubber is intentionally positioned in `run-cmd`, not as a Claude hook, because `run-cmd` is the single path by which Maven/bash output reaches the agent. One filter there covers every future tool automatically.
2. **File-modification guards (Block 2)**: `check_migration_edit_guard()` is a blocking git pre-commit check; `check_jacoco_config_guard()` is a non-blocking PostToolUse warning. Different severity because a modified migration *cannot be safely rolled back* once committed, while a touched JaCoCo config is only a soft rule violation. Include an `install-git-hooks` script so the pre-commit guard can be set up reproducibly by new clones.
3. **Wiring + cross-epic audit (Block 3)**: this is the last plan in the epic, so the final audit is scoped across all three plans to verify the full enforcement matrix: every promoted rule clause has an `Enforcement:` pointer, every hook has a fixture test, no dead code remains.

## Steps
<!-- Tests ship with the code: each step that adds/modifies production code must include its tests. See exec-plans.md § "Tests live with the code". -->
<!-- For plans with >5 steps: use session blocks (### Block N — label / Context: ...). See exec-plans.md § "Session blocks". -->

### Block 1 — Secret scrubber
Context: PLAN-0003 and PLAN-0004 completed — shared library `scripts/harness/lib/hook-checks.sh`, dispatcher, fixture runner, and test format all exist. This block adds a *separate* library (`lib/scrub-secrets.sh`) used by `run-cmd`, not the hook dispatcher.
- [x] Step 1: Create `scripts/harness/lib/scrub-secrets.sh` — regex-based scrubber that reads stdin and writes stdout with credential patterns replaced by `[REDACTED:<pattern-name>]`. Pattern table: AWS access key (`AKIA[0-9A-Z]{16}`), GitHub token (`ghp_[A-Za-z0-9]{36}`, `gho_[A-Za-z0-9]+`, `ghu_`, `ghs_`, `ghr_`), JWT (`eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}`), Bearer header (`Authorization:\s*Bearer\s+\S+`), RSA/EC/OpenSSH private key delimiters, `AWS_SECRET_ACCESS_KEY=<value>` env assignments. Allowlist file `scripts/harness/lib/scrub-secrets-allowlist.txt` for known test fixtures (e.g., a specific test JWT used in integration tests) — matches on the allowlist pass through untouched. Add fixture tests in `tests/hooks/scrub-secrets/` feeding each pattern through the scrubber and asserting redaction.
- [x] Step 2: Integrate the scrubber into `scripts/harness/run-cmd`. Pipe captured stdout/stderr through `lib/scrub-secrets.sh` before emission to the caller's tty/stdout; preserve **raw** (unscrubbed) output in `target/runner.log` because the log is local-only and operators may genuinely need the original for debugging. Verify the existing error-extraction logic (surefire/failsafe report parsing) still works after the filter is added.
- [x] Step 3: Verify integration with a live run. Fixture: invoke a bash command that prints a fake AWS key + a JWT through `run-cmd`, assert redacted output appears in the captured stream and raw values appear in `target/runner.log`. Also run `scripts/harness/mvn -q compile` to prove no performance regression on normal output.

### Block 2 — File-modification guards
Context: secret scrubber shipped, `run-cmd` integration verified. This block adds two guards: one blocking (migration edit) and one warning (jacoco config).
- [x] Step 4: Add `check_migration_edit_guard()` to `lib/hook-checks.sh` (A4 — `persistence.md` § "Schema management — Flyway"). Takes a working directory; runs `git diff --cached --name-status -- src/main/resources/db/migration/`; if any row starts with `M` (modified, not `A` added), exits non-zero with message: "V<n>__*.sql is modified — never edit an applied migration; create V<n+1>." This is the first *blocking* hook — all others so far are non-blocking reminders. Fixtures: `M` row on a migration file (block), `A` row on a new migration (pass), modification to a non-migration file (pass).
- [x] Step 5: Add `check_jacoco_config_guard()` (A5 — `jacoco-coverage.md`). On `Edit|Write` of `pom.xml`, use `git diff HEAD -- pom.xml` to check whether the edited region touched any line containing `jacoco-maven-plugin` or belongs to an XML block whose ancestor is the jacoco plugin declaration. Non-blocking warning with strong language: "You edited the JaCoCo plugin configuration — this violates `jacoco-coverage.md`. Revert unless the user explicitly approved." Fixtures: edit to jacoco block (warn), edit to a different plugin block (clean), edit to a `<dependency>` (clean).
- [x] Step 6: Create `scripts/harness/install-git-hooks` — idempotent installer that drops a `.git/hooks/pre-commit` file wired to call `check_migration_edit_guard`. Must handle the case where `.git/hooks/pre-commit` already exists (append, don't overwrite) and must be safe to re-run. Document the installer in the top of `persistence.md` (next to the rule) so new clones know to run it. Add fixture tests under `scripts/harness/tests/hooks/install-git-hooks/` using temporary git repositories (`mktemp -d` + `git init`) that exercise three scenarios: **(a) fresh repo** with no pre-existing `pre-commit` hook → installer creates the hook file with the expected invocation and exit-on-failure semantics; **(b) re-run on the same repo** → `pre-commit` file is unchanged byte-for-byte after the second run (no duplicate guard invocation appended) — asserted via `cmp` on before/after snapshots; **(c) pre-existing custom `pre-commit`** → the custom content is preserved intact and the guard invocation is appended exactly once (verified by counting matches of a marker string in the final file). Runner asserts expected file contents after each scenario and cleans up the temporary repo.

### Block 3 — Wiring + cross-epic audit & close
Context: all hook functions exist, scrubber is live in `run-cmd`, git-hooks installer works. This block wires the final pieces, updates docs, and runs the cross-epic audit that closes EPIC-0001.
- [x] Step 7: Wire `check_jacoco_config_guard` into the PostToolUse dispatcher for `Edit|Write` on `pom.xml`. Append `Enforcement:` lines to `security.md` (scrubber), `persistence.md` (migration guard + installer pointer), `jacoco-coverage.md` (config guard). Verify with `grep -c '^Enforcement:' .claude/rules/{security,persistence,jacoco-coverage}.md`.
- [x] Step 8: Run `scripts/harness/full-check` + `scripts/harness/test-hooks` + `scripts/harness/install-git-hooks`. Manual acceptance: stage a modification to an existing migration file (e.g., touch `V2__create_notes_table.sql`) and attempt `git commit` — the pre-commit guard must block. Stage an edit to the `<jacoco-maven-plugin>` block in `pom.xml` — the PostToolUse hook must emit the warning. Revert both test edits.
- [x] Step 9: Cross-epic audit — spawn the `audit` agent with the full EPIC-0001 scope (PLAN-0003 + PLAN-0004 + PLAN-0005 diffs). Verify: (a) every rule file flagged with a GAP in the original audit now has at least one `Enforcement:` line for the promoted clause, (b) every `check_*` function in `lib/hook-checks.sh` has at least one fixture in `tests/hooks/`, (c) no dead standalone scripts remain in `scripts/harness/`, (d) `settings.json` still parses as valid JSON and contains all wired hooks. Report attached to this plan's execution notes. Mark plan completed; move to `docs/exec-plans/completed/`. Once all three child plans are in `completed/`, mark EPIC-0001 completed and move it too.

## Contract updates (if this plan changes a module's REST boundary)
- N/A — touches only `scripts/harness/`, `.claude/rules/*.md`, `.claude/settings.json`, and (transiently) fixture test files. No module code.

## Risks & mitigations

| Risk | Mitigation |
|---|---|
| Secret scrubber redacts legitimate output that happens to match a pattern (false positive breaks a build) | Allowlist file for known test fixtures; raw output preserved in `target/runner.log` so the operator always has the original. Each pattern's fixture test includes a benign near-miss to prove the anchor is specific enough. |
| Scrubber performance cost on large Maven logs | Patterns are compiled once, applied line-by-line via `grep`/`sed` in streaming mode. Fixture Step 3 includes a compile run to catch a regression. |
| Blocking migration guard blocks a legitimate migration-rename scenario (e.g., fixing a typo in a file committed seconds ago but not yet pushed) | Guard is only a blocker at pre-commit — a truly urgent case can still be handled with `git commit --no-verify` and a decision-log entry. The guard's job is to make the unsafe case *visible*, not impossible. Document this escape hatch next to the rule. |
| `install-git-hooks` destroys a user's existing custom pre-commit hook | Installer checks for an existing `.git/hooks/pre-commit`, appends the new invocation if absent, leaves existing content alone. Idempotent re-run verified in fixture. |
| JaCoCo guard's "line inside jacoco block" detection is fragile on multi-line XML edits | Use a simple heuristic: if the diff hunk contains any line matching `jacoco-maven-plugin` OR if the hunk's line numbers fall within the jacoco plugin's declared range, warn. False positives on large pom edits are preferable to false negatives. |
| Cross-epic audit finds a gap and this plan's DoD cannot close | Audit findings drive a follow-up plan under the same EPIC; DoD explicitly allows a "Tech debt introduced" entry pointing at any HIGH-but-not-CRITICAL finding that's deferred. |

## Definition of done
- [x] Every step that touched code includes its fixture tests
- [x] Audit agent passes (cross-epic scope: PLAN-0003 + PLAN-0004 + PLAN-0005 diffs); no CRITICAL or HIGH findings, or any findings logged as tech debt with rationale
- [x] `scripts/harness/full-check` passes
- [x] `scripts/harness/test-hooks` passes
- [x] `echo 'AKIAIOSFODNN7EXAMPLE' | scripts/harness/lib/scrub-secrets.sh` emits `[REDACTED:aws-access-key]`
- [x] `echo 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxIn0.abcdef' | scripts/harness/lib/scrub-secrets.sh` emits `[REDACTED:jwt]`
- [x] Manual: touching `V2__create_notes_table.sql` and attempting `git commit` is blocked by the pre-commit guard; the block message names the file
- [x] Manual: editing the jacoco plugin block in `pom.xml` causes `post-tool-hook` to emit the jacoco-config-guard warning
- [x] `grep -c '^Enforcement:' .claude/rules/security.md` returns ≥ 1 (scrubber)
- [x] `grep -c '^Enforcement:' .claude/rules/persistence.md` returns ≥ 1 (migration guard + installer pointer)
- [x] `grep -c '^Enforcement:' .claude/rules/jacoco-coverage.md` returns ≥ 1 (config guard)
- [x] EPIC-0001 DoD satisfied: all three child plans in `completed/`, epic also moved to `completed/`

## Decision log

| Date | Decision | Rationale |
|---|---|---|
| 2026-04-11 | Scrubber patterns live as string variables initialized in awk's BEGIN, not as /regex/ literals passed to functions | awk treats a `/regex/` argument to a user function as the implicit match `$0 ~ /regex/`, not a regex object. Passing patterns as strings is the portable idiom and works identically under mawk and gawk. Discovered during Step 1 smoke-test (the first version silently returned every line unchanged). |
| 2026-04-11 | run-cmd scrubber is wrapped in `[[ -x "$scrubber" ]]` with raw-emission fallback | Keeps run-cmd usable even if the scrubber is somehow missing or non-executable — we fail open to raw output rather than dropping error context entirely. The allowlist file is similarly optional; awk's getline just reports 0 lines if absent. |

## Tech debt introduced
- None yet.

## Execution notes
<!-- Append discoveries that affect future steps/blocks. See exec-plans.md § "Execution notes". -->

- 2026-04-11 (Block 1): Secret scrubber shipped. Scrubber lives at `scripts/harness/lib/scrub-secrets.sh` (awk-based, single pass), allowlist at `scripts/harness/lib/scrub-secrets-allowlist.txt` (empty seed). `run-cmd` scrubs both the `grep`-matched error lines and the `tail` fallback before emitting to stderr; raw log at `target/runner.log` is untouched. Fixture runner `scripts/harness/test-hooks` gained a `run_scrub_fixture` path for `input`-file fixtures, factored out a shared `match_expectations`/`report_result` helper. Total fixture count 62 → 71 (9 new scrub-secrets fixtures). Live integration verified: fake AWS key + JWT redacted on stderr, preserved in `target/runner.log`; `mvn -q clean compile` success path unchanged (6s, no scrubber involvement on success). Block 2 can reuse `match_expectations` for any input-driven fixtures it adds.
- 2026-04-11 (Block 2): File-modification guards shipped. Two new functions in `scripts/harness/lib/hook-checks.sh`: `check_jacoco_config_guard` (dispatcher-contract, ~20 lines — path guard + `git diff HEAD -- pom.xml` piped through `grep -E '^[+-][^+-]'` and matched against a per-line regex covering `jacoco-maven-plugin|<jacoco\.|</jacoco|COVEREDRATIO|<minimum>|<counter>(LINE|BRANCH)</counter>`) and `check_migration_edit_guard` (blocking, ~20 lines — takes `$1` repo root, NOT a dispatcher function, writes to stderr, returns non-zero). The jacoco guard is NOT yet in post-tool-hook's CHECKS list — Block 3 Step 7 wires it. New installer at `scripts/harness/install-git-hooks` drops a marker-tagged block into `.git/hooks/pre-commit`; supports `HOOK_TARGET_ROOT` env override so fixtures can install into a synthetic repo. `scripts/harness/test-hooks` gained a `run_shell_fixture` path that routes fixtures containing a `test.sh` to a self-contained script runner (exports `REPO_ROOT_REAL`, chdir's into an ephemeral `mktemp -d`, runs the script, reports via the shared `report_result` helper). Route priority in the main loop: `test.sh` > `case.json` > `input`. Fixture count 71 → 81 (+3 migration-guard, +4 jacoco-guard, +3 install-git-hooks). `persistence.md` got a one-time-setup hint pointing at the installer. Block 3 Step 7 still needs to: wire `check_jacoco_config_guard` into the CHECKS list; add `Enforcement:` lines to `security.md`, `persistence.md`, `jacoco-coverage.md`.
- 2026-04-11 (Block 3): Plan closed. Step 7 wired `check_jacoco_config_guard` into `scripts/harness/post-tool-hook`'s CHECKS list and appended `Enforcement:` lines to `.claude/rules/{security,persistence,jacoco-coverage}.md` — each file now has exactly one `Enforcement:` line grounding the promoted clause in a named script or function. Step 8 ran `test-hooks` (81/81 green), `full-check` (doc-lint 0s, verify 26s, smoke-startup on port 18080, OpenAPI spec current), `install-git-hooks` against the real repo (pre-commit hook installed at `.git/hooks/pre-commit` with the `HARNESS:migration-edit-guard` marker), and both safe manual acceptance tests: migration-guard end-to-end in a scratch `mktemp -d` repo (installer → baseline commit → modify migration → invoke `.git/hooks/pre-commit` directly → exit 1 + BLOCKED message naming the file), jacoco-guard via simulated case.json piped through `post-tool-hook` against a whitespace-modified pom.xml then restored (additionalContext contained VIOLATION + JaCoCo). Step 9 cross-epic audit (audit agent, full EPIC-0001 scope) returned PASS with 0 findings across all 7 claim-by-claim checks: no Java regressions, Enforcement lines accurate, no dead standalones, shell scripts sound (quoted expansions, `set -uo pipefail`, heredoc-escaped installer block, marker-based idempotency proved by fixture-level `cmp -s`), fixture coverage parity (11/11 `check_*` functions have fixture dirs, 81/81 green), scrubber pattern soundness (allowlist correctly wired, line-wrapping bypass is an accepted best-effort limit), installer safety (idempotency + preservation genuinely tested, not claimed). Verdict: PLAN-0005 safe to close, no blockers. EPIC-0001 DoD satisfied — all three child plans now in `completed/`.
