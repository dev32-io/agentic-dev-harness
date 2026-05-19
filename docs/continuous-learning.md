# Continuous learning

How `/retro` closes the loop between everyday project work and the harness itself, so the rules sharpen over time instead of ossifying.

## The feedback loop

```
project work happens
  → /retro reads diff + transcript
  → proposes T1/T2/T3/T4 update candidates
  → user approves per-candidate (table-driven UI)
  → writes back to target's .claude/rules/ + agents/docs/
  → next session: recall-* skills pull updated context
  → harness gets sharper
  → periodic generalizations PR'd back to agentic-dev-harness/base/
```

Each step matters. `/retro` does not silently rewrite rules — it proposes a table of candidates per tier, the human approves them one by one, and only approved candidates are written. The result is a small, reviewable change set per branch, not a runaway "AI rewrites my conventions" loop.

## Worked example: logtape truncation

A concrete pass through the loop, framed around what `/retro` actually does.

**Branch context.** A developer just shipped a feature on `feature/llm-prompt-logging` in project A. During development they hit the `logtape` ~180-character field-truncation cutoff and chunked the prompt at log time. The chunk-and-log workaround is in the diff; the discovery is in the session transcript.

**`/retro` runs.** It reads:
- `git diff main...HEAD` — sees the chunking helper and the call sites.
- The current session transcript — sees the developer's "wait, logtape is silently truncating?" moment and the workaround they landed on.

**`/retro` proposes (table-driven).** A T3 candidate for `learnings/learnings.md`:

```
## 2026-05-04 — logtape truncates long string fields at ~180 chars
- Repro: log a 2KB prompt; only the first ~180 chars survive.
- Workaround: chunk the prompt before passing to the logger.
- Generic enough to promote? Not yet — single project, single repro.
```

It does NOT propose a T1 rule change yet, and it does NOT propose a T2 details edit. One observation is not a pattern. The candidate is appended to T3 only, and the developer approves it.

**Day 30, project B.** Same human, fresh agent, different repo. Same truncation, different field. `/retro` notices the candidate it is about to write to T3 in project B *echoes* an existing T3 entry in project A. (`/retro` is aware of the developer's previous entries because the table-driven UI surfaces near-duplicates.) Now the pattern is generic.

**Promotion.** The developer opens an issue against `agentic-dev-harness/` using `.github/ISSUE_TEMPLATE/learning-to-promote.md`, then a PR that:
- Adds a gotcha section to T2 `base/docs/logging-details.md`.
- Tightens the T1 `base/rules/logging.md` to require chunking-or-pre-formatting for long string fields.
- Removes the dated T3 entry from both projects.

The next `install.sh` run on a new project inherits the rule and the details.

## Linked skills (from ccToolBox)

- **`/retro`** — analyses the branch diff and the current-session transcript, proposes per-tier updates with table-driven approval. Writes only what the user approves. Lives in [ccToolBox](https://github.com/dev32-io/ccToolBox).

- **`/recall-test-knowledge`** — reads the T4 catalogue (`learnings/testing-knowledge.md`) and injects relevant entries into the current session when the user's intent is test-writing or test-planning. The complement to T4 writes: `/retro` puts cases in, `/recall-test-knowledge` pulls them back out.

Other useful members of the same family (also in ccToolBox): `/qa-session` (writes to T4 via charter findings), `/skill-distill` (turns a successful session into a reusable skill).

## Why this matters

Without `/retro`, the harness ossifies. Rules written in the first month of a project never get refined, even as the team keeps tripping over the same edge cases. Worse: each new project rediscovers the same gotchas from scratch, because the lessons stayed in heads or in PR comments and never made it into a rule file.

With `/retro`, every project sharpens the harness, and every install of the harness benefits from every previous project's mistakes. The flywheel only spins if the loop is actually closed.

The harness is a *living* artifact, not a static template.
