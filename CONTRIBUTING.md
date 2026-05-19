# Contributing to agentic-dev-harness

Thanks for your interest. This harness is intentionally small and opinionated.
We accept contributions in three flows: **adding a platform**, **proposing a
base rule**, and **promoting a learning** from a real project.

Before opening a pull request, please open the matching issue first and wait
for an acknowledgement. This keeps the project tightly scoped and avoids
wasted work.

---

## Flow 1: Add a platform

Use this flow when you want to add a new `platforms/<name>/` overlay (e.g.
`rust`, `flutter`, `go`).

1. **Open an issue** using the **platform-request** template.
   - State the platform name, primary toolchain, whether it chains another
     platform (e.g. `chain: [typescript]`), and at least two planned rules.
   - Explain why the rule set generalizes beyond your personal project.
2. **Wait for a maintainer acknowledgement** on the issue before doing the
   work. Platforms are a long-term commitment for the repo.
3. **Open a pull request** that adds:
   - `platforms/<name>/` directory.
   - At least **2 rules** under `platforms/<name>/rules/`.
   - A paired **details** file for every rule (see Quality bars below).
   - `platforms/<name>/chain.yaml` **only if** this platform overlays another
     platform (e.g. `react` overlaying `typescript`). Otherwise omit the file.
   - Any platform-specific commands, scripts, or template snippets the rules
     reference.

---

## Flow 2: Propose a base rule

Use this flow when you want to add or amend a rule under `base/rules/`. Base
rules apply to every project regardless of language or framework, so the bar
is high.

1. **Open an issue** using the **rule-proposal** template.
   - Explain why the rule is **workflow-essential** (it affects the
     brainstorm → spec → plan → execute → verify → retro loop).
   - Explain why it is **language-agnostic** (no rule that only makes sense
     for one language belongs in `base/`).
2. **Wait for a maintainer acknowledgement.**
3. **Open a pull request** that:
   - Adds or edits the rule file under `base/rules/` (≤100 LOC,
     instruction-only, atomic — one concern per file).
   - Adds or edits the paired details file under `base/details/`.
   - Passes `tests/lint-rules.sh` locally (rule/details pairing and LOC
     budget are enforced there).

If your idea is workflow-essential but only meaningful in one ecosystem, it
probably belongs under `platforms/<name>/rules/` instead — use Flow 1.

---

## Flow 3: Promote a learning

Use this flow when a `/retro` in one of your real projects produces a
learning that you believe generalizes. This is the most common path to new
base rules and is encouraged.

1. **Run `/retro`** in your target project as normal. The retro will append
   an entry to that project's `learnings.md`.
2. **Open an issue** using the **learning-to-promote** template.
   - Quote the learning **verbatim** from your `learnings.md`.
   - Explain why it generalizes beyond your project.
   - Indicate where it should land: a new file under `base/rules/`, an
     amendment to an existing `base/rules/` file, or a new file under
     `platforms/<name>/rules/`.
3. **Wait for a maintainer acknowledgement.**
4. **Open a pull request** that adds the learning to `base/rules/` or
   `platforms/<p>/rules/` (with paired details, as above).

The verbatim quote matters: it preserves the original context so reviewers
can judge whether the learning truly generalizes, or whether it is shaped by
something local to your project.

---

## Quality bars

These bars are enforced by `tests/lint-rules.sh` (LOC + pairing) and by code
review (everything else).

- **Rule files**: ≤100 LOC, **instruction-only**, **atomic** (one concern per
  file). A rule says *do this* / *don't do that*. It does not explain.
- **Details files**: ≤500 LOC, **prose-heavy**, containing examples,
  gotchas, and FAQs. Details files are where the *why* lives.
- **Every rule must have a paired details file.** `tests/lint-rules.sh`
  enforces this. A rule named `base/rules/foo.md` requires
  `base/details/foo.md` (and vice versa).
- **`install.sh` must remain POSIX-sh.** No zsh-isms, no bash-isms. If you
  need a feature your shell offers, find a POSIX-sh equivalent.
  `tests/install-test.sh` runs in CI and will fail on regressions.

---

## License

This project is MIT-licensed. By contributing, you agree that your
contributions are licensed under the MIT License as well.
