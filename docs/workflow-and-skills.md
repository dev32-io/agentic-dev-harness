# Workflow and skills

The spec-driven flow this harness is built around, and the skills that make it actually work day to day.

## The spec-driven flow

```
idea
  → /brainstorming         (rules force e2e matrix into spec)
  → spec + e2e matrix
  → /writing-plans         (rules force e2e matrix into plan, broken down by step)
  → plan + e2e matrix      ← SELF-CONTAINED, MODEL- AND HUMAN-PORTABLE
  → /executing-plans       (any model — or a human — can execute; e2e matrix is the contract)
  → implementation
  → /verification-before-completion  (every e2e matrix row green, no exceptions)
  → all-green
  → /requesting-code-review → /finishing-a-development-branch → handoff
  → /retro  (promotes learnings back into the harness)
```

The flow is deliberately ceremonial in the early stages so the late stages can be mechanical. The e2e matrix is forced into both the spec and the plan; by the time anyone (model or human) starts implementing, the definition of done is no longer up for debate.

## The e2e matrix is the contract

The e2e matrix is a flat list of user-observable acceptance scenarios. It sits inside the spec and is copied, expanded, and step-mapped inside the plan. Two properties make it the centre of gravity:

1. **Definition of done is mechanical.** "All matrix rows green" is binary. No "looks done to me" judgement call. `/verification-before-completion` literally walks the matrix.
2. **Plan portability across models and humans.** A plan with an e2e matrix can be picked up by a different model — or a different human — in a fresh session, and the contract still holds. The plan does not depend on the originating session's context to be executable.

This is what makes "AI does the work, human reviews" not a meme but a workflow: there is a written contract everyone agrees on before any code is written.

## Recommended skill stack

1. **Anthropic `superpowers` family (required for the workflow):** `brainstorming`, `writing-plans`, `executing-plans`, `verification-before-completion`, `requesting-code-review`, `finishing-a-development-branch`, `systematic-debugging`, `subagent-driven-development`, `dispatching-parallel-agents`.

2. **`ccToolBox/frustration-check` — THE headline pick.**

   > A `UserPromptSubmit` hook with tiered regex scoring (constraint-repeat / rage / contradiction / self-realization) that detects when the user is hitting a **knowledge gap** or falling into the **cognitive trap of overconfidence in their own abilities** — the most expensive failure mode of senior-with-AI collaboration. When it fires, it injects a calm reflection prompt that pauses tactical work, surfaces drift, and offers consent-gated knowledge lookups (web search / context7) before resuming. This is what *maximises the AI as a true collaborator* rather than letting it amplify the user's blind spots; it pushes a senior engineer to think one level higher than they would have alone. The rarest piece in the public AI-tooling market.

3. **`ccToolBox/retro`** — closes the continuous-learning loop. Reads diff + transcript, proposes T1/T2/T3/T4 candidates, writes only what the human approves. Without it, the harness ossifies (see `continuous-learning.md`).

4. **`ccToolBox/qa-session`** *(nice to have)* — Session-Based Test Management charters. Risk-ranked exploratory charters, Explorer sub-agents per charter, PROOF-style reporter. Useful when the e2e matrix is green but you want to find the bugs the matrix didn't anticipate.

5. **`ccToolBox/ui-refinement`** *(nice to have, web/mobile only)* — autonomous UI critique loop. Senior-designer and ruthless-tester personas critique a live running app, the loop iterates until the agent's own bar is met or the user calls stop.

6. **`ccToolBox/skill-distill`** *(meta)* — turn a successful session into a reusable skill. Reads the transcript, extracts the prompt patterns that made it work, writes a generalised skill file at a destination of your choosing. The way new skills enter the ecosystem.

## Putting it together

The `superpowers` family is the trunk. `frustration-check` is the runtime safety net catching the failure mode the trunk cannot — overconfident humans driving past their own limits. `retro` is the feedback loop that keeps the trunk sharp. The rest are useful branches.

Run the trunk + `frustration-check` + `retro` for at least one full project cycle before deciding what else to add. The compounding effect is in the loop, not in any single skill.
