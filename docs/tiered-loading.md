# Tiered context loading

How rules, details, and learnings are split into four tiers so an agent loads only what the current task actually needs.

## The four tiers

| Tier | What | When loaded | Writes via |
|------|------|-------------|-----------|
| **T1** | `rules/*.md` ≤100 LOC, atomic, paths-glob scoped | Always (per `paths:` frontmatter) | Manual + `/retro` promotion from T3 |
| **T2** | `docs/*-details.md` | On-demand by `recall-*` skills | `/retro` writes paired with T1 |
| **T3** | `learnings/learnings.md` | On testing/debug intent | `/retro` appends; promoted to T1/T2 once pattern emerges |
| **T4** | `learnings/testing-knowledge.md` | On test-write intent (`recall-test-knowledge` from ccToolBox) | `/qa-session` + `/retro` |

T1 is the LAW: short, imperative, always present when its glob matches. T2 is the CASE LAW: longer prose paired one-to-one with each T1 rule, pulled in only when needed. T3 is the journal of things we keep tripping over. T4 is the catalogue of test cases worth remembering.

## Worked example: a learning's journey to a rule

A concrete observation moves from T3 to T2 to T1 over weeks.

**Day 1 — project A.** A developer hits a `logtape` field-truncation cutoff at around 180 characters while logging the prompt sent to an LLM. The logs hide the very thing they were meant to debug. `/retro` runs at the end of the branch, sees the diff and the transcript, and proposes a T3 entry:

```
## 2026-05-04 — logtape truncates long string fields at ~180 chars
- Repro: log a 2KB prompt; only the first ~180 chars survive.
- Workaround in this branch: chunk the prompt into 150-char slices.
- Open question: is this generic across logtape sinks, or a sink-specific cap?
```

The entry lives in the project's `learnings/learnings.md`. Not in `base/`. Not promoted. Just noted.

**Day 30 — project B.** Different repo, different developer-pair (same human, a fresh agent session). Same truncation, this time on a tool-call argument dump. `/retro` notices the new T3 entry would echo the old one. The pattern is no longer project-specific — it is a generic property of `logtape`.

**Promotion PR.** The developer opens a "Learning to promote" issue using `.github/ISSUE_TEMPLATE/learning-to-promote.md`, then a PR against `agentic-dev-harness`:

- Adds a gotcha section to T2 `base/docs/logging-details.md` describing the cap, the repro, and the chunk-or-stringify workaround.
- Tightens the T1 `base/rules/logging.md` line: "Long string fields MUST be chunked or pre-formatted before logging; see details."
- Removes the dated T3 entry from both projects' `learnings/learnings.md` (it is no longer a local note — it is base-ruleset law).

**Day 90.** A third project is installed with `install.sh`. The logtape gotcha is already in its T1 rule and T2 details, inherited from `base/`. The new project never has to learn it the hard way.

## Why this matters

The four-tier split exists so that the always-loaded slice (T1) stays small and sharp, while the long tail of accumulated knowledge (T2/T3/T4) is reachable on demand. Without the demotion-and-promotion flow, T1 either bloats into an unreadable wall of text or stays frozen against reality. With it, rules earn their place: a T3 note has to survive multiple projects before it costs anyone any T1 budget.

This is what makes the harness a *living* artifact rather than a static template. Without the feedback loop, rules ossify and projects drift apart.
