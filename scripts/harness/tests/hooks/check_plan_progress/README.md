# check_plan_progress fixtures

These fixtures pin the regression format of the `EXEC PLAN CHECKPOINT:` chunk
so later refactors cannot silently drift its shape. Each fixture seeds a fake
plan file via `plans/PLAN-0099-fake.md` and then runs the hook with a tool
call that should trigger the plan-progress check.

| Fixture                        | Category         | Proves                                                |
|--------------------------------|------------------|-------------------------------------------------------|
| `positive-no-in-progress`      | positive         | Missing `[~]` marker emits the VIOLATION line         |
| `positive-over-limit`          | positive         | 13-step plan emits the 12-step-limit VIOLATION line   |
| `content-negative-in-progress` | content-negative | Plan with a `[~]` marker is clean (no VIOLATION)      |
| `wrong-tool-no-build-command`  | wrong-path proxy | `Bash` tool with a non-build command is skipped       |

`benign-near-miss` and a literal `wrong-path` category do not apply here:

- The check reads plan files, not the currently edited file's content, so there
  is no "pattern hiding in a comment" scenario.
- The check's "path" is really its tool filter (`Edit`/`Write` or build-ish
  `Bash` commands). The `wrong-tool-no-build-command` fixture covers the
  dispatcher-guard equivalent by firing a `Bash` call with a non-build
  command and asserting the check stays silent.
