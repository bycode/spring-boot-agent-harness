---
paths:
  - "pom.xml"
---

# JaCoCo coverage thresholds — DO NOT MODIFY

The JaCoCo coverage enforcement in `pom.xml` is a project-level quality gate. **Never** change the JaCoCo plugin configuration, including but not limited to:

- Coverage thresholds (`<minimum>` values for LINE and BRANCH)
- Counter types or value types
- Adding exclusions or lowering limits to make tests pass
- Removing or disabling the `check` execution goal
- Changing the plugin version without explicit user approval

If tests fail the coverage check, write more tests — do not weaken the gate.

## Known acceptable failures

JaCoCo coverage checks can fail for reasons unrelated to test quality. These are expected and do not warrant changing the plugin configuration:

- **No application code yet** — JaCoCo reports 0% when there are no classes to instrument. This is normal for a fresh project or early in a feature branch before production code is written. The check will pass once code and corresponding tests are added.
- **Only configuration/framework classes** — Classes like `@SpringBootApplication`, `@Configuration`, or `package-info.java` may not be exercised by unit tests. Coverage improves as real business code is added.
- **Mid-implementation state** — During active development you may have production code without tests yet. This is a transient state; finish the tests before considering the task complete.

In all these cases the correct response is to continue development, not to lower thresholds or add exclusions.
