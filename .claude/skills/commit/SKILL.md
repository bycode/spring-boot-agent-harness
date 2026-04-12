---
name: commit
description: Create atomic, well-grouped git commits from the current working tree, push them on a feature branch, and open a pull request on GitHub. Use this skill whenever the user says "commit", "/commit", "commit my changes", "make commits", "commit all", or any variation of asking to commit their work. Also trigger when the user says things like "save my progress" or "wrap this up" in a git context.
user_invocable: true
---

# Atomic Commit + PR Skill

You are creating a series of small, logical, atomic commits from the current working tree, then pushing them on a feature branch and opening a pull request. Each commit should represent exactly one coherent change — something a reviewer could understand in isolation.

## Why atomic commits matter

A good commit history is a communication tool. Each commit tells a story: "here is one thing that changed, and here is why." When commits are atomic, `git bisect` works, reverts are safe, and code review is pleasant. When commits are kitchen-sink dumps, all of that breaks down.

## Safety rules — non-negotiable

- **Never** force-push (`git push -f`, `--force`, `--force-with-lease`)
- **Never** push directly to the default branch (`master`, `main`)
- **Never** use `--no-verify` to skip hooks
- **Never** `--amend` a commit that has already been pushed
- **Never** stage files that look like secrets (`.env`, `credentials.*`, `*.pem`, tokens)
- **Never** use `git add -A` / `git add .` — always stage specific files by name
- **Never** partially stage with `git add -p`; if a file mixes related and unrelated changes, tell the user and ask

## Step 1: Inspect the working tree

Run these in parallel:

```bash
git status                     # all changed, staged, and untracked files
git diff                       # unstaged changes (full content)
git diff --cached              # staged changes (if any)
git log --oneline -10          # recent commit style to match
git branch --show-current      # where we are now
git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@'  # default branch
```

Read through every change carefully. You need to understand every file before you can group them.

## Step 2: Decide branch strategy

Branch behavior is driven entirely by the current branch:

- **On the default branch (`master`/`main`):** You MUST create a new feature branch before committing. Generate a short kebab-case slug from the primary change topic and prefix it with `feature/`. Examples: `feature/commit-skill-pr-flow`, `feature/fix-utf8-bom-parse`, `feature/extract-plan-progress-hook`. Keep the slug under ~40 characters. Don't create the branch yet — wait for the Step 5 confirmation.
- **On an existing feature branch:** Commit on the current branch. No new branch. Step 7's push will update the existing upstream (or set it if missing).
- **Detached HEAD or no `origin` remote:** Skip push and PR entirely. Commit locally, report the state at the end, and stop.

## Step 3: Plan the commit groups

Group changes by logical cohesion — files that are part of the same conceptual change belong together.

**What makes a good group:**
- A bug fix + its test = one commit
- A new feature's production code + its tests + its migration = one commit
- A rename/refactor that touches many files but does one thing = one commit
- Config/infra changes unrelated to feature work = separate commit

**What does NOT belong together:**
- An unrelated formatting fix lumped with a feature
- A dependency update mixed with a bug fix
- Test fixture updates that serve a different change than the main code

**Ordering matters:** Put foundational changes first. Schema migrations before code that uses them. Dependency additions before code that imports them. Each commit should compile and pass tests on its own when possible.

**Typical group patterns** (not exhaustive — use judgment):
1. Build/dependency/config changes
2. Schema migrations + domain model changes
3. Core feature or bug fix (production code + tests)
4. Test fixture or test infrastructure updates
5. Documentation, specs, contract updates

Aim for 2-7 commits for a typical feature. Don't over-split (one commit per file is too granular) and don't under-split (everything in one commit defeats the purpose).

## Step 4: Draft commit messages

Follow the commit message conventions visible in `git log`. If no clear convention exists, use this format:

```
<summary line: imperative mood, what and why, under 72 chars>

<optional body: explain motivation, context, or non-obvious decisions>

Co-Authored-By: Claude <noreply@anthropic.com>
```

**Summary line rules:**
- Imperative mood: "Fix bug" not "Fixed bug" or "Fixes bug"
- Focus on **why** over **what** when the diff makes the "what" obvious
- Be specific: "Fix UTF-8 BOM causing XML parse failure" not "Fix bug"
- Under 72 characters — if you can't fit it, the commit is probably doing too much

**When to add a body:**
- The "why" isn't obvious from the diff
- There are non-obvious design decisions worth explaining
- The change has broader context (e.g., "Part of the bulk harvest resilience work")

Skip the body for self-explanatory changes.

## Step 5: Confirmation gate — stop and wait

Before creating any branch, making any commit, or running any push, output the full plan and wait for the user's explicit go/no-go. **This is the only approval gate** — everything after this runs without further prompts.

If we're on a feature branch (not the default branch), check for an existing PR first so the plan can show it:

```bash
gh pr view --json url,state 2>/dev/null
```

Then print the plan in this exact shape:

```
Current branch: <current>
Branch action:  create feature/<slug> from <default>
                  — or —
                reuse <current>
                  — or —
                local-only (detached HEAD / no origin remote)

Planned commits:
  1. <summary>
  2. <summary>
  3. <summary>

Existing PR on this branch: <URL>  |  none  |  n/a (new branch)

Draft PR title: <summary of the commit that best describes the PR —
                usually the one implementing the primary change, not
                necessarily the first commit in order>

Proceed with commits + push + PR? (y/n)
```

**End your turn here.** Output the plan and wait for the user's next message. If they say no or ask for changes, adjust the plan and re-confirm. Do not commit, branch, push, or create a PR until the user explicitly approves.

## Step 6: Create branch and commit

If Step 2 chose a new branch, create it now:

```bash
git checkout -b feature/<slug>
```

Then stage and commit each group. Use HEREDOC for the message to preserve formatting:

```bash
git add <file1> <file2> ...
git commit -m "$(cat <<'EOF'
Summary line here

Optional body here.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

Stage specific files by name (see safety rules). If a pre-commit hook fails: fix the issue and create a NEW commit. Do not `--amend` to paper over hook failures.

## Step 7: Push the branch

If the branch was freshly created in Step 6, set upstream:

```bash
git push -u origin feature/<slug>
```

If the branch already tracks a remote (the user was already on a feature branch with upstream set), plain push:

```bash
git push
```

If the push fails (network, auth, non-fast-forward, protected branch), **stop**. Report the failure verbatim. Do NOT reset, stash, delete commits, or retry with `--force`. The commits stay on the local branch; the user can resolve and re-push manually.

## Step 8: Create or update the PR

Only if we're on a feature branch with a successful push behind us. Check for an existing open PR:

```bash
gh pr view --json url,state 2>/dev/null
```

- **PR exists and is open:** The Step 7 push already updated it. Capture the URL for the report — do NOT run `gh pr create`.
- **No PR exists:** Create one against the default branch detected in Step 1:

```bash
gh pr create --base <default-branch> --head feature/<slug> --title "<PR title>" --body "$(cat <<'EOF'
## Summary
- <bullet per commit: use commit summary lines>

## Test plan
- [ ] scripts/harness/full-check
EOF
)"
```

If `gh pr create` fails (not authenticated, rate limited, network), report the exact failure. The branch is already pushed — the user can open the PR manually from the compare URL that `git push -u` printed on stderr. Do not retry with different flags or arguments.

Don't pre-check `gh auth status`. `git push` uses git (not gh) so it may succeed even when gh is unauthenticated. Try each step and handle its failure on its own.

## Step 9: Report

Print a short, factual summary:

- Commits made (count + summary lines)
- Branch name
- Push status: `pushed to origin` | `failed: <reason>` | `skipped: local only`
- PR status: `<URL>` | `existing: <URL>` | `failed: <reason>` | `skipped: local only`

Then stop.

## Edge cases

- **No changes:** If the working tree is clean, say so and stop. Don't create a branch.
- **Only staged changes:** Respect what the user already staged — commit those first, then ask about unstaged changes before continuing.
- **Sensitive files:** If you spot `.env`, credentials, or tokens in the changeset, warn the user and exclude them.
- **Single logical change:** If all changes are one coherent unit, one commit is fine. Don't split artificially.
- **User says no at the confirmation gate:** Stop completely. Do not commit, branch, push, or create a PR. Leave the working tree exactly as you found it.
- **Partial failure (e.g., commits made, push failed):** Do not try to clean up by resetting or stashing. Report current state and let the user decide.
