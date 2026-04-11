---
status: active
epic: EPIC-0001
---

# PLAN-0003: regex scanning hooks

## Goal
Establish the shared hook library and dispatcher architecture, consolidate dead standalone scripts, and ship per-file regex hooks that catch silent-failure and high-drift rule violations: test class naming, deprecated Spring Boot 3 / JUnit 5 APIs, Lombok deny-list, bundled Tier-B code-style patterns, and `OpenApiContractValidator` usage in integration tests.

## Non-goals
- Cross-file content-aware checks (module contract sync, decision log append, execution-notes discipline, session block structure) — PLAN-0004 covers those
- Git / subprocess / pre-commit guards (migration edit, jacoco config, secret scrubber) — PLAN-0005
- Subjective style rules from `code-style.md` (`var` usage, stream length, class cohesion, exception message wording) — hooks would produce false positives and teach the agent to ignore `additionalContext`
- Rules already enforced by Spotless, NullAway, ArchUnit, or PMD/SpotBugs — no duplicate enforcement in hook form
- Renaming or relocating `post-tool-hook` / `regression-first-reminder` — out-of-scope refactor; only the internal dispatcher shape changes

## Approach
1. **Foundation first**: create `scripts/harness/lib/hook-checks.sh` as the single home for all check functions; refactor `post-tool-hook` to source it and migrate existing inline logic (test reminder + plan progress) into library functions. This pins the dispatcher contract and the fixture-test format before any new hook is added.
2. **Consolidate cleanup in the same block**: delete (or convert into thin wrappers) the dead standalones `check-test-exists` and `plan-progress-check`, fix the stale "8-step limit" comments, unify violation labels. Done once, here, so PLAN-0004 and PLAN-0005 start from a clean base.
3. **Per-file regex hooks in two batches**: test-file hooks (S1, S2, A6) touch `src/test/**/*.java`; main-file hooks (S3, Tier-B bundle) touch `src/main/java/**/*.java`. Both batches use the same library + dispatcher established in Block 1.
4. **Enforcement pointers**: every rule clause that gets a hook gains an `Enforcement: scripts/harness/lib/hook-checks.sh::check_<name>` line in the relevant rule file, so future audits can grep for coverage.

## Steps
<!-- Tests ship with the code: each step that adds/modifies production code must include its tests. See exec-plans.md § "Tests live with the code". -->
<!-- For plans with >5 steps: use session blocks (### Block N — label / Context: ...). See exec-plans.md § "Session blocks". -->

### Block 1 — Foundation & cleanup
Context: none (first block)
- [x] Step 1: Create `scripts/harness/lib/hook-checks.sh` skeleton (sourced-library shape, no functions yet), `scripts/harness/test-hooks` fixture runner, and `scripts/harness/tests/hooks/` directory with a README defining the fixture format. Runner feeds fixtures through `post-tool-hook` end-to-end (input JSON + `$FILE` content → expected-substring in `additionalContext`), so dispatcher routing is covered implicitly — if a check is added but not wired, its positive fixture fails. README mandates **four fixture categories per check** (categories that genuinely don't apply for a given check — e.g., a check with no path guard — must be explicitly justified in that check's fixture README): **(1) positive** — matching path + matching content → expected warning; **(2) content-negative** — matching path + clean content → no output; **(3) benign-near-miss** — matching path + pattern appearing in a comment or string literal → no output (proves the pattern anchor is tight enough); **(4) wrong-path** — non-matching path + content that would otherwise match → no output (proves the dispatcher's path guard is wired correctly and catches the case where a future edit accidentally drops the guard). Runner exits non-zero on any fixture miss.
- [x] Step 2: Refactor `post-tool-hook` into a thin dispatcher that sources `lib/hook-checks.sh`, parses the tool input JSON once, then calls existing checks (now `check_test_reminder`, `check_plan_progress` library functions). Byte-identical output for current known inputs; add a regression fixture pinning the current `EXEC PLAN CHECKPOINT` + `TEST REMINDER` strings so future edits can't silently drift behavior.
- [x] Step 3: Delete standalone `scripts/harness/check-test-exists` + `scripts/harness/plan-progress-check` (their logic now lives in the library). Grep the repo first for any caller. Fix the stale `"8-step"` comment at `post-tool-hook:62`. Unify violation labels — pick plain-text (`VIOLATION:` / `PLAN:`) for greppability; log the choice in the decision log.

### Block 2 — Test-file regex hooks
Context: shared library + dispatcher in place; fixture runner passes; dead standalones removed. New checks are library functions with paired fixtures under `tests/hooks/`.
- [x] Step 4: Add `check_test_naming()` (S1 — `testing.md` § "Test class naming conventions"). Detects: `@SpringBootTest(...RANDOM_PORT)` in a non-`*IT` file; any of `@DataJdbcTest`/`@WebMvcTest`/`@RestClientTest`/`@ApplicationModuleTest` in an `*IT` file. Fixtures: both violation directions + a clean file that emits nothing + a benign near-miss (the annotation in a `// comment`).
- [x] Step 5: Add `check_deprecated_test_api()` (S2 — `testing.md` § "Project-standard Spring Boot 4 / Framework 7 test APIs"). Detects: `@MockBean`, `@SpyBean`, `TestRestTemplate`, `SpringRunner`, `SpringClassRule`, `SpringMethodRule`, `import org.testcontainers.containers.PostgreSQLContainer`, `@JsonComponent`. Each match names the replacement from the testing.md table. Fixture per symbol.
- [x] Step 6: Add `check_contract_validator_in_it()` (A6 — `testing.md` § "OpenAPI contract validation"). For `*IT.java` files using `RestTestClient` or `MockMvcTester` endpoint calls without importing `OpenApiContractValidator`, warn with the rule pointer. Fixtures: IT with validator (clean), IT without (warn), non-IT test (ignored).
- [x] Step 7: Wire the three test-file checks into the dispatcher (only when `$FILE` matches `src/test/**/*.java`). Append `Enforcement:` lines to the corresponding clauses in `testing.md`. Re-run `test-hooks`.

### Block 3 — Main-file regex hooks + close
Context: test-file batch wired and green. Main-file hooks follow the same shape but match `src/main/java/**/*.java`. Tier-B patterns bundled into a single `check_style_scan()` to avoid function sprawl.
- [x] Step 8: Add `check_lombok_denylist()` (S3 — `code-style.md` § "Lombok"). Detects: `@Data`, `@Getter`, `@Setter`, `@Value`, `@AllArgsConstructor`, `@NoArgsConstructor`, `@RequiredArgsConstructor`. Allowlist: `@Slf4j`, `@With`, `@Builder`. Fixture per forbidden annotation + a clean file using `@Slf4j`.
- [x] Step 9: Add `check_style_scan()` — bundled Tier-B regex table (`code-style.md`, `rest.md`, `virtual-threads.md`). Patterns: `Optional<` in parameter/field/record-component position; old nullness annotations (`javax.annotation.Nullable`, JetBrains, FindBugs/SpotBugs); `Stream.collect(Collectors.toList())`; `@Validated` on a `@RestController` line; `@CrossOrigin`; `newFixedThreadPool`/`newCachedThreadPool`; `import reactor.core.publisher.(Mono|Flux)`; `CompletableFuture.supplyAsync`; `ThreadLocal.withInitial`; `import org.mapstruct.`/`import org.modelmapper.`; `LoggerFactory.getLogger`; `@*Mapping("…")` with a path that doesn't start with `/api/`. Pattern table + rule-pointer + fixture name in a declarative block at the top of the function. Fixture per pattern.
- [x] Step 10: Wire main-file checks into dispatcher. Append `Enforcement:` lines to each covered clause in `code-style.md`, `rest.md`, `virtual-threads.md`. Verify: `grep -c '^Enforcement:' .claude/rules/{code-style,testing,rest,virtual-threads}.md`.
- [~] Step 11: Run `scripts/harness/full-check` + `scripts/harness/test-hooks`. Spawn `audit` agent scoped to this plan's diff to verify rule compliance and no regression in existing hook behavior. Mark plan completed; move to `docs/exec-plans/completed/`.

## Contract updates (if this plan changes a module's REST boundary)
- N/A — touches only `scripts/harness/`, `.claude/rules/*.md`, and `.claude/settings.json`. No module code.

## Risks & mitigations

| Risk | Mitigation |
|---|---|
| Dispatcher refactor changes `post-tool-hook` output and breaks the agent's current behavior | Step 2 includes a regression fixture pinning current `EXEC PLAN CHECKPOINT` / `TEST REMINDER` output. Any drift fails `test-hooks` before the change ships. |
| Regex patterns produce false positives (e.g., `@CrossOrigin` in a Javadoc comment) and teach the agent to ignore `additionalContext` | Anchors: annotation at start of line, specific import lines. Each fixture set includes a benign near-miss (pattern in comment or string literal). If benign case fires, the fixture fails and forces pattern refinement. |
| Style-scan bundled hook becomes a grab-bag that's hard to maintain | Pattern table at top of the function (regex + rule pointer + fixture name). Adding a pattern is one row. |
| Dead-standalone deletion breaks a caller (CI, another script, agent memory) | Grep `scripts/ .github/ docs/ .claude/` for references before deletion. If any external caller exists, convert standalone to a thin wrapper that sources the library, rather than deleting. |
| "Enforcement:" marker convention clashes with existing rule-file markdown structure | Decision-logged at Step 10: single prefix style applied consistently. Style lint can be added later if drift appears. |

## Definition of done
- [x] Every step that touched code includes its fixture tests — 49/49 fixtures green via `scripts/harness/test-hooks`
- [x] Audit agent passes — 0 CRITICAL / 0 HIGH; 2 LOW findings fixed in-place before close
- [x] `scripts/harness/full-check` passes (verify 27s, smoke-startup port 18080, OpenAPI current, doc-lint clean)
- [x] `scripts/harness/test-hooks` exists and passes (49 fixtures)
- [x] `test ! -f scripts/harness/check-test-exists && test ! -f scripts/harness/plan-progress-check` — both deleted outright
- [x] `grep -c '^Enforcement:' .claude/rules/testing.md` = 3 (test naming, deprecated APIs, contract validator)
- [x] `grep -c '^Enforcement:' .claude/rules/code-style.md` = 5 (Lombok deny-list, Collectors.toList, nullness imports, manual logger, mapping frameworks)
- [x] `grep -c '^Enforcement:' .claude/rules/rest.md` = 2 (@Validated+@RestController, @CrossOrigin + non-/api/ mapping)
- [x] `grep -c '^Enforcement:' .claude/rules/virtual-threads.md` = 1 (thread pool / reactor / CompletableFuture / ThreadLocal bundle)

## Decision log

| Date | Decision | Rationale |
|---|---|---|
| 2026-04-10 | Violation labels: plain-text `VIOLATION:` / `PLAN:` / `Warning:` (no emoji). | Greppability + `additionalContext` is displayed as a single line in Claude Code with literal `\n`; emoji in that format add no signal. Existing `post-tool-hook` already used this style; the dead `plan-progress-check` standalone used emoji. Library unifies on plain text. |
| 2026-04-10 | Each check writes its chunk to stdout; dispatcher captures and joins with literal `\n\n`. | Keeps check functions self-contained (no shared-variable mutation), preserves byte-identical output versus the pre-refactor hook, and makes fixture-based testing tractable (`expect.txt` reasons about `additionalContext` substrings rather than stderr noise). |
| 2026-04-10 | Dispatcher uses `REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel …)}"` rather than always computing it. | Lets the fixture runner inject a temporary `REPO_ROOT` so plan-progress fixtures can seed fake active plan files without polluting the real `docs/exec-plans/active/` directory. |
| 2026-04-10 | Deleted `check-test-exists` and `plan-progress-check` outright (no thin-wrapper fallback). | Repo-wide grep found zero external callers; the only references were in this plan and its epic. Thin wrappers would have preserved a drift trap for no benefit. |
| 2026-04-10 | `check_deprecated_test_api` uses `import`-anchored detection for type-name patterns (`TestRestTemplate`, `SpringRunner`, `SpringClassRule`, `SpringMethodRule`, legacy `PostgreSQLContainer`) and annotation-anchored detection for `@MockBean` / `@SpyBean`. | Import-anchored is tight enough to avoid firing on the identifier appearing inside a comment or string literal, yet sufficient — a Java file cannot use a type without importing it. Annotation-anchored uses `^[[:space:]]*@` so the pattern stays silent inside multi-line comments. Both anchor styles verified by `benign-near-miss-comment` fixture. |
| 2026-04-10 | `@JsonComponent` omitted from `check_deprecated_test_api` pattern table. | `testing.md` does not call out a specific replacement for `@JsonComponent`. Per the plan's non-goal "do not fabricate text that is not in the rule file", a pattern without a documented replacement is worse than no pattern — it teaches the agent to ignore `additionalContext`. If a replacement is added to `testing.md` in the future, add the pattern then. |
| 2026-04-10 | `check_contract_validator_in_it` uses import-anchored detection for both trigger (`RestTestClient` / `MockMvcTester`) and allowlist (`OpenApiContractValidator`). | Matches the same anchor rationale as `check_deprecated_test_api`. Benign-near-miss fixture confirms a Javadoc mention of "RestTestClient" in a comment does not misfire. |
| 2026-04-10 | `check_style_scan` excludes `Optional<` detection in parameter/field positions and `@JsonComponent` replacement hint. | `Optional<` is hard to anchor without a Java parser (return types vs parameters look identical to regex). `@JsonComponent` has no named replacement in `testing.md`. Both left as tech debt; an ArchUnit rule is a better fit for `Optional<` placement. |
| 2026-04-10 | `check_style_scan` uses per-line `grep -vE '^[0-9]+:[[:space:]]*(//\|\*)'` comment exclusion for virtual-thread anti-patterns. | These are method-call patterns that cannot be import-anchored (the base types `Executors`, `CompletableFuture`, `ThreadLocal` have legitimate uses). Line-level anchor excludes comment lines but still fires on real inline call sites. Verified by dedicated `benign-near-miss-in-comments` fixture with all 14 patterns embedded in Javadoc. |
| 2026-04-10 | `content-negative` / `benign-near-miss` fixtures for main-file checks use scoped `-substring` negatives instead of `EMPTY`. | `check_test_reminder` also fires on every `src/main/java/**/*.java` path, so `EMPTY` is unreachable for main-file fixtures. Scoped negatives target the specific check under test and let the test-reminder pass through. Documented in execution notes for PLAN-0004/0005. |
| 2026-04-10 (post-audit) | Addressed both audit LOW findings in-place before closing PLAN-0003. | (a) Collapsed `check_style_scan` Collectors.toList() double-grep into the same pattern used by the virtual-thread checks. (b) Added `check_test_naming/benign-near-miss-slice-annotation-in-it-comment/` fixture to cover the second anchor branch (slice annotations in an `*IT`-named file Javadoc). Fixes are <10 lines and keep every check's fixture matrix symmetric. 49/49 fixtures pass after the fixes. |

## Tech debt introduced
- **`Optional<` in parameter / field / record-component position** not enforced by `check_style_scan`. Regex cannot distinguish parameter-type uses from return-type uses without a Java parser. Better fit: an ArchUnit rule. Not blocking, but the rule in `code-style.md` § "Modeling and framework boundaries" stays documentation-only for this placement.
- **`@JsonComponent` → modern replacement** not enforced. `testing.md` does not currently name a replacement; adding a pattern without a named alternative would teach the agent to ignore the warning. Revisit if `testing.md` adds a replacement.
- **`check_plan_progress` sequential-execution false positives**: when executing multiple active plans sequentially under an epic, downstream plans fire `VIOLATION: No step marked [~] in-progress` warnings even though those plans are intentionally queued. PLAN-0004 Block 1's `check_session_block_structure` / plan-file diff hooks can narrow `check_plan_progress` to only warn on the plan whose Steps section most recently changed (via `git diff HEAD -- "$FILE"`). Documented in execution notes.

## Execution notes
<!-- Append discoveries that affect future steps/blocks. See exec-plans.md § "Execution notes". -->

- 2026-04-10 (Block 1): `check_plan_progress` treats every plan under `docs/exec-plans/active/*.md` as equally "current", so when executing plans sequentially under an epic, downstream plans fire VIOLATION warnings from the very first edit because none of their steps are `[~]` yet. This is a **false positive** on the sequential-execution workflow and is the motivating case for `check_session_block_structure` / plan-file diff hooks in PLAN-0004 Block 1 — consider having PLAN-0004 also narrow `check_plan_progress` to only warn on the plan whose steps section most recently changed (via `git diff`) so sibling plans stay quiet. Noted so PLAN-0004 Block 1 does not re-derive this.
- 2026-04-10 (Block 1): Fixture runner's temporary REPO_ROOT strategy works cleanly for `check_plan_progress`. Confirmed by `positive-no-in-progress` passing when the fixture's `plans/PLAN-0099-fake.md` is the only active plan visible to the hook, even though the real repo has three active plans. Block 2 and beyond can rely on this isolation.
- 2026-04-10 (Block 1): Command substitution strips trailing newlines, but `printf '%s' "$plan_msg"` (with `plan_msg` containing literal backslash-n sequences) yields captures that still carry the literal `\n` characters. Byte-identical output verified against the pre-refactor hook by running both against the same input. If a future check needs to include actual newlines in its chunk, it has to embed them as literal `\n` the way `check_plan_progress` does — document that convention if Block 2 or later hooks run into it.
- 2026-04-10 (Block 1): `check_test_reminder` README justifies skipping the `benign-near-miss` category because the check reads no file content at all — only `file_path`. Apply the same pattern for other path-only checks (no future `check_test_reminder`-style check should be blocked on inventing a synthetic near-miss case).
- 2026-04-10 (Block 2): Fixture count after Block 2 = 27 (was 7 after Block 1). Distribution: check_test_reminder 3, check_plan_progress 4, check_test_naming 5, check_deprecated_test_api 9, check_contract_validator_in_it 5. `check_deprecated_test_api` intentionally ships multiple positive fixtures (one per detected pattern family) plus the mandatory negatives — the 4-category rule is a floor, not a ceiling, for checks with multiple trigger patterns.
- 2026-04-10 (Block 2): All pattern detection in Block 2 uses shell `grep -E` with `^[[:space:]]*` or `^[[:space:]]*import[[:space:]]+` anchors. This proved robust enough that no multi-line awk scanning was needed. Block 3 can reuse the same anchor style for the Lombok deny-list and the Tier-B style scan. Watch for patterns that legitimately appear mid-line (like `Optional<` in a parameter list) — those will need a different anchor and probably a `benign-near-miss-in-javadoc-return-doc` fixture.
- 2026-04-10 (Block 2): `testing.md` now has 3 `Enforcement:` markers (the plan's DoD requires ≥3). Placement convention: single plain-text line starting with `Enforcement: scripts/harness/lib/hook-checks.sh::check_<name>` followed by a short sentence summarizing what the hook catches. Placed after the rule's table or bullet list, before the next `##`/`###` heading. Follow the same placement for Block 3's code-style.md, rest.md, virtual-threads.md annotations.
- 2026-04-10 (Block 3): Final fixture count = 49 (was 27 after Block 2). New: `check_lombok_denylist` 7, `check_style_scan` 14, plus one late-added sibling benign-near-miss for `check_test_naming` (from audit finding). `check_style_scan` uses a single dense `benign-near-miss-in-comments` fixture that exercises all 14 pattern families inside a Javadoc block — denser than one-per-pattern and catches the regression risk equivalently via a 14-line `-substring` assertion list.
- 2026-04-10 (Block 3): Enforcement marker counts at close: testing.md=3, code-style.md=5, rest.md=2, virtual-threads.md=1. All DoD thresholds met.
- 2026-04-10 (Block 3): `full-check` green (verify 27s, smoke-startup port 18080, OpenAPI current, doc-lint clean). `test-hooks` green (49/49). Audit: 0 CRITICAL / 0 HIGH / 2 LOW — both LOW findings fixed in place before close.
- 2026-04-10 (Block 3): **Scoped-negative pattern for main-file check fixtures.** Because `check_test_reminder` fires on every `src/main/java/**/*.java` write, `EMPTY` is unreachable for fixtures on that path. Use scoped `-substring` negatives (e.g., `-VIOLATION: Foo.java: Collectors.toList()`) that target only the check under test. `EMPTY` is still valid for path-guard wrong-path fixtures (test files, package-info, etc.) where no check fires. **Applies to all main-file checks in PLAN-0004/0005.**
