---
name: Notepad module reference patterns
description: Patterns in the notepad reference module that are accepted per rules annotations, preventing future false positives
type: project
---

The notepad module is the reference implementation (documented in its contract header).

Accepted patterns specific to this module:
- rest.md has "Accepted when" annotation: "Controller returns domain type directly -> reference module notepad may simplify mapping for trivial cases." However, the current implementation does use DTOs, so this exception is not exercised.
- NullAway enforces null-safety at compile time. Do not flag @Nullable mismatches between domain and entity layers as findings -- if it compiles, NullAway already checked it.
- ArchUnit enforces @Transactional on all facade public methods. Do not flag missing @Transactional as a finding.

**Why:** These patterns recur and flagging them wastes audit time.
**How to apply:** Skip these checks on future audits of this module unless the accepted-when annotations change.
