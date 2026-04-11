#!/usr/bin/env bash
# scripts/harness/lib/hook-checks.sh
#
# Shared library of check functions for post-tool-hook dispatcher.
# Source this file from post-tool-hook — do not execute it directly.
#
# Dispatcher contract:
#   Before calling any check function, the dispatcher exports:
#     TOOL       tool_name from the Claude Code hook input ("Edit", "Write", "Bash")
#     FILE       tool_input.file_path (may be empty for Bash calls)
#     CMD        tool_input.command (only set for Bash calls)
#     INPUT      raw JSON input (for advanced access, e.g. tool_result.exit_code)
#     REPO_ROOT  absolute path to the repository root
#
# Each check function writes its warning text to stdout (or nothing). The
# dispatcher collects chunks and joins them with literal "\n\n" separators.
# Path guards live inside each check function; the dispatcher stays simple.
#
# Functions must not alter shell state that outlives their call (no unset,
# no global exports). Use `local` for variables.
#
# To add a new check:
#   1. Add a function below (convention: check_<name>)
#   2. Append the function name to the dispatcher's CHECKS list in
#      scripts/harness/post-tool-hook
#   3. Add fixture cases under scripts/harness/tests/hooks/<check_name>/
#      covering the four mandatory categories (positive, content-negative,
#      benign-near-miss, wrong-path) — see tests/hooks/README.md.

# -----------------------------------------------------------------------------
# Shared helpers
# These collapse the three repeated patterns that appear across most checks:
#   - _guard_edit_write_java: dispatcher-guard for Edit|Write on a Java file
#     under the requested scope (main|test|any). Returns 0 on match, 1 otherwise.
#   - _has_import: true if FILE contains `import <regex>` at line start. The
#     regex argument is the FQN tail (everything after `import[[:space:]]+`).
#   - _grep_annotation_at_line_start: runs a single awk pass over FILE and
#     emits each matching annotation name (without `@`) in caller order.
# -----------------------------------------------------------------------------
_guard_edit_write_java() {
  [[ "$TOOL" == "Edit" || "$TOOL" == "Write" ]] || return 1
  case "$1" in
    main) [[ "$FILE" == *src/main/java/*.java ]] ;;
    test) [[ "$FILE" == *src/test/java/*.java ]] ;;
    any)  [[ "$FILE" == *src/main/java/*.java || "$FILE" == *src/test/java/*.java ]] ;;
  esac
}

_has_import() {
  grep -Eq '^[[:space:]]*import[[:space:]]+'"$2" "$1" 2>/dev/null
}

_grep_annotation_at_line_start() {
  local file="$1"
  shift
  (($#)) || return 0
  awk -v names="$*" '
    BEGIN {
      n = split(names, arr, " ")
      for (i = 1; i <= n; i++) {
        pat[i] = "^[[:space:]]*@" arr[i] "([^A-Za-z0-9_]|$)"
      }
    }
    {
      for (i = 1; i <= n; i++) {
        if (!seen[i] && $0 ~ pat[i]) { seen[i] = 1 }
      }
    }
    END {
      for (i = 1; i <= n; i++) if (seen[i]) print arr[i]
    }
  ' "$file" 2>/dev/null
}

# -----------------------------------------------------------------------------
# check_test_reminder
# Nudges the agent to write a test for any production Java file it just
# created or edited.
# Rule: testing.md § "Tests live with the code"
# -----------------------------------------------------------------------------
check_test_reminder() {
  _guard_edit_write_java main || return 0
  local bn
  bn=$(basename "$FILE" .java)
  [[ "$bn" == "package-info" ]] && return 0
  printf '%s' "TEST REMINDER: You wrote $bn. Decide what test this needs (unit, slice, or integration) per .claude/rules/testing.md, if a test is needed do NOT delay writing it, do it right now"
}

# -----------------------------------------------------------------------------
# check_plan_progress
# Inspects docs/exec-plans/active/*.md and warns about discipline slips:
#   - no step marked [~] in-progress while open steps remain
#   - tests passed but step still [~]
#   - plan exceeds the 12-step hard limit
# Emits a single "EXEC PLAN CHECKPOINT:" chunk.
#
# Narrowing logic (avoids sibling-plan false positives during sequential
# execution):
#
#   - If the edited $FILE is itself a plan file under docs/exec-plans/active/,
#     only inspect THAT plan.
#   - Otherwise, inspect the plan whose Steps section already has a [~] marker
#     (the plan currently being executed). If more than one plan has a [~],
#     all of them are included. If zero plans have a [~] and at least one plan
#     has an open step, emit a single "no step [~]" warning naming the
#     most-recently-edited plan (resolved via `ls -t` mtime — portable and
#     does not depend on the fixture having git history).
#   - The 12-step limit and "tests passed with [~]" checks always run on the
#     selected plans (never on unrelated siblings).
#
# Rule: exec-plans.md § "Execution discipline", § "Plan size limit"
# -----------------------------------------------------------------------------
check_plan_progress() {
  # Patterns for Bash-branch triggering. Lifted to readonly locals so the
  # regex is visible at function top instead of buried in two call sites.
  local trigger_cmd_re='(mvnw|mvn|full-check|verify|spotless|smoke-startup|doc-lint|fast-check)'
  local test_cmd_re='(verify|full-check|test)'

  local run=false
  if [[ "$TOOL" == "Edit" || "$TOOL" == "Write" ]]; then
    run=true
  elif [[ "$TOOL" == "Bash" && "$CMD" =~ $trigger_cmd_re ]]; then
    run=true
  fi
  $run || return 0

  local active_dir="$REPO_ROOT/docs/exec-plans/active"
  [ -d "$active_dir" ] || return 0

  # Single-pass awk that, given a plan file, extracts the `## Steps` section
  # and counts: open ([ ]), in-progress ([~]), done ([x]) top-level steps,
  # plus decision-log data rows and execution-notes bullets from their own
  # sections. Emits one line: "open in_progress done_count dec_rows notes".
  # Replaces the 1-awk + 3-grep + 2-awk-reread pattern of the previous
  # implementation with one awk invocation per plan.
  _plan_counts() {
    awk '
      /^## Steps/           { section = "steps";  next }
      /^## Decision log/    { section = "dec";    next }
      /^## Execution notes/ { section = "notes";  next }
      /^## /                { section = ""        }
      section == "steps" && /^- \[ \]/  { open++ }
      section == "steps" && /^- \[~\]/  { in_progress++ }
      section == "steps" && /^- \[x\]/  { done_count++ }
      section == "dec"    && /^\| [0-9]{4}-[0-9]{2}-[0-9]{2}/ { dec++ }
      section == "notes"  && /^- /      { notes++ }
      END {
        printf "%d %d %d %d %d\n",
          open + 0, in_progress + 0, done_count + 0, dec + 0, notes + 0
      }
    ' "$1"
  }

  # Build the candidate plan list. Three cases:
  #   1. Edited file is a plan under docs/exec-plans/active/ -> just that plan.
  #   2. Otherwise, plans with a [~] marker -> those plans.
  #   3. Otherwise, fall back to the most-recently-edited active plan.
  #
  # Caches awk results per candidate via parallel indexed arrays keyed by
  # array index, so the main loop does not re-read the plan file.
  local -a candidates=() counts_cache=()

  if [[ "$FILE" == "$active_dir/"*.md ]]; then
    candidates=("$FILE")
    counts_cache=("$(_plan_counts "$FILE")")
  else
    local plan counts ip
    for plan in "$active_dir"/*.md; do
      [ -e "$plan" ] || continue
      counts=$(_plan_counts "$plan")
      ip=${counts#* }; ip=${ip%% *}
      if [ "$ip" -gt 0 ]; then
        candidates+=("$plan")
        counts_cache+=("$counts")
      fi
    done
    if ((${#candidates[@]} == 0)); then
      # Fallback: most-recently-edited active plan. `ls -t` sorts by mtime
      # descending, and `head -n1` picks the most recent. Using `ls -t` rather
      # than `git log` keeps the check portable across fixture runners that
      # may lack a git history.
      local newest
      newest=$(ls -t "$active_dir"/*.md 2>/dev/null | head -n1)
      if [ -n "$newest" ]; then
        candidates=("$newest")
        counts_cache=("$(_plan_counts "$newest")")
      fi
    fi
  fi

  ((${#candidates[@]} == 0)) && return 0

  local plan_msg=""
  local i plan name open in_progress done_count dec_count notes_count total tool_exit
  for i in "${!candidates[@]}"; do
    plan="${candidates[$i]}"
    [ -e "$plan" ] || continue
    name=$(basename "$plan")
    read -r open in_progress done_count dec_count notes_count <<< "${counts_cache[$i]}"

    if [[ "$TOOL" == "Bash" ]] && [ "$in_progress" -gt 0 ] && [[ "$CMD" =~ $test_cmd_re ]]; then
      tool_exit=$(echo "$INPUT" | jq -r '.tool_result.exit_code // empty')
      if [ "$tool_exit" = "0" ]; then
        plan_msg="${plan_msg}  Warning: ${name}: Tests passed with step still [~]. Mark it [x] and add execution notes before continuing.\n"
      fi
    fi

    if [ "$in_progress" -eq 0 ] && [ "$open" -gt 0 ]; then
      plan_msg="${plan_msg}  VIOLATION: ${name}: No step marked [~] in-progress. Mark your current step [~] in the plan file NOW before writing more code.\n"
    fi

    total=$((open + in_progress + done_count))
    if [ "$total" -gt 12 ]; then
      plan_msg="${plan_msg}  VIOLATION: ${name}: ${total} steps exceeds 12-step limit. Split into follow-up plan.\n"
    fi

    if [ "$open" -gt 0 ]; then
      plan_msg="${plan_msg}  PLAN: ${name}: ${done_count} done, ${in_progress} active, ${open} remaining\n"
    elif [ "$done_count" -gt 0 ] && [ "$in_progress" -eq 0 ]; then
      plan_msg="${plan_msg}  PLAN: ${name}: All items checked. Move to docs/exec-plans/completed/\n"

      # Pre-finalization checks: decision log and execution notes counts
      # come from the same awk pass that populated counts_cache.
      if [ "$dec_count" -eq 0 ]; then
        plan_msg="${plan_msg}  Warning: ${name}: plan is complete but decision log is empty — add at least one row before moving to completed/\n"
      fi
      if [ "$notes_count" -eq 0 ]; then
        plan_msg="${plan_msg}  Warning: ${name}: plan is complete but execution notes are empty — add a block summary before moving to completed/\n"
      fi
    fi
  done

  if [[ -n "$plan_msg" ]]; then
    printf '%s' "EXEC PLAN CHECKPOINT:\n$plan_msg"
  fi
}

# -----------------------------------------------------------------------------
# check_test_naming
# Flags test files whose annotation contents mismatch the naming convention:
#   - @SpringBootTest(...RANDOM_PORT) in a *Test file → should be *IT
#   - @DataJdbcTest/@WebMvcTest/@RestClientTest/@ApplicationModuleTest in
#     an *IT file → should be *Test
# Anchors: annotation must appear at start of a (possibly indented) line so
# the same token in a `// comment` or string literal stays silent.
# Rule: testing.md § "Test class naming conventions"
# -----------------------------------------------------------------------------
check_test_naming() {
  _guard_edit_write_java test || return 0
  [ -f "$FILE" ] || return 0
  local bn
  bn=$(basename "$FILE" .java)
  local out=""

  if [[ "$bn" != *IT ]]; then
    # Integration annotation in a *Test file.
    if grep -Eq '^[[:space:]]*@SpringBootTest\b[^/]*RANDOM_PORT' "$FILE" 2>/dev/null; then
      out="${out}VIOLATION: ${bn}.java uses @SpringBootTest(RANDOM_PORT) but the basename is not *IT — integration annotations belong in *IT.java files. Rename ${bn} → ${bn%Test}IT (see .claude/rules/testing.md § \"Test class naming conventions\")."
    fi
  fi

  if [[ "$bn" == *IT ]]; then
    # Slice/module annotation in an *IT file — first match wins. The helper
    # returns each matching name on its own line in caller order, so `head -n1`
    # picks the first one in that order.
    local annfound
    annfound=$(_grep_annotation_at_line_start "$FILE" \
      DataJdbcTest WebMvcTest RestClientTest ApplicationModuleTest \
      | head -n1)
    if [[ -n "$annfound" ]]; then
      [[ -n "$out" ]] && out="${out}\n\n"
      out="${out}VIOLATION: ${bn}.java uses @${annfound} but the basename ends in IT — slice/module annotations belong in *Test.java files. Rename ${bn} → ${bn%IT}Test (see .claude/rules/testing.md § \"Test class naming conventions\")."
    fi
  fi

  [[ -n "$out" ]] && printf '%s' "$out"
  return 0
}

# -----------------------------------------------------------------------------
# check_deprecated_test_api
# Warns when a test file uses Spring Boot 3 / JUnit 4 era APIs that have
# project-standard replacements in Spring Boot 4 / Framework 7 / JUnit 6.
# Each trigger names the replacement from testing.md's standards table.
# Rule: testing.md § "Project-standard Spring Boot 4 / Framework 7 test APIs"
#       testing.md § "JUnit 6 baseline"
#       testing.md § "Testcontainers 2.x import paths"
# -----------------------------------------------------------------------------
check_deprecated_test_api() {
  _guard_edit_write_java test || return 0
  [ -f "$FILE" ] || return 0
  local out="" hits=()

  # Annotation-start anchored patterns (tight: ignores occurrences in // comments).
  local ann
  while IFS= read -r ann; do
    case "$ann" in
      MockBean) hits+=("@MockBean is deprecated for removal in Spring Boot 4 — replace with @MockitoBean") ;;
      SpyBean)  hits+=("@SpyBean is deprecated for removal in Spring Boot 4 — replace with @MockitoSpyBean") ;;
    esac
  done < <(_grep_annotation_at_line_start "$FILE" MockBean SpyBean)

  # Type-name patterns: match ONLY on the import statement. This keeps the
  # anchor tight enough that identifiers mentioned inside a `// comment` or
  # a string literal do not misfire. (A usage site without the import is
  # impossible in Java, so import-anchored detection is sufficient.)
  if _has_import "$FILE" '[A-Za-z0-9_.]*\.TestRestTemplate[[:space:]]*;'; then
    hits+=("TestRestTemplate is not a project-standard Spring Boot 4 test API — use RestTestClient for full HTTP integration tests")
  fi
  if _has_import "$FILE" '[A-Za-z0-9_.]*\.SpringRunner[[:space:]]*;'; then
    hits+=("SpringRunner is JUnit 4 — Spring Framework 7 requires JUnit 6. Remove @RunWith or replace with JUnit 6 @ExtendWith(SpringExtension.class)")
  fi
  if _has_import "$FILE" '[A-Za-z0-9_.]*\.SpringClassRule[[:space:]]*;'; then
    hits+=("SpringClassRule is a JUnit 4 rule — obsolete in JUnit 6. Remove it (see .claude/rules/testing.md § \"JUnit 6 baseline\")")
  fi
  if _has_import "$FILE" '[A-Za-z0-9_.]*\.SpringMethodRule[[:space:]]*;'; then
    hits+=("SpringMethodRule is a JUnit 4 rule — obsolete in JUnit 6. Remove it (see .claude/rules/testing.md § \"JUnit 6 baseline\")")
  fi

  # Testcontainers 2.x relocated PostgreSQLContainer — flag the legacy import.
  if _has_import "$FILE" 'org\.testcontainers\.containers\.PostgreSQLContainer[[:space:]]*;'; then
    hits+=("org.testcontainers.containers.PostgreSQLContainer is the Testcontainers 1.x path — use org.testcontainers.postgresql.PostgreSQLContainer (see .claude/rules/testing.md § \"Testcontainers 2.x import paths\")")
  fi

  if ((${#hits[@]} > 0)); then
    local first=true h
    for h in "${hits[@]}"; do
      if $first; then
        out="VIOLATION: $h. See .claude/rules/testing.md § \"Project-standard Spring Boot 4 / Framework 7 test APIs\"."
        first=false
      else
        out="${out}\n\nVIOLATION: $h. See .claude/rules/testing.md § \"Project-standard Spring Boot 4 / Framework 7 test APIs\"."
      fi
    done
    printf '%s' "$out"
  fi
  return 0
}

# -----------------------------------------------------------------------------
# check_contract_validator_in_it
# Integration tests that exercise REST endpoints via RestTestClient or
# MockMvcTester must also validate the response shape against
# docs/generated/openapi.json using OpenApiContractValidator.
# Rule: testing.md § "OpenAPI contract validation"
# -----------------------------------------------------------------------------
check_contract_validator_in_it() {
  _guard_edit_write_java test || return 0
  local bn
  bn=$(basename "$FILE" .java)
  [[ "$bn" == *IT ]] || return 0
  [ -f "$FILE" ] || return 0

  # Does the test exercise an endpoint via a project-standard client? We
  # detect via the import statement to avoid false positives on identifiers
  # that only appear inside a comment or string literal.
  _has_import "$FILE" '[A-Za-z0-9_.]*\.(RestTestClient|MockMvcTester)[[:space:]]*;' || return 0

  # Bail if the validator is already imported.
  if _has_import "$FILE" '[A-Za-z0-9_.]*\.OpenApiContractValidator[[:space:]]*;'; then
    return 0
  fi

  printf '%s' "VIOLATION: ${bn}.java is an integration test that calls REST endpoints via RestTestClient or MockMvcTester but does not import OpenApiContractValidator. Integration tests exercising REST endpoints must assert response shape via OpenApiContractValidator.assertResponseMatchesSpec — see .claude/rules/testing.md § \"OpenAPI contract validation\"."
  return 0
}

# -----------------------------------------------------------------------------
# check_lombok_denylist
# Flags disallowed Lombok annotations on main-source Java files. Records and
# sealed types already cover what `@Data` / `@Getter` / `@Setter` / `@Value` /
# `@*ArgsConstructor` did; those annotations hide behavior and short-circuit
# reasoning about field mutability and constructor wiring. Allowlist:
# `@Slf4j`, `@With`, `@Builder`.
# Anchor: `^[[:space:]]*@Name\b` so the pattern stays silent inside comments.
# Rule: code-style.md § "Lombok"
# -----------------------------------------------------------------------------
check_lombok_denylist() {
  _guard_edit_write_java main || return 0
  [ -f "$FILE" ] || return 0

  local out="" hits=() ann
  while IFS= read -r ann; do
    [[ -n "$ann" ]] && hits+=("@$ann")
  done < <(_grep_annotation_at_line_start "$FILE" \
    Data Getter Setter Value AllArgsConstructor NoArgsConstructor RequiredArgsConstructor)

  if ((${#hits[@]} > 0)); then
    local list
    list=$(printf '%s, ' "${hits[@]}")
    list="${list%, }"
    out="VIOLATION: $(basename "$FILE" .java).java uses disallowed Lombok annotation(s): ${list}. Lombok is limited to @Slf4j, @With, @Builder — records and sealed types replace the data/constructor shortcuts. See .claude/rules/code-style.md § \"Lombok\"."
    printf '%s' "$out"
  fi
  return 0
}

# -----------------------------------------------------------------------------
# check_style_scan
# Bundled Tier-B style / framework-boundary scan over src/main/java/**/*.java.
# Each entry in PATTERNS is a space-separated tuple of
#   <label>|<anchor-regex>|<rule-pointer>
# where <anchor-regex> is matched with `grep -E` against the file. Entries
# are checked in order; every match contributes one VIOLATION line to the
# chunk the check emits.
#
# | # | Label                          | Rule                                                    | Fixture family                  |
# |---|--------------------------------|---------------------------------------------------------|---------------------------------|
# | 1 | legacy-nullness-jsr305         | code-style.md § Null safety                             | positive-nullness-imports       |
# | 2 | legacy-nullness-jetbrains      | code-style.md § Null safety                             | positive-nullness-imports       |
# | 3 | legacy-nullness-findbugs       | code-style.md § Null safety                             | positive-nullness-imports       |
# | 4 | stream-collectors-tolist       | code-style.md § Functional style                        | positive-collectors-tolist      |
# | 5 | manual-logger-factory-import   | code-style.md § Logging                                 | positive-manual-logger          |
# | 6 | crossorigin-annotation         | rest.md § URI design                                    | positive-crossorigin            |
# | 7 | reactor-publisher-import       | virtual-threads.md § Do NOT                             | positive-reactor-import         |
# | 8 | mapstruct-import               | code-style.md § Modeling and framework boundaries       | positive-mapping-framework-import |
# | 9 | modelmapper-import             | code-style.md § Modeling and framework boundaries       | positive-mapping-framework-import |
# |10 | executors-newfixedthreadpool   | virtual-threads.md § Do NOT                             | positive-executors-pool         |
# |11 | executors-newcachedthreadpool  | virtual-threads.md § Do NOT                             | positive-executors-pool         |
# |12 | completablefuture-supplyasync  | virtual-threads.md § Do NOT                             | positive-completablefuture-async|
# |13 | threadlocal-withinitial        | virtual-threads.md § Do NOT                             | positive-threadlocal-withinitial|
#
# Two non-line-based checks run in addition:
# - @Validated alongside @RestController in the same file (rest.md § Controller responsibilities)
# - `@(Get|Post|Put|Delete|Patch|Request)Mapping("path")` where path does not
#   start with `/api/` (rest.md § URI design)
#
# Rule: code-style.md, rest.md, virtual-threads.md
# -----------------------------------------------------------------------------
check_style_scan() {
  _guard_edit_write_java main || return 0
  [ -f "$FILE" ] || return 0

  local bn
  bn=$(basename "$FILE" .java)

  # Single awk pass runs every Tier-B style pattern against each non-comment
  # line, emitting one label per hit (newline-separated, stable order). The
  # label is used below to build the VIOLATION text — keeping the message
  # strings in bash avoids awk string-quoting issues. Replaces the previous
  # ~17 sequential `grep -E` + `grep -qvE` pipelines.
  #
  # `\b` is not portable in mawk, so patterns use `[^A-Za-z0-9_]` (or end-of-
  # line via `$`) to reject word-char continuation.
  local labels
  labels=$(awk '
    BEGIN { W = "([^A-Za-z0-9_]|$)" }
    # Skip blank lines.
    /^[[:space:]]*$/ { next }
    # Skip line comments, javadoc opens, and javadoc continuation lines.
    /^[[:space:]]*(\/\/|\*|\/\*)/ { next }

    # --- Imports (line-start anchored — safe regardless of the filter) ---
    $0 ~ ("^[[:space:]]*import[[:space:]]+javax\\.annotation\\.(Nullable|Nonnull)" W) { h["nullness-jsr305"] = 1 }
    $0 ~ ("^[[:space:]]*import[[:space:]]+org\\.jetbrains\\.annotations\\.(Nullable|NotNull)" W) { h["nullness-jetbrains"] = 1 }
    /^[[:space:]]*import[[:space:]]+edu\.umd\.cs\.findbugs\.annotations\./ { h["nullness-findbugs"] = 1 }
    /^[[:space:]]*import[[:space:]]+org\.slf4j\.LoggerFactory[[:space:]]*;/ { h["manual-logger"] = 1 }
    $0 ~ ("^[[:space:]]*import[[:space:]]+reactor\\.core\\.publisher\\.(Mono|Flux)" W) { h["reactor-import"] = 1 }
    /^[[:space:]]*import[[:space:]]+org\.mapstruct\./ { h["mapstruct-import"] = 1 }
    /^[[:space:]]*import[[:space:]]+org\.modelmapper\./ { h["modelmapper-import"] = 1 }

    # --- Annotations (line-start anchored) ---
    $0 ~ ("^[[:space:]]*@CrossOrigin" W) { h["crossorigin"] = 1 }
    $0 ~ ("^[[:space:]]*@RestController" W) { has_restcontroller = 1 }
    $0 ~ ("^[[:space:]]*@Validated" W) { has_validated = 1 }

    # --- Non-/api mapping path (line-start anchored) ---
    /^[[:space:]]*@(Get|Post|Put|Delete|Patch|Request)Mapping[[:space:]]*\(/ {
      if (!bad_mapping && match($0, /"[^"]+"/)) {
        path = substr($0, RSTART+1, RLENGTH-2)
        if (path !~ /^\/api\//) {
          bad_mapping = path
        }
      }
    }

    # --- Substring patterns (rely on the comment-filter above) ---
    /Collectors\.toList\(\)/                       { h["collectors-tolist"] = 1 }
    /Executors\.newFixedThreadPool[[:space:]]*\(/  { h["executors-newfixed"] = 1 }
    /Executors\.newCachedThreadPool[[:space:]]*\(/ { h["executors-newcached"] = 1 }
    /CompletableFuture\.supplyAsync[[:space:]]*\(/ { h["completablefuture-async"] = 1 }
    /ThreadLocal\.withInitial[[:space:]]*\(/       { h["threadlocal-withinitial"] = 1 }

    END {
      if (has_restcontroller && has_validated) h["validated-restcontroller"] = 1
      # Stable output order that matches the original sequential-grep order.
      split("nullness-jsr305 nullness-jetbrains nullness-findbugs collectors-tolist manual-logger crossorigin validated-restcontroller bad-mapping reactor-import mapstruct-import modelmapper-import executors-newfixed executors-newcached completablefuture-async threadlocal-withinitial", order, " ")
      for (i = 1; i in order; i++) {
        if (order[i] == "bad-mapping" && bad_mapping) print order[i] "\t" bad_mapping
        else if (order[i] != "bad-mapping" && h[order[i]]) print order[i]
      }
    }
  ' "$FILE" 2>/dev/null)

  [[ -z "$labels" ]] && return 0

  # Label → message map. `bad-mapping` is special-cased because the path is
  # interpolated at runtime.
  local -A MSG=(
    [nullness-jsr305]="legacy JSR-305 nullness annotation (javax.annotation.*) — use JSpecify @Nullable / NullMarked (.claude/rules/code-style.md § \"Null safety\")"
    [nullness-jetbrains]="JetBrains nullness annotation (org.jetbrains.annotations.*) — use JSpecify @Nullable / NullMarked (.claude/rules/code-style.md § \"Null safety\")"
    [nullness-findbugs]="FindBugs/SpotBugs nullness annotation (edu.umd.cs.findbugs.annotations.*) — use JSpecify @Nullable / NullMarked (.claude/rules/code-style.md § \"Null safety\")"
    [collectors-tolist]="Collectors.toList() — prefer Stream.toList() which returns an unmodifiable list (.claude/rules/code-style.md § \"Functional style\")"
    [manual-logger]="manual LoggerFactory import — use Lombok @Slf4j instead of LoggerFactory.getLogger() (.claude/rules/code-style.md § \"Logging\")"
    [crossorigin]="@CrossOrigin on controller — CORS is handled centrally in SecurityConfig; per-controller @CrossOrigin bypasses the security filter chain (.claude/rules/rest.md § \"URI design\")"
    [validated-restcontroller]="@Validated alongside @RestController — Spring MVC 7 validates @RequestParam/@PathVariable natively; adding @Validated causes double-validation (.claude/rules/rest.md § \"Controller responsibilities\")"
    [reactor-import]="import reactor.core.publisher.(Mono|Flux) — virtual threads make reactive unnecessary; write straightforward synchronous code instead (.claude/rules/virtual-threads.md § \"Do NOT\")"
    [mapstruct-import]="import org.mapstruct.* — no mapping frameworks; write explicit mappings at boundaries (.claude/rules/code-style.md § \"Modeling and framework boundaries\")"
    [modelmapper-import]="import org.modelmapper.* — no mapping frameworks; write explicit mappings at boundaries (.claude/rules/code-style.md § \"Modeling and framework boundaries\")"
    [executors-newfixed]="Executors.newFixedThreadPool( — no fixed thread pools for IO-bound work; virtual threads handle IO concurrency (.claude/rules/virtual-threads.md § \"Do NOT\")"
    [executors-newcached]="Executors.newCachedThreadPool( — no cached thread pools for IO-bound work; virtual threads handle IO concurrency (.claude/rules/virtual-threads.md § \"Do NOT\")"
    [completablefuture-async]="CompletableFuture.supplyAsync( — do not introduce callback/async patterns to avoid blocking; blocking is fine on virtual threads (.claude/rules/virtual-threads.md § \"Do NOT\")"
    [threadlocal-withinitial]="ThreadLocal.withInitial( — custom ThreadLocal with virtual threads causes memory pressure; use Spring's context propagation (RequestAttributes, SecurityContextHolder, MDC) (.claude/rules/virtual-threads.md § \"Do NOT\")"
  )

  local hits=() label path
  while IFS=$'\t' read -r label path; do
    if [[ "$label" == "bad-mapping" ]]; then
      hits+=("REST mapping path \"$path\" does not start with /api/ — all REST endpoints must live under the /api/ prefix (.claude/rules/rest.md § \"URI design\")")
    else
      hits+=("${MSG[$label]}")
    fi
  done <<< "$labels"

  if ((${#hits[@]} > 0)); then
    local first=true h out=""
    for h in "${hits[@]}"; do
      if $first; then
        out="VIOLATION: ${bn}.java: $h"
        first=false
      else
        out="${out}\n\nVIOLATION: ${bn}.java: $h"
      fi
    done
    printf '%s' "$out"
  fi
  return 0
}

# -----------------------------------------------------------------------------
# check_session_block_structure
# Warns when a plan has more than 5 top-level `## Steps` items but no
# `### Block ` headers. Reads only the current file state — no diff needed.
#
# Silent when:
#   - ≤5 steps in `## Steps`
#   - at least one `### Block ` header exists
#
# Rule: exec-plans.md § "Session blocks" ("Plans with more than 5 steps")
# -----------------------------------------------------------------------------
check_session_block_structure() {
  [[ "$TOOL" == "Edit" || "$TOOL" == "Write" ]] || return 0
  [[ "$FILE" == *docs/exec-plans/active/*.md \
  || "$FILE" == *docs/exec-plans/completed/*.md ]] || return 0
  [ -f "$FILE" ] || return 0

  # Extract the ## Steps section (up to the next ## heading).
  local steps_section
  steps_section=$(awk '
    /^## Steps/ { inside = 1; next }
    /^## / { inside = 0 }
    inside { print }
  ' "$FILE" 2>/dev/null)
  [[ -z "$steps_section" ]] && return 0

  # Count top-level checklist items (exclude nested bullets with leading space).
  local count
  count=$(printf '%s\n' "$steps_section" \
    | grep -cE '^- \[( |~|x)\]' 2>/dev/null || true)
  [[ -z "$count" ]] && count=0

  [ "$count" -le 5 ] && return 0

  # Any `### Block ` header in the Steps section?
  if printf '%s\n' "$steps_section" | grep -qE '^### Block '; then
    return 0
  fi

  local name
  name=$(basename "$FILE")
  printf '%s' "Warning: ${name}: ${count} steps (>5) without session blocks — group into 3–5 step blocks. See .claude/rules/exec-plans.md § \"Session blocks\"."
  return 0
}

# -----------------------------------------------------------------------------
# check_openapi_annotations_present
# Enforces the cheaply regex-detectable subset of rest.md § "OpenAPI
# annotations (mandatory)" on any REST controller.
#
# Drift cases emitted as VIOLATION lines:
#   A. @RestController class with no @Tag( annotation anywhere in the file.
#   B. Any @<Verb>Mapping(...) line (Get/Post/Put/Delete/Patch) that lacks an
#      @Operation( annotation within the preceding 20 lines (the method-
#      annotation block is small in practice).
#
# Triggers on Edit|Write of:
#   - src/main/java/**/rest/*Controller.java
#   (any module's rest subpackage; file name must end in Controller.java)
#
# Carve-outs documented in the plan's decision log:
#   - operationId presence is NOT enforced. rest.md § "Accepted when"
#     explicitly exempts the notepad reference module from operationId, and
#     regex-matching operationId across multi-line @Operation(...)
#     annotations is fragile.
#   - URI prefix (/api/) is NOT duplicated here. check_style_scan already
#     flags @<Verb>Mapping("path") where path does not start with /api/.
#
# Rule: rest.md § "OpenAPI annotations (mandatory)"
# -----------------------------------------------------------------------------
check_openapi_annotations_present() {
  _guard_edit_write_java main || return 0
  [[ "$FILE" == */rest/*Controller.java ]] || return 0
  [ -f "$FILE" ] || return 0

  local bn
  bn=$(basename "$FILE" .java)
  local hits=()

  # --- Drift case A: @RestController without @Tag anywhere in the file ---
  if grep -Eq '^[[:space:]]*@RestController\b' "$FILE" 2>/dev/null \
     && ! grep -Eq '^[[:space:]]*@Tag[[:space:]]*\(' "$FILE" 2>/dev/null; then
    hits+=("${bn}.java: @RestController without @Tag — every controller must declare a Swagger @Tag. See .claude/rules/rest.md § \"OpenAPI annotations (mandatory)\".")
  fi

  # --- Drift case B: @<Verb>Mapping method with no @Operation in its block ---
  # Scan the file forward collecting the current method's annotation block.
  # An "annotation block" is the sequence of @Annotation lines (with optional
  # multi-line continuations and javadoc) that immediately precedes a method
  # signature. When we hit the method signature, if the collected block
  # contains @<Verb>Mapping but not @Operation, emit a VIOLATION for that
  # method. Resets the block on class/method body close.
  local bad_methods
  bad_methods=$(awk '
    function reset_block() {
      has_mapping = 0
      has_operation = 0
      mapping_verb = ""
      mapping_line = 0
    }
    BEGIN { reset_block() }
    # Blank line inside a block is fine; skip without resetting.
    /^[[:space:]]*$/ { next }
    # Skip javadoc and line comments — they can contain the string @Operation
    # without being an actual annotation.
    /^[[:space:]]*\/\// { next }
    /^[[:space:]]*\/\*/ { in_javadoc = 1 }
    in_javadoc {
      if ($0 ~ /\*\//) { in_javadoc = 0 }
      next
    }
    # Mapping annotation: remember verb and line, set has_mapping.
    # Note: mawk lacks `\b`, so we anchor by requiring the line to start
    # with `@<Verb>Mapping` followed by whitespace, `(`, or end-of-line.
    /^[[:space:]]*@(Get|Post|Put|Delete|Patch)Mapping([[:space:]]|\(|$)/ {
      has_mapping = 1
      mapping_line = NR
      verb = $0
      sub(/^[[:space:]]*@/, "", verb)
      sub(/Mapping.*/, "", verb)
      mapping_verb = verb
      next
    }
    # Operation annotation: any position within the same block counts.
    /^[[:space:]]*@Operation[[:space:]]*\(/ {
      has_operation = 1
      next
    }
    # Other annotation: still part of the current block, just ignore.
    /^[[:space:]]*@/ { next }
    # Any other non-blank line ends the current annotation block. The first
    # non-annotation line following a block is either a method signature,
    # a field, or a nested type. Only method signatures matter for this
    # check: they match `name(` somewhere in the line.
    {
      if (has_mapping && !has_operation) {
        # Try to extract the method name: the last identifier followed by (.
        line = $0
        name = ""
        # Scan right-to-left for the last `identifier(` token on this line,
        # preferring names that sit at the start of a parameter list.
        n = split(line, words, /[^A-Za-z0-9_]+/)
        for (i = n; i >= 1; i--) {
          if (words[i] ~ /^[A-Za-z_][A-Za-z0-9_]*$/ \
              && words[i] != "if" \
              && words[i] != "for" \
              && words[i] != "while" \
              && words[i] != "switch" \
              && words[i] != "catch" \
              && words[i] != "return" \
              && words[i] != "class" \
              && words[i] != "new") {
            # Confirm this identifier is immediately followed by `(` in the
            # original line (no space permitted — method names and `(` are
            # adjacent in practice).
            if (index(line, words[i] "(") > 0) {
              name = words[i]
              break
            }
          }
        }
        if (name == "") {
          name = "<line " mapping_line ">"
        }
        print mapping_verb "\t" name
      }
      reset_block()
      next
    }
  ' "$FILE" 2>/dev/null)

  if [[ -n "$bad_methods" ]]; then
    local verb_hit name_hit
    while IFS=$'\t' read -r verb_hit name_hit; do
      [[ -z "$verb_hit" ]] && continue
      hits+=("${bn}.java: ${name_hit}() uses @${verb_hit}Mapping without a preceding @Operation annotation. Every operation must document itself via @Operation. See .claude/rules/rest.md § \"OpenAPI annotations (mandatory)\".")
    done <<< "$bad_methods"
  fi

  if ((${#hits[@]} > 0)); then
    local first=true h out=""
    for h in "${hits[@]}"; do
      if $first; then
        out="VIOLATION: $h"
        first=false
      else
        out="${out}\n\nVIOLATION: $h"
      fi
    done
    printf '%s' "$out"
  fi
  return 0
}

# -----------------------------------------------------------------------------
# check_jacoco_config_guard
# PostToolUse warning fired on Edit|Write of pom.xml when the diff has touched
# any JaCoCo plugin configuration line (plugin declaration, thresholds,
# counters, or jacoco.* properties). Uses a per-line regex over the diff
# rather than XML-ancestor analysis — per the plan's risk table, false
# positives on large pom edits are preferable to false negatives.
# Rule: jacoco-coverage.md
# -----------------------------------------------------------------------------
check_jacoco_config_guard() {
  [[ "$TOOL" == "Edit" || "$TOOL" == "Write" ]] || return 0
  [[ "$FILE" == *pom.xml ]] || return 0
  local diff_output
  diff_output=$(cd "$REPO_ROOT" && git diff HEAD -- pom.xml 2>/dev/null)
  [[ -z "$diff_output" ]] && return 0
  if echo "$diff_output" \
       | grep -E '^[+-][^+-]' \
       | grep -qE 'jacoco-maven-plugin|<jacoco\.|</jacoco|COVEREDRATIO|<minimum>|<counter>(LINE|BRANCH)</counter>'; then
    printf '%s' "VIOLATION: You edited the JaCoCo plugin configuration in pom.xml — this violates .claude/rules/jacoco-coverage.md. JaCoCo thresholds are a project-level quality gate. Revert unless the user explicitly approved the change. If a threshold truly must move, document the rationale in the plan's decision log and state the user approval."
  fi
  return 0
}

# -----------------------------------------------------------------------------
# check_migration_edit_guard <repo-root>
# BLOCKING pre-commit guard: refuses to let a modified migration file
# through. Unlike the other checks in this library, this function does NOT
# use the dispatcher contract — it is invoked by .git/hooks/pre-commit
# (installed via scripts/harness/install-git-hooks), takes a repo root as
# its only positional argument, writes its block message to STDERR, and
# returns non-zero to abort the commit. It is NOT added to the
# post-tool-hook CHECKS list.
# Rule: persistence.md § "Schema management — Flyway"
# -----------------------------------------------------------------------------
check_migration_edit_guard() {
  local repo_root="${1:-$PWD}"
  local diff_output
  diff_output=$(cd "$repo_root" && git diff --cached --name-status -- src/main/resources/db/migration/ 2>/dev/null)
  [[ -z "$diff_output" ]] && return 0

  local modified
  modified=$(echo "$diff_output" | awk '$1 == "M" { print $2 }')
  [[ -z "$modified" ]] && return 0

  {
    echo "BLOCKED: migration file(s) modified — never edit an applied migration; create V<n+1>."
    echo "$modified" | sed 's/^/  - /'
    echo ""
    echo "See .claude/rules/persistence.md § \"Schema management — Flyway\"."
    echo "Override with: git commit --no-verify (document the reason in the plan's decision log)."
  } >&2
  return 1
}
