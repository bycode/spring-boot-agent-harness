# check_test_reminder fixtures

Only three of the four mandatory fixture categories apply here:

- `positive-production-class` — matching path (`src/main/java/**/*.java`) plus a
  real class name → reminder fires.
- `content-negative-package-info` — matching path but the basename is
  `package-info`, which the check explicitly ignores → no output.
- `wrong-path-test-file` — file is under `src/test/java` (not `src/main/java`),
  so the dispatcher's path guard must skip the check → no output.

**`benign-near-miss` is skipped:** `check_test_reminder` inspects no file content
at all — only the `file_path`. There is no pattern inside the file that could
hide in a comment or string literal, so the near-miss category is not meaningful
for this check.
