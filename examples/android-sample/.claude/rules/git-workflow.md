---
description: Feature branches off main, linear history, small PRs, conventional-commit messages, no force-push to shared branches.
---

# Git Workflow

Git history is the project's externalized memory. An agent reading
`git log` six months from now must be able to reconstruct what
changed, why, and in what order. Tangled merges, sprawling PRs,
and rewritten shared branches all destroy that signal.
When a rule is unclear, see `base/docs/git-workflow-details.md`.

## Feature branches off main

- All work happens on a feature branch cut from `main`. Never
  commit directly to `main` (or `develop`, `release/*`, or any
  other shared branch).
- Branch name format: `<type>/<short-kebab>`. The type matches the
  conventional-commit prefix list: `feat`, `fix`, `refactor`,
  `docs`, `chore`, `test`.
- Examples: `feat/login-rate-limit`, `fix/session-refresh-race`,
  `refactor/payment-input-split`, `chore/upgrade-tsconfig`.
- One branch per logical change. If a branch grows two
  responsibilities, split it.

## Linear main, rebase before merge

- `main` is a LINEAR history. No merge commits on `main`.
- Before merging a feature branch into `main`: rebase the branch
  onto current `origin/main`, resolve conflicts ON THE FEATURE
  BRANCH, then fast-forward into `main`.
- A merge commit on `main` ("Merge branch 'feat/...' into main")
  is a smell — it means somebody clicked "Create a merge commit"
  in the PR UI instead of rebasing first.
- Feature branches MAY pull `main` in via merge during development
  if rebasing mid-flight is disruptive. Squash or rebase before
  opening the PR.

## One logical change per PR

- A logical change is what you'd describe in ONE SENTENCE in the
  PR title. If you need "and" twice, it's two changes.
- Multi-purpose PRs get bounced. Split into N smaller PRs, each
  one-sentence describable, stacked or sequential.
- Small PRs review faster, revert cleaner, bisect more usefully,
  and force the author to think about what actually changed.

## Commit message format

- Conventional Commits prefix:
  `<type>(<scope>): <imperative subject>`.
- Subject: imperative mood ("Add login rate limit", NOT "Added"
  or "Adds"). Capitalized first letter. No trailing period.
  ≤72 characters.
- Body (optional but expected for non-trivial commits): blank
  line after the subject, prose wrapped at 72 chars, explains the
  WHY. The WHAT is in the diff; the body says why the diff is
  what it is.
- Example subjects: `feat(auth): add login rate limit`,
  `fix(session): close race in refresh handler`,
  `refactor(payments): split input parsing from provider calls`.

## Force-push policy

- Force-push is ALLOWED on personal feature branches (after rebase,
  squash, fixup). Use `--force-with-lease`, never bare `--force`.
- Force-push is FORBIDDEN on `main`, `develop`, `release/*`, or
  any branch with multiple authors. Rewriting shared history
  silently destroys other contributors' local work.
- If you must "undo" a commit on a shared branch, push a new
  revert commit. Never rewrite the timeline others have pulled.

## Pre-merge rebase, not merge-commit

The merge ritual onto `main`:

1. `git fetch origin`
2. On the feature branch: `git rebase origin/main`
3. Resolve conflicts ON THE FEATURE BRANCH. Push the rebased
   branch (`git push --force-with-lease`).
4. Re-run tests and the lint gate on the rebased branch.
5. Merge as fast-forward into `main` (`git merge --ff-only`, or
   the PR UI's "Rebase and merge" option).

The result: `main`'s history is a clean sequence of fast-forward
landings, each one a one-sentence-describable change.
