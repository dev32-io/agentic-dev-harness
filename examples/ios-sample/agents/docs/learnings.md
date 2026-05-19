# Learnings

> Dated observations not yet formalized as rules. The active distilled-wisdom log.

## How this file is used

- `/retro` (from [ccToolBox](https://github.com/dev32-io/ccToolBox)) appends entries here after each completed branch.
- Each entry describes a specific gotcha or observation — config drift, API contract surprise, environment quirk — with the date discovered and reproducible context.
- When an entry recurs across projects or generalizes, it gets **promoted** to a rule under `.claude/rules/<name>.md` and is removed from this file.

## Entry format

```markdown
### [YYYY-MM-DD] <short kebab-case identifier>

**Observed:** <what happened>

**Why it matters:** <consequence>

**Workaround / fix:** <how it was resolved>

**Promote when:** <criteria for graduating to a rule>
```

## Entries

<!-- New entries appended here. -->
