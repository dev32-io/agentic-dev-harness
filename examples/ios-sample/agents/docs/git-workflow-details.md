# Git Workflow — Details & Examples

This file expands `base/rules/git-workflow.md`. The rule defines
the bar; this doc shows a worked example of a feature branch from
start to merge with rebase, an interactive-rebase squash of WIP
commits, a bisect session locating a regression, and the two
anti-patterns (the do-everything PR, force-pushing to main).

## Worked example: feature branch from start to merge

A typical feature: adding rate-limiting to the login endpoint.

### Step 1 — cut the branch from current main

```bash
git checkout main
git pull --ff-only origin main
git checkout -b feat/login-rate-limit
```

### Step 2 — work, commit, push

```bash
# Edit code, write tests, run the local lint gate.
git add src/auth/rate-limit.ts tests/auth/rate-limit.test.ts
git commit -m "feat(auth): add login rate limit"

# Push the branch and set upstream.
git push -u origin feat/login-rate-limit
```

### Step 3 — keep the branch current with main

While your PR is open, `main` keeps moving. Before requesting
review, and again before merge, rebase onto current `main`:

```bash
git fetch origin
git rebase origin/main
# resolve any conflicts here, on the feature branch
git push --force-with-lease
```

Using `--force-with-lease` instead of bare `--force` is
non-negotiable: it refuses to push if someone else has pushed to
the branch since you last pulled. This catches the case where a
co-author has been working on the same branch — which is a
separate problem (see the "force-push" anti-pattern below).

### Step 4 — merge as fast-forward

In the PR UI, choose "Rebase and merge" (or equivalent). The
result on `main`:

```text
* a1b2c3d  feat(auth): add login rate limit       (HEAD -> main)
* 9876543  (previous commit on main)
```

No merge commit. The new commit sits cleanly on top, addressable
by its hash, bisectable, revertable as a single point.

### Step 5 — delete the branch

```bash
git checkout main
git pull --ff-only origin main
git branch -d feat/login-rate-limit
git push origin --delete feat/login-rate-limit
```

The branch existed for a single logical change; the change is now
on `main`; the branch is done.

## Worked example: interactive-rebase squash of WIP commits

During development the branch accumulates noise:

```text
* 8 commits on feat/login-rate-limit, top first:
e7f0a01  fix lint
b3c2d11  fix lint again
4451922  wip — token bucket
9988fc7  wip — tests passing locally
0066ab1  add docs
acdc789  pr feedback
ddee123  pr feedback
112233e  init rate limit
```

Eight commits, only THREE logical changes: implementation, tests,
docs. Before opening (or before merging) the PR, squash into the
three logical commits.

### Run interactive rebase against the merge base

```bash
git fetch origin
git rebase -i origin/main
```

In the editor, the commits appear in chronological order. Reorder
and mark them:

```text
pick    112233e  init rate limit
fixup   4451922  wip — token bucket
fixup   9988fc7  wip — tests passing locally
fixup   e7f0a01  fix lint
fixup   b3c2d11  fix lint again
reword  acdc789  pr feedback     # rewrite into the proper commit subject
pick    ddee123  pr feedback
pick    0066ab1  add docs
```

After the rebase, the branch has three commits:

```text
*  feat(auth): add login rate limit
*  test(auth): cover rate-limit edge cases
*  docs(auth): document rate-limit configuration
```

Each commit's subject is one sentence. Each commit stands alone:
the implementation commit passes its own tests, the test commit
extends coverage, the docs commit only touches docs. A reviewer
walking the diff commit-by-commit gets a sensible narrative; a
future bisect lands on the exact commit that introduced any
particular line.

### Why not leave the WIP commits?

`main`'s log is read by people who weren't there. "wip — tests
passing locally" tells them nothing six months from now. The
squashed history is the version of the story that survives.

## Worked example: bisect session for a regression

The dashboard's checkout-success rate dropped 5% on Tuesday.
Tuesday's release contained a merge of `main` with 40 commits
landed since Friday's known-good release. You need to find which
commit caused the regression.

### Step 1 — establish good and bad endpoints

```bash
git checkout main
git pull --ff-only

# A commit known to be good (Friday's release tag).
GOOD=v2024.10.18.1

# A commit known to be bad (current main, the dropped-rate state).
BAD=HEAD
```

### Step 2 — start the bisect

```bash
git bisect start
git bisect bad $BAD
git bisect good $GOOD
```

Git checks out the midpoint of the 40-commit range.

### Step 3 — run the verification at each step

You need a reproducible YES/NO answer at each commit. The team's
acceptance test is: run the e2e suite's `checkout-happy-path`
test. If it passes, the commit is "good"; if it fails or times
out, the commit is "bad."

```bash
# At each bisect step:
npm install                       # if deps changed, refresh them
npm run test:e2e -- checkout-happy-path
# pass → git bisect good
# fail → git bisect bad
```

Repeat. With 40 commits in the range, the bisect lands the
culprit in ~6 steps (log2(40) ≈ 5.3, rounded up).

### Step 4 — bisect reports the offender

```text
abc1234 is the first bad commit
commit abc1234
Author: ...
Date:   ...

    refactor(checkout): inline cart-total helper
```

The bisect's correctness depends on one rule that the rebase
protocol enforces: every commit on `main` is independently testable
because every commit is a fast-forward landing of a single logical
change. If `main` were a tangle of merge commits with WIP states,
bisect would land on a half-finished commit and the verification
step would be ambiguous.

### Step 5 — clean up

```bash
git bisect reset
```

This restores `main` to its previous tip. You now have a single
commit to revert or fix.

## Anti-pattern: the "do everything" PR

A PR titled `Various improvements and fixes` touches 30 files
across 5 unrelated features:

- A new rate-limit middleware.
- A refactor of the cart total calculation.
- A bump of the TypeScript version.
- Two unrelated bug fixes in the webhook handler.
- A copy edit on the README.

### Why it's broken

- **Review is unworkable.** The reviewer cannot hold five
  unrelated mental models at once. Each subsystem needs a
  different domain expert.
- **CI signal is muddied.** If the suite fails, which of the five
  changes caused it?
- **Revert is dangerous.** If one of the bug fixes turns out to be
  wrong in production, reverting the PR also reverts the rate
  limiter, the TS upgrade, and the README edit.
- **Bisect is useless.** When a regression appears, bisect lands
  on a commit that contains 5 distinct changes. You have to
  re-read the entire diff.

### Fix — split into five PRs

```text
feat/login-rate-limit         → PR #1: "feat(auth): add login rate limit"
refactor/cart-total-inline    → PR #2: "refactor(checkout): inline cart total"
chore/typescript-5.4          → PR #3: "chore: upgrade TypeScript to 5.4"
fix/webhook-idempotency       → PR #4: "fix(webhook): make handler idempotent"
fix/webhook-null-payload      → PR #5: "fix(webhook): handle null payload"
docs/readme-typo              → PR #6: "docs: fix typo in README"
```

Each PR is one sentence in the title, reviewable in 5–15 minutes,
revertable independently, and bisectable in isolation. Some can
land in parallel; others can stack. The author thinks once about
splitting; the team thinks much less per PR forever after.

## Anti-pattern: force-pushing to main

A developer notices that a commit on `main` had a typo in the
commit message. They do this:

```bash
git checkout main
git commit --amend -m "feat(auth): add login rate limit (fixed)"
git push --force origin main
```

### What just happened

- Every other developer who already pulled the old commit now has
  a divergent `main`. Their next `git pull` will either merge the
  old and new histories (a tangle) or refuse to fast-forward.
- CI may re-run on the rewritten commit and surface "this commit
  no longer exists" alerts on every PR that referenced it.
- Build artifacts and deployment systems may be tied to the old
  commit hash. The rewritten hash invalidates them silently.
- Bisects through this window of history are broken — the old
  commit hash is unreachable, and the new commit has a different
  timestamp and content.

### Fix — push a NEW commit, never rewrite shared history

```bash
git checkout main
git pull --ff-only
# Make whatever fix is actually needed (typo in code, not in
# commit message — commit messages on landed commits are
# part of the historical record).
git commit -m "docs(auth): clarify rate-limit comment"
git push origin main
```

If the original commit's message is genuinely problematic (leaked
a secret, contains a slur), the org's "history rewrite" process is
a coordinated, scheduled, communicated event — not a `--force`
push from one developer's machine. Treat shared history as
append-only by default.

## When in doubt

- "Is this a force-push to a shared branch?" → don't.
- "Is this PR one sentence?" → split until each piece is.
- "Is this a merge commit on main?" → rebase instead.
- "Is this commit message in imperative mood?" → if it starts with
  "Added" or "Fixed", rewrite it.

The discipline costs a few minutes per change and buys a clean,
bisectable, narratively coherent history for the lifetime of the
repo.
