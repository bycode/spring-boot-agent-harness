# Hook fixtures

Fixture-based tests for `scripts/harness/post-tool-hook` and the check
functions in `scripts/harness/lib/hook-checks.sh`.

Run with `scripts/harness/test-hooks`.

## Why fixtures

Every check in `hook-checks.sh` has a narrow blast radius (a single file
type or content pattern) but the cost of a false positive is high: when a
hook injects noise, the agent learns to ignore `additionalContext`. The
fixture runner exists to prove, per check, that:

1. The pattern fires when it should (positive)
2. It stays silent on clean content (content-negative)
3. It does not fire on a near-miss hiding in a comment or string
   literal (benign-near-miss)
4. The dispatcher's path guard is wired (wrong-path)

## Fixture format

A fixture is a **directory** anywhere under `scripts/harness/tests/hooks/`.
It is picked up by the runner if it contains a `case.json`.

```
tests/hooks/<check_name>/<category>-<short-label>/
├── case.json        (required) the tool-input JSON fed to post-tool-hook
├── content          (optional) bytes to place at the file_path from case.json
├── expect.txt       (required) expectations, one per line
└── plans/           (optional) fake active-plan .md files, seeded into
    PLAN-*.md        $REPO_ROOT/docs/exec-plans/active/ before the hook runs
```

### `case.json`

The literal JSON the runner pipes into `post-tool-hook`. Typically:

```json
{"tool_name":"Edit","tool_input":{"file_path":"{{TMPDIR}}/src/test/java/foo/FooTest.java"}}
```

The placeholder `{{TMPDIR}}` is replaced by the runner with the absolute
path of the temporary `$REPO_ROOT` it creates for this fixture. If the
fixture has a `content` file, the runner writes it to the resolved
`file_path` before invoking the hook.

For Bash-tool fixtures:

```json
{"tool_name":"Bash","tool_input":{"command":"scripts/harness/mvn test"}}
```

To simulate a completed Bash command's exit code, include `tool_result`:

```json
{"tool_name":"Bash","tool_input":{"command":"scripts/harness/mvn test"},"tool_result":{"exit_code":0}}
```

### `content`

If present, the runner creates the file at the `file_path` from
`case.json` and writes this file's bytes verbatim. Use this for
file-content-sensitive checks (test-file regex, Lombok deny-list, etc.).

### `expect.txt`

Line-per-expectation, anchored substring checks against the
`additionalContext` field of the hook's JSON output. Three forms:

- `+text` — `additionalContext` must contain `text`
- `-text` — `additionalContext` must NOT contain `text`
- `EMPTY` — `additionalContext` must be empty (the hook must emit nothing
  for this check to fire)

Lines starting with `#` and blank lines are ignored.

### `plans/`

Any `.md` file placed in this directory is copied into
`$REPO_ROOT/docs/exec-plans/active/` before the hook runs. Use this to
exercise `check_plan_progress` without depending on the repo's real
active plans.

## Required categories per check

Every `check_<name>` function added to `lib/hook-checks.sh` **must** ship
with four fixture directories:

| Category           | What it proves                                             |
|--------------------|------------------------------------------------------------|
| `positive-*`       | The check fires with the expected warning on a matching case |
| `content-negative-*` | The check stays silent when the content is clean            |
| `benign-near-miss-*` | The pattern anchor is tight enough to ignore comments / strings |
| `wrong-path-*`       | The dispatcher's path guard is wired — content matches but the path does not |

Categories that genuinely do not apply (e.g., a check with no path guard
has no meaningful `wrong-path` case) must be explicitly justified in a
`README.md` *inside the check's fixture directory*, naming which
categories are skipped and why.

## Adding a new check

1. Add the function to `scripts/harness/lib/hook-checks.sh`.
2. Append its name to the `CHECKS` list in `scripts/harness/post-tool-hook`.
3. Create `tests/hooks/<check_name>/` with all four fixture categories.
4. Run `scripts/harness/test-hooks` — green before you commit.
