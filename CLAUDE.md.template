# {{PROJECT_NAME}}

## MANDATORY — Read Rules First

This project uses the [agentic-dev-harness](https://github.com/dev32-io/agentic-dev-harness) rule system.

Before exploring or modifying code, read all rules in `.claude/rules/`.

- **Top-level files** (`.claude/rules/*.md`) are workflow-essential rules and are loaded always.
- **Subdirectories** (`.claude/rules/<platform>/`) hold platform-specific rules. Each declares a `paths:` glob in YAML frontmatter; Claude Code auto-loads the matching rules when files matching that glob are touched.

## Companion docs

- `agents/docs/<rule-name>-details.md` — expands each rule with examples, gotchas, and FAQs.
- `agents/docs/learnings.md` — recent observations not yet promoted to rules.
- `agents/docs/testing-knowledge.md` — the reusable case catalog. **Spec matrices reference cases here by name; never duplicate.**

## Workflow contract

```
idea → /brainstorming → spec (with e2e matrix)
     → /writing-plans → plan (with e2e matrix)
     → /executing-plans → implementation
     → /verification-before-completion → all-green
     → /requesting-code-review → /finishing-a-development-branch → handoff
     → /retro (back into the rules)
```

**The e2e test matrix is the contract.** Every spec and every plan ships with a concrete e2e matrix. "Done" means every row is green. This applies whether the executor is this agent, a different model, or a human developer.

## Quality gates

Two hooks enforce the rules:

- **PostToolUse** — every `Write`/`Edit` triggers `scripts/quality-gate.sh typecheck`.
- **TaskCompleted** — every task close triggers `scripts/quality-gate.sh all`.

A red gate means the task is not done.

## Architecture

{{PROJECT_ARCHITECTURE_NOTES}}

> Replace this section with project-specific architecture context (key patterns, surface boundaries, named flows). Keep it under 30 lines — long architecture docs live in `docs/`, not here.
