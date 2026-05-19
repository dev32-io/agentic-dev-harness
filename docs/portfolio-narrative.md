# About this project

Why this harness exists, who it is for, and how it gets used in practice.

## The problem

Every Claude Code project I start tends to begin from zero. Rules get re-invented. Hooks get re-pasted from the last repo. A few good patterns from the previous project survive; most are quietly forgotten. Quality drifts. The same gotchas — logging caps, e2e matrix discipline, when to chunk a long string field — get rediscovered on schedule, project after project.

Without something to anchor the conventions, the agentic loop drifts too. The model is happy to write code in any style you have not constrained. Without rules, "any style" is what you get.

## The opinion

An agentic workflow needs a *substrate*. Not a chatbot wrapper, not a prompt library — a substrate. Rules in version control, hooks that fire on real events, a spec-driven flow that forces the definition of done into writing, and a feedback loop that promotes lessons learned back into the rules.

Those four things, taken together, ARE the substrate. Without them, the agentic loop is improvised every session. With them, the loop runs at the bar a senior engineer would set for themselves on a good day, every day.

## The contribution

This harness extracts that substrate into a public, composable, opinionated kit:

- `base/` — workflow-essential rules every project gets.
- `platforms/*` — stack-specific overlays (mobile, web, embedded, runtime).
- `hooks/` — quality-gate scripts that run on real events.
- `learnings/` — the T3/T4 tiers where in-flight observations live before they earn a rule.
- `install.sh` — composes `base/` + selected `platforms/*` into a target project's `.claude/`.

It is the sibling of [ccToolBox](https://github.com/dev32-io/ccToolBox), which ships the *skills* that consume what this harness installs: `/retro`, `/qa-session`, `/recall-test-knowledge`, `/frustration-check`, and the rest of the kit.

## Daily use

I use this stack daily across the projects I am actually building — mobile (Android + iOS), embedded (ESP32), and web. The rules in this repo ARE the rules running in those projects. When I hit a gotcha in one of them and decide it generalises, it gets promoted back here through a "learning to promote" issue, and the next project I install benefits from it.

The harness is sharpened in production, not maintained as a showpiece. That is the only reason it stays honest — if a rule does not pull its weight in real work, I find out fast and either tighten it, demote it, or delete it.

## What's next

I am shipping this publicly because it works for me, and because I think the substrate idea generalises beyond my own projects. The friendly invitation:

- Open an issue if a rule does not match how your stack actually works.
- PR a new platform overlay (the `chain.yaml` and frontmatter contract is small and documented).
- Propose a rule promotion when you keep hitting the same thing across multiple projects.

The harness gets better when more practitioners contribute. That is the whole bet.
