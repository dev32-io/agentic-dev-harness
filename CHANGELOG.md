# Changelog

All notable changes to `agentic-dev-harness` will be documented here.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.1.0] - 2026-05-19

### Added
- `base/rules/` — 7 workflow-essential rules + 7 paired details (clean-code, collaboration, e2e-testing, error-handling, git-workflow, logging, testing).
- `platforms/typescript/` — shared TS overlay (typescript + decorator-pattern) auto-chained by web/node/bun.
- `platforms/mobile/` — shared mobile overlay (lifecycle, navigation, offline) auto-chained by android/ios.
- `platforms/android/` — FLAGSHIP: 7 rules + paired details (kotlin, compose, mvi, hilt-di, coroutines-flow, testing, gradle), qa oracles + 2 charters (cold-start, config-change), platform-specific quality-gate hook.
- `platforms/ios/` — FLAGSHIP: 7 rules + paired details (swift, swiftui, mvvm, swift-concurrency, combine, testing, xcodebuild), qa oracles + 2 charters (cold-launch, rotation), platform-specific quality-gate hook.
- `platforms/web/` — 4 rules: react, css, accessibility, e2e-playwright.
- `platforms/node/`, `platforms/bun/`, `platforms/python/`, `platforms/esp32/` — 2 rules each, leaner v0.1 scope.
- `hooks/` — `quality-gate.sh` platform-aware dispatcher + `settings.example.json` with the two-hook CI pair (PostToolUse typecheck + TaskCompleted full gate) + README.
- `CLAUDE.md.template` — meta-gate forcing MANDATORY rule-reading in target projects.
- `install.sh` — POSIX-sh bootstrap with `--target`, `--platforms`, `--no-chain`, `--dry-run`.
- `examples/` — 3 working sample projects: web-bun-sample (Bun + Preact, builds green), ios-sample (SwiftUI, builds green), android-sample (Compose, scaffolded; requires Android SDK to build).
- `docs/` — 6 public explainers: tiered-loading, composite-layout, ruleset-philosophy, continuous-learning, workflow-and-skills (with the `frustration-check` callout), portfolio-narrative.
- `tests/` — `lint-rules.sh` (5-check rule-file contract) + `install-test.sh` (5-case install integration test). Both POSIX sh.
- `CONTRIBUTING.md` with three flows (add platform, propose rule, promote learning) + 3 issue templates under `.github/ISSUE_TEMPLATE/`.
- Cross-link to [ccToolBox](https://github.com/dev32-io/ccToolBox).

### Deferred to v0.2
- `install.sh --update` mode (reconcile target's rules against latest harness).
- `.harness-version` stamp in target projects (for upgrade paths).
