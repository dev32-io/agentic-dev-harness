# agentic-dev-harness

> Wrap Claude Code with the rules, hooks, and scripts that make it ship at a senior bar.

## What it is

A composable Claude Code rules + hooks + scripts harness. Drop it into any project and the agentic workflow — `brainstorm → spec → plan → execute → verify → retro` — runs at a senior engineer's quality bar without operator intervention.

Pairs with [ccToolBox](https://github.com/dev32-io/ccToolBox), which provides the skills (`/retro`, `/qa-session`, `frustration-check`) that consume this harness.

## The 30-second install

```bash
# One-shot
curl -fsSL https://raw.githubusercontent.com/dev32-io/agentic-dev-harness/main/install.sh \
  | sh -s -- --target . --platforms web,bun
```

Or:

```bash
git clone https://github.com/dev32-io/agentic-dev-harness
sh agentic-dev-harness/install.sh --target ~/your-project --platforms android,ios
```

## What you get

- `base/rules/` — 7 workflow-essential rules (≤100 LOC each): clean-code, collaboration, e2e-testing, error-handling, git-workflow, logging, testing.
- `platforms/<p>/` — language/framework overlays. Pick what you use (typescript, mobile, android, ios, web, node, bun, python, esp32). Chains compose: `web` auto-includes `typescript`; `android` auto-includes `mobile`.
- `CLAUDE.md.template` — meta-gate forcing "MANDATORY — Read Rules First" header in every target project.
- `hooks/` — the two-hook CI pair (PostToolUse typecheck + TaskCompleted full gate) that gives the e2e mandate its teeth.
- `learnings/` — empty seeds for the project's growing T3/T4 catalogs.

## The e2e matrix is the contract

Every spec and every implementation plan written under this harness contains a concrete e2e test matrix. Definition of done is mechanical: every row green. This makes plans:

- **Model-portable.** Hand the plan to a different model (cheaper, faster, specialized) for execution. "Done" still means the same thing.
- **Human-portable.** Hand the plan to a developer working in a non-agentic IDE. The matrix + plan is a complete engineering brief.

See [`docs/workflow-and-skills.md`](docs/workflow-and-skills.md) for the full flow with diagrams.

## Tiered loading

Rules evolve. T1 atomic rules → T2 paired details → T3 dated learnings → T4 reusable test cases. `/retro` (from [ccToolBox](https://github.com/dev32-io/ccToolBox)) writes back into the loop. See [`docs/tiered-loading.md`](docs/tiered-loading.md).

## Recommended skills (use with [ccToolBox](https://github.com/dev32-io/ccToolBox))

> **`frustration-check`** — the headline pick. A `UserPromptSubmit` hook with tiered regex scoring that detects knowledge gaps and overconfidence cognitive traps — the most expensive failure mode of senior-with-AI collaboration. Injects a calm reflection prompt, surfaces drift, offers consent-gated knowledge lookups. The rarest piece in the public AI-tooling market. Maximizes AI-as-collaborator rather than letting it amplify the user's blind spots.

Full priority-ordered skill stack: see [`docs/workflow-and-skills.md`](docs/workflow-and-skills.md).

## Repo layout

```
base/{rules,docs}/        # workflow-essential, always loaded
platforms/<p>/            # language/framework overlays (chained)
hooks/                    # quality-gate.sh + settings.example.json
learnings/                # T3/T4 seeds
CLAUDE.md.template        # meta-gate for target projects
install.sh                # POSIX-sh bootstrap
examples/                 # 3 working samples (android, ios, web-bun)
docs/                     # 6 explainers
tests/                    # lint-rules.sh + install-test.sh
```

## Status

**v0.1** — initial public release. Mobile platforms (android, ios) are the most complete (full rule set + paired details + qa oracles + sample charters + working sample). Web/node/bun mid-tier (chained via the shared typescript overlay). Python/esp32 leaner — `(PRs welcome to deepen)`.

The harness is sharpened in production daily; expect frequent updates as patterns generalize via `/retro` promotions.

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md). Three flows: add a platform, propose a base rule, promote a learning. Issue templates under `.github/ISSUE_TEMPLATE/`.

## License

MIT.
