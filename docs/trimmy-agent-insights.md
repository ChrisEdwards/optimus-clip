# Trimmy Agent Directive Insights

A comprehensive implementation guide for configuring AI coding assistants based on patterns from the Trimmy repository. Trimmy uses `AGENTS.md` for agent directives.

**Source:** https://github.com/steipete/Trimmy

---

## Table of Contents

1. [Philosophy: Why Agent Directives Matter](#1-philosophy-why-agent-directives-matter)
2. [The Agent File Hierarchy](#2-the-agent-file-hierarchy)
3. [CLAUDE.md / AGENTS.md Structure](#3-claudemd--agentsmd-structure)
4. [Writing Effective Directives](#4-writing-effective-directives)
5. [Documentation Frontmatter System](#5-documentation-frontmatter-system)
6. [Package.json as Agent Interface](#6-packagejson-as-agent-interface)
7. [Config Files as Implicit Standards](#7-config-files-as-implicit-standards)
8. [CI as Source of Truth](#8-ci-as-source-of-truth)
9. [Safety Directives](#9-safety-directives)
10. [Implementation Checklist](#10-implementation-checklist)
11. [Full File Templates](#11-full-file-templates)
12. [Testing Agent Behavior](#12-testing-agent-behavior)
13. [Common Pitfalls](#13-common-pitfalls)
14. [Advanced Patterns](#14-advanced-patterns)

---

## 1. Philosophy: Why Agent Directives Matter

### The Problem
AI coding assistants are powerful but lack project-specific context. Without guidance, they:
- Use inconsistent formatting and naming conventions
- Run wrong build commands or skip testing
- Make architectural decisions that conflict with existing patterns
- Accidentally perform destructive operations (releases, force pushes)
- Generate code that fails CI checks

### The Solution
Agent directive files (`CLAUDE.md`, `AGENTS.md`) provide:
- **Guardrails**: Prevent destructive operations
- **Context**: Project structure, naming patterns, architectural decisions
- **Workflow**: Exact commands for building, testing, linting
- **Standards**: Coding style, commit message format, PR expectations

### Key Insight from Trimmy
Trimmy treats agent directives as **first-class project documentation**—not an afterthought. The `AGENTS.md` file is:
- Maintained alongside code changes
- Referenced by other docs (release checklist says "read AGENTS.md first")
- Structured for quick scanning during different tasks

---

## 2. The Agent File Hierarchy

### What Trimmy Actually Uses

Trimmy's agent configuration files:

```
Repository Root
├── AGENTS.md          # Main agent instructions (root for quick access)
├── .swiftformat       # SwiftFormat config (implicit standards)
├── .swiftlint.yml     # SwiftLint config (implicit standards)
├── package.json       # Discoverable commands via npm scripts
├── docs/
│   ├── AGENTS.md      # Detailed guidelines (with YAML frontmatter)
│   ├── spec.md        # Product spec (with frontmatter)
│   └── release.md     # Release process (with frontmatter)
└── .github/
    └── workflows/
        └── ci.yml     # CI workflow (authoritative checks)
```

Note: Trimmy does **not** use `.cursorrules` or `.github/copilot-instructions.md`. It relies solely on `AGENTS.md`.

### Other Tools (For Reference)

If you need to support other AI tools, they read different files:

| Tool | Primary File |
|------|-------------|
| Claude Code | `CLAUDE.md` (falls back to `AGENTS.md`) |
| Cursor | `.cursorrules` |
| GitHub Copilot | `.github/copilot-instructions.md` |
| OpenAI Codex | `AGENTS.md` |

### Trimmy's Approach
Trimmy uses `AGENTS.md` at root (for quick access) with a more detailed `docs/AGENTS.md` containing frontmatter. The root version includes:

```markdown
YOU MUST READ ~/Projects/agent-scripts/AGENTS.MD BEFORE ANYTHING (skip if file missing).
```

This allows **shared global directives** across multiple projects—useful for teams with consistent tooling.

---

## 3. CLAUDE.md / AGENTS.md Structure

### Trimmy's Section Organization

```markdown
# Repository Guidelines

## Project Structure & Module Organization
[What goes where—helps agent navigate codebase]

## Build, Test, and Development Commands
[Exact commands—no ambiguity]

## Coding Style & Naming Conventions
[How to format code, name things]

## Testing Guidelines
[Testing expectations and patterns]

## Commit & Pull Request Guidelines
[Git workflow, PR checklist]

## Release & Validation Notes
[Deployment process, safety guards]
```

### Why This Structure Works

1. **Project Structure first**: Agent needs to know where things are before doing anything
2. **Commands early**: Most interactions involve building/testing
3. **Style before testing**: Write code correctly, then test it
4. **Commits near end**: Only relevant when work is complete
5. **Release last**: Rare operation, needs extra safety

### Section-by-Section Breakdown

#### Project Structure Section
**Purpose**: Orient the agent to the codebase layout.

```markdown
## Project Structure & Module Organization
- `Sources/Trimmy`: SwiftUI/macOS app code (clipboard monitoring, command detection, settings panes, entry point `TrimmyApp.swift`).
- `Sources/TrimmyCore`: Shared logic (testable independently, no UI dependencies).
- `Sources/TrimmyCLI`: Command-line interface using TrimmyCore.
- `Tests/TrimmyTests`: Swift Testing suites covering clipboard behavior and edge cases.
- `Scripts`: Automation helpers; prefer these over ad-hoc commands.
- `docs`: Contributor docs (this file and feature notes). Keep `CHANGELOG.md` Trimmy-only.
- Assets and project metadata live at repository root (`Trimmy.xcodeproj`, `Info.plist`, icons).
```

**Key patterns**:
- List directories with their **purpose**, not just names
- Mention entry points (`TrimmyApp.swift`)
- Call out what goes where (`CHANGELOG.md` is project-only)
- Reference conventions (`prefer these over ad-hoc commands`)

#### Build Commands Section
**Purpose**: Eliminate guesswork about how to build/run/test.

```markdown
## Build, Test, and Development Commands
- Dev build & launch: `./Scripts/compile_and_run.sh` (re-run after code changes; avoids launching stale app bundles).
- Swift build: `swift build` (debug) or `swift build -c release` for production binaries.
- Package app: `./Scripts/package_app.sh release` → `Trimmy.app`; follow with `./Scripts/sign-and-notarize.sh` when shipping.
- Tests: `swift test` (use `--filter` to target a suite). Run before push/PR.
- Format & lint: `swiftformat .` then `swiftlint lint --fix`. Fix reported issues before committing.
- After any code change, run `pnpm check` and fix all reported format/lint issues before handoff.
```

**Key patterns**:
- **Preferred workflow first**: "Dev build & launch" is the most common operation
- **Parenthetical context**: "(re-run after code changes; avoids stale bundles)"
- **Explicit sequences**: "swiftformat . then swiftlint lint --fix"
- **Trigger conditions**: "Run before push/PR", "After any code change"
- **Unified command**: `pnpm check` wraps multiple tools

#### Coding Style Section
**Purpose**: Ensure generated code matches existing patterns.

```markdown
## Coding Style & Naming Conventions
- SwiftFormat config: 4-space indent, LF line endings, max width 120, arguments/parameters wrapped before-first, explicit `self` inserted for Swift 6 concurrency. Do not hand-format differently.
- SwiftLint config favors strictness: keep imports sorted by formatter, avoid force casts/tries (warnings), respect length thresholds.
- Prefer small, focused types and functions; extract helpers instead of letting files grow past soft limits (file warning 1500 lines).
- Use descriptive names for settings panes and clipboard helpers; follow existing `Settings*Pane` and `*Monitor` patterns.
```

**Key patterns**:
- Reference config files: "SwiftFormat config: ..."
- Explicit prohibitions: "Do not hand-format differently"
- Architectural guidance: "small, focused types"
- Naming conventions with examples: "`Settings*Pane` and `*Monitor` patterns"

#### Testing Section
**Purpose**: Set expectations for test coverage and style.

```markdown
## Testing Guidelines
- Add/extend Swift Testing cases under `Tests/TrimmyTests`; mirror naming like `ClipboardMonitorTests` and `AggressivenessPreviewExamplesTests`.
- Cover new clipboard parsing branches and regression fixes with explicit inputs/expected outputs; favor deterministic tests over UI snapshots.
- Maintain or increase coverage; do not skip `swift test` in CI-equivalent workflows.
```

**Key patterns**:
- Framework specification: "Swift Testing cases"
- Naming examples: "mirror naming like `ClipboardMonitorTests`"
- Test philosophy: "explicit inputs/expected outputs", "deterministic over UI snapshots"
- Coverage expectations: "Maintain or increase coverage"

#### Commit Section
**Purpose**: Standardize git workflow.

```markdown
## Commit & Pull Request Guidelines
- Commit messages: short, imperative, and scoped (e.g., "Fix Sparkle feed URL", "Add settings height animation guard").
- Before opening a PR: run `swiftformat .`, `swiftlint lint --fix`, `swift test`, and `./Scripts/compile_and_run.sh` to verify the app boots cleanly.
- Include a concise summary, linked issue (if applicable), repro steps, and before/after notes or screenshots for UI-touching changes.
- Update `CHANGELOG.md` for user-visible adjustments; keep entries Trimmy-specific. Avoid introducing new tooling or dependencies without prior approval.
```

**Key patterns**:
- Message format with examples: "short, imperative, scoped"
- Pre-PR checklist: exact sequence of commands
- PR content requirements: summary, linked issue, screenshots
- Change log expectations: "user-visible adjustments"
- Dependency warning: "Avoid introducing new tooling without approval"

#### Release Section
**Purpose**: Prevent accidental deployments, document process.

```markdown
## Release & Validation Notes
- Package with `./Scripts/package_app.sh release`, sign/notarize via `./Scripts/sign-and-notarize.sh`, then verify (`spctl`, `stapler`) per README checklist.
- Do not edit generated bundles directly—regenerate via scripts.
- Releases must only be performed when explicitly requested in the current prompt; permission is one-time and does not persist to future sessions.
```

**Key patterns**:
- Complete command sequence for releases
- Explicit prohibition: "Do not edit generated bundles directly"
- **Critical safety guard**: "only performed when explicitly requested... one-time... does not persist"

---

## 4. Writing Effective Directives

### Good vs Bad Directives

#### Bad: Vague
```markdown
## Code Style
Follow good Swift practices and keep code clean.
```

#### Good: Specific
```markdown
## Code Style
- 4-space indent (configured in `.swiftformat`)
- Max 120 chars per line
- Use `self.` explicitly for member access (required for Swift 6 concurrency)
- Prefer `guard` for early returns over nested `if` statements
- Follow existing `Settings*Pane` naming pattern for settings views
```

#### Bad: Missing Context
```markdown
## Testing
Write tests for new features.
```

#### Good: Actionable
```markdown
## Testing
- Use Swift Testing framework (`@Suite`, `@Test`, `#expect`)
- Place tests in `Tests/TrimmyTests/` mirroring source structure
- Name test files `<Feature>Tests.swift` (e.g., `ClipboardMonitorTests.swift`)
- Each transformation should have input/output test cases:
  ```swift
  @Test func testURLRepair() {
      let input = "https://example\n.com/path"
      let expected = "https://example.com/path"
      #expect(transform(input) == expected)
  }
  ```
- Run `swift test` before any commit; CI will reject failing PRs
```

### Directive Writing Principles

1. **Be explicit about commands**: Include exact command strings
2. **Provide examples**: Show naming patterns, code snippets
3. **Explain why**: "(re-run after changes; avoids stale bundles)"
4. **Set triggers**: "Before PR", "After any code change"
5. **Include prohibitions**: "Do not", "Avoid", "Never"
6. **Reference other files**: "configured in `.swiftformat`"

---

## 5. Documentation Frontmatter System

### The Pattern
Trimmy uses YAML frontmatter in documentation files to help agents understand when to read them:

```markdown
---
summary: "Trimmy repo guardrails, build/lint/test commands, and release expectations."
read_when:
  - Starting work on Trimmy
  - Before running builds, tests, or changing tooling
---

# Repository Guidelines
...
```

### Frontmatter Schema

```yaml
---
summary: "One-line description of document purpose"
read_when:
  - "Condition that triggers reading this doc"
  - "Another trigger condition"
  - "Yet another trigger"
---
```

### Examples from Trimmy

**docs/AGENTS.md**
```yaml
---
summary: "Trimmy repo guardrails, build/lint/test commands, and release expectations."
read_when:
  - Starting work on Trimmy
  - Before running builds, tests, or changing tooling
---
```

**docs/spec.md**
```yaml
---
summary: "Trimmy product/technical spec: goals, heuristics, settings, and build notes."
read_when:
  - Planning or scoping new Trimmy features
  - Changing clipboard detection heuristics or settings behavior
  - Reviewing product scope or requirements
---
```

**docs/release.md**
```yaml
---
summary: "Trimmy release checklist: package, sign, notarize, Sparkle appcast, and assets."
read_when:
  - Cutting or validating a Trimmy release
  - Updating appcast or signing/notarization steps
---
```

### Why Frontmatter Works

1. **Discoverability**: Agent can scan frontmatter without reading full docs
2. **Conditional reading**: Only load docs relevant to current task
3. **Self-documenting**: Humans also benefit from clear summaries
4. **Reduces context**: Agent doesn't load everything upfront

### Implementation for Optimus Clip

Create a `docs/` directory with frontmatter-enabled files:

```
docs/
├── AGENTS.md       # Main guidelines (frontmatter: "Starting work")
├── spec.md         # Product spec (frontmatter: "Planning features")
├── architecture.md # Technical design (frontmatter: "Architectural decisions")
└── release.md      # Release process (frontmatter: "Cutting releases")
```

---

## 6. Package.json as Agent Interface

### The Pattern
Even for non-Node.js projects, `package.json` provides a discoverable command interface.

### Trimmy's package.json

```json
{
  "name": "trimmy",
  "private": true,
  "scripts": {
    "start": "./Scripts/compile_and_run.sh",
    "start:release": "sh -c './Scripts/package_app.sh release && ./Scripts/kill_trimmy.sh && open Trimmy.app'",
    "format": "swiftformat .",
    "lint": "swiftlint lint --fix",
    "check": "swiftformat . --lint && swiftlint lint",
    "build": "swift build",
    "test": "swift test",
    "release": "./Scripts/package_app.sh release",
    "restart": "pnpm start",
    "stop": "./Scripts/kill_trimmy.sh || true"
  }
}
```

### Why This Works

1. **Standard interface**: `pnpm start`, `pnpm test`, `pnpm build` work everywhere
2. **Self-documenting**: `pnpm run` lists all available commands
3. **Composable**: `check` combines `format` and `lint`
4. **Agent-discoverable**: AI can read `package.json` to find commands
5. **Cross-platform**: Works on any system with Node.js

### Integration with CLAUDE.md

Reference package.json scripts in your agent file:

```markdown
## Quick Commands
- `pnpm start` — Build and launch dev app
- `pnpm check` — Format + lint (run before commits)
- `pnpm test` — Run test suite
- `pnpm package` — Create release .app bundle
```

---

## 7. Config Files as Implicit Standards

### The Insight
Config files (`.swiftformat`, `.swiftlint.yml`) are **machine-readable coding standards**. Agents can:
1. Read them to understand project conventions
2. Generate code that passes linting automatically
3. Avoid formatting conflicts

### SwiftFormat Config (`.swiftformat`)

```bash
# SwiftFormat configuration for Swift 6 projects

# CRITICAL: Swift 6 concurrency requires explicit self
--self insert
--selfrequired

# Indentation
--indent 4
--indentcase false
--ifdef no-indent
--xcodeindentation enabled

# Line formatting
--linebreaks lf
--maxwidth 120
--trimwhitespace always

# Wrapping
--wraparguments before-first
--wrapparameters before-first
--wrapcollections before-first
--closingparen same-line

# Organization
--organizetypes class,struct,enum,extension
--extensionmark "MARK: - %t + %p"
--marktypes always
--markextensions always

# Swift version
--swiftversion 6.2

# Exclusions
--exclude .build,.swiftpm,DerivedData,node_modules
```

### SwiftLint Config (`.swiftlint.yml`)

```yaml
# SwiftLint configuration - Swift 6 compatible

included:
  - Sources
  - Tests

excluded:
  - .build
  - DerivedData
  - "**/Generated"

# Analyzer rules (require compilation)
analyzer_rules:
  - unused_declaration
  - unused_import

# Strict rules
opt_in_rules:
  - array_init
  - closure_spacing
  - empty_count
  - empty_string
  - explicit_init
  - first_where
  - last_where
  - multiline_arguments
  - multiline_parameters
  - operator_usage_whitespace
  - sorted_first_last

# Disabled rules
disabled_rules:
  - explicit_self          # SwiftFormat handles this
  - trailing_whitespace    # SwiftFormat handles this
  - identifier_name        # Single letters OK in closures
  - todo                   # TODOs are acceptable

# Rule configurations
force_cast: warning
force_try: warning

line_length:
  warning: 120
  error: 250
  ignores_comments: true
  ignores_urls: true

file_length:
  warning: 1500
  error: 2500
  ignore_comment_only_lines: true

function_body_length:
  warning: 150
  error: 300

type_body_length:
  warning: 800
  error: 1200

reporter: "xcode"
```

### How Agents Use Config Files

When an agent reads `.swiftformat`, it learns:
- Use 4-space indentation
- Max line width is 120 characters
- Wrap arguments before first parameter
- Insert explicit `self` for Swift 6

This means generated code will pass `swiftformat . --lint` without changes.

---

## 8. CI as Source of Truth

### The Principle
Your CI workflow defines what **must pass** for code to be accepted. Agents should treat CI steps as requirements.

### Trimmy's CI Workflow

```yaml
name: CI

on:
  push:
    branches: ["*"]
  pull_request:

jobs:
  lint-build-test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4

      - name: Select Xcode
        run: |
          for candidate in /Applications/Xcode_16.1.app /Applications/Xcode_16.app /Applications/Xcode.app; do
            if [[ -d "$candidate" ]]; then
              sudo xcode-select -s "$candidate"
              break
            fi
          done
          xcodebuild -version

      - name: Install Swift 6.2 toolchain
        run: |
          curl -L https://download.swift.org/swift-6.2-release/xcode/swift-6.2-RELEASE/swift-6.2-RELEASE-osx.pkg -o /tmp/swift.pkg
          sudo installer -pkg /tmp/swift.pkg -target /

      - name: Install lint tools
        run: brew install swiftlint swiftformat

      - name: SwiftFormat (lint)
        run: swiftformat Sources Tests --lint

      - name: SwiftLint
        run: swiftlint --strict

      - name: Swift Test
        run: swift test --parallel
```

### Translating CI to Agent Directives

The CI workflow tells agents:

1. **Format check**: `swiftformat Sources Tests --lint` must pass
2. **Lint check**: `swiftlint --strict` must pass (zero warnings)
3. **Tests**: `swift test --parallel` must pass

This becomes:

```markdown
## Before Commits
These checks must pass (CI will reject failures):
1. `swiftformat Sources Tests --lint` — zero formatting issues
2. `swiftlint --strict` — zero warnings or errors
3. `swift test` — all tests pass
```

### Reference CI in CLAUDE.md

```markdown
## CI Requirements
See `.github/workflows/ci.yml` for authoritative checks. Summary:
- SwiftFormat lint mode (no auto-fix in CI)
- SwiftLint strict mode (warnings = failure)
- All tests must pass

Run `pnpm check && pnpm test` locally before pushing.
```

---

## 9. Safety Directives

### Critical Safety Patterns from Trimmy

#### Release Guard
```markdown
Releases must only be performed when explicitly requested in the current prompt;
permission is one-time and does not persist to future sessions.
```

**Why**: Prevents agent from releasing when asked to "finish up" or "deploy".

#### Generated File Guard
```markdown
Do not edit generated bundles directly—regenerate via scripts.
```

**Why**: Prevents agent from modifying `.app` contents, breaking code signing.

#### Dependency Guard
```markdown
Avoid introducing new tooling or dependencies without prior approval.
```

**Why**: Prevents agent from adding npm packages, Swift packages, etc. without review.

### Additional Safety Directives to Consider

```markdown
## Safety Guards

### Destructive Git Operations
- NEVER force push to main/master
- NEVER use `git reset --hard` without explicit confirmation
- NEVER delete remote branches without explicit request

### Credential Handling
- NEVER commit files containing secrets (.env, credentials.json, API keys)
- NEVER log or display sensitive values
- If you encounter credentials, stop and alert the user

### External Services
- NEVER make API calls to production services unless explicitly requested
- NEVER modify cloud resources (AWS, GCP, Azure) without confirmation
- NEVER send emails or notifications without explicit request

### File Operations
- NEVER delete files outside the project directory
- NEVER modify system files or configurations
- Prefer editing existing files over creating new ones
```

---

## 10. Implementation Checklist

### Phase 1: Foundation (Do First)

- [ ] Create `CLAUDE.md` at repository root
- [ ] Create `package.json` with script shortcuts
- [ ] Create `.swiftformat` config
- [ ] Create `.swiftlint.yml` config
- [ ] Create `Scripts/` directory

### Phase 2: Scripts

- [ ] Create `Scripts/compile_and_run.sh`
- [ ] Create `Scripts/kill_<appname>.sh`
- [ ] Create `Scripts/package_app.sh`

### Phase 3: CI

- [ ] Create `.github/workflows/ci.yml`
- [ ] Verify CI passes locally before pushing

### Phase 4: Documentation

- [ ] Create `docs/AGENTS.md` with frontmatter
- [ ] Create `docs/spec.md` with frontmatter
- [ ] Create `CHANGELOG.md`

### Phase 5: Testing

- [ ] Test agent with "build the project" prompt
- [ ] Test agent with "add a new feature" prompt
- [ ] Test agent with "create a release" prompt (should refuse without explicit request)
- [ ] Verify generated code passes `pnpm check`

---

## 11. Full File Templates

### CLAUDE.md Template

```markdown
# Optimus Clip - Repository Guidelines

## Project Structure
- `Sources/OptimusClip`: SwiftUI macOS menu-bar app (clipboard monitoring, transformations, settings).
- `Sources/OptimusClipCore`: Shared transformation logic (testable independently, no UI).
- `Tests/OptimusClipTests`: Swift Testing suites.
- `Scripts/`: Build and automation helpers; prefer these over ad-hoc commands.
- `docs/`: Contributor documentation.

## Quick Commands
- `pnpm start` — Build and launch dev app
- `pnpm check` — Format + lint (run before every commit)
- `pnpm test` — Run test suite
- `pnpm package` — Create release .app bundle

## Build & Development
- Dev workflow: `./Scripts/compile_and_run.sh` (kills existing, builds, launches)
- Swift build: `swift build` (debug) or `swift build -c release`
- Tests: `swift test` (or `swift test --filter <pattern>`)

## Code Style
- Swift 6.2 with strict concurrency (`.swiftformat` has `--self insert`)
- 4-space indent, max 120 chars per line
- Wrap arguments/parameters before-first
- Follow existing naming: `*Monitor`, `*Transformation`, `Settings*Pane`
- Prefer small types; extract helpers before files reach 1500 lines

## Testing
- Use Swift Testing: `@Suite`, `@Test`, `#expect`
- Name files `<Feature>Tests.swift` in `Tests/OptimusClipTests/`
- Cover transformations with explicit input/output test cases
- Run `swift test` before any commit

## Before Commits
1. `swiftformat .` — fix formatting
2. `swiftlint lint --fix` — fix lint issues
3. `swift test` — verify tests pass
4. Update `CHANGELOG.md` for user-visible changes

Or simply: `pnpm check && pnpm test`

## Commit Messages
- Short, imperative, scoped: "Add URL transformation", "Fix clipboard polling"
- Reference issues: "Fix #123: Handle empty clipboard"

## Pull Requests
- Run full check: `pnpm check && pnpm test && pnpm start`
- Include: summary, linked issue, before/after for UI changes
- Update CHANGELOG.md for user-visible changes

## Safety Guards
- Releases: Only when explicitly requested; permission does not persist
- Dependencies: Do not add new packages without approval
- Generated files: Do not edit .app bundles directly; use scripts
- Git: Never force push to main; never delete remote branches without request
```

### package.json Template

```json
{
  "name": "optimus-clip",
  "private": true,
  "scripts": {
    "start": "./Scripts/compile_and_run.sh",
    "build": "swift build",
    "build:release": "swift build -c release",
    "test": "swift test",
    "format": "swiftformat .",
    "lint": "swiftlint lint --fix",
    "check": "swiftformat . --lint && swiftlint lint",
    "package": "./Scripts/package_app.sh release",
    "stop": "./Scripts/kill_optimusclip.sh || true",
    "clean": "swift package clean && rm -rf .build DerivedData"
  }
}
```

### Scripts/compile_and_run.sh Template

Based on Trimmy's actual script (simplified):

```bash
#!/usr/bin/env bash
# Reset app: kill running instances, build, test, package, relaunch, verify.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="OptimusClip"
APP_BUNDLE="${ROOT_DIR}/${APP_NAME}.app"

log()  { printf '%s\n' "$*"; }
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

run_step() {
  local label="$1"; shift
  log "==> ${label}"
  if ! "$@"; then
    fail "${label} failed"
  fi
}

# 1) Kill all running instances
log "==> Killing existing ${APP_NAME} instances"
pkill -x "${APP_NAME}" 2>/dev/null || true
sleep 0.5

# 2) Build, test, package
run_step "swift build" swift build -q
run_step "swift test" swift test -q
run_step "package app" "${ROOT_DIR}/Scripts/package_app.sh" debug

# 3) Launch the packaged app
run_step "launch app" open "${APP_BUNDLE}"

# 4) Verify the app stays up for at least 1s
sleep 1
if pgrep -x "${APP_NAME}" >/dev/null 2>&1; then
  log "OK: ${APP_NAME} is running."
else
  fail "App exited immediately. Check crash logs in Console.app."
fi
```

### .github/workflows/ci.yml Template

```yaml
name: CI

on:
  push:
    branches: ["*"]
  pull_request:

jobs:
  lint-build-test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4

      - name: Select Xcode
        run: |
          if [[ -d "/Applications/Xcode_16.app" ]]; then
            sudo xcode-select -s /Applications/Xcode_16.app
          fi
          xcodebuild -version

      - name: Install tools
        run: brew install swiftlint swiftformat

      - name: SwiftFormat (lint)
        run: swiftformat Sources Tests --lint

      - name: SwiftLint
        run: swiftlint --strict

      - name: Build
        run: swift build

      - name: Test
        run: swift test --parallel
```

---

## 12. Testing Agent Behavior

### Test Prompts

After setting up agent files, test with these prompts:

#### Basic Build Test
> "Build and run the project"

**Expected**: Agent runs `pnpm start` or `./Scripts/compile_and_run.sh`

#### Code Generation Test
> "Add a new transformation that converts tabs to spaces"

**Expected**:
- Creates file in correct location (`Sources/OptimusClipCore/`)
- Uses correct naming pattern (`TabToSpaceTransformation`)
- Adds tests in `Tests/OptimusClipTests/`
- Runs `pnpm check` before finishing

#### Safety Test
> "Create a release"

**Expected**: Agent refuses or asks for explicit confirmation

#### Style Test
> "Show me how you'd write a new settings pane"

**Expected**:
- Uses 4-space indent
- Follows `Settings*Pane` naming
- Uses explicit `self.`
- Max 120 char lines

### Verification Checklist

- [ ] Agent finds correct build command
- [ ] Agent runs tests before committing
- [ ] Agent uses correct file locations
- [ ] Agent follows naming conventions
- [ ] Agent respects safety guards
- [ ] Generated code passes `pnpm check`

---

## 13. Common Pitfalls

### Pitfall 1: Overly Verbose Directives
**Problem**: Agent ignores long documents or misses key points.
**Solution**: Keep directives concise. Use bullet points. Front-load important info.

### Pitfall 2: Missing Command Context
**Bad**: `Run swiftformat`
**Good**: `Run swiftformat . (formats all Swift files in place)`

### Pitfall 3: Assuming Knowledge
**Bad**: `Follow our standard PR process`
**Good**: `Before PR: run pnpm check, swift test, verify app launches`

### Pitfall 4: No Examples
**Bad**: `Use descriptive names`
**Good**: `Use descriptive names following existing patterns: *Monitor, *Transformation, Settings*Pane`

### Pitfall 5: Conflicting Instructions
**Problem**: CLAUDE.md says one thing, docs/AGENTS.md says another.
**Solution**: Single source of truth. Reference one file from another.

### Pitfall 6: Missing Safety Guards
**Problem**: Agent force-pushes, deletes branches, or releases without asking.
**Solution**: Explicit prohibitions with consequences.

---

## 14. Advanced Patterns

### Pattern: Layered Directives

```
~/.config/claude/CLAUDE.md    # Global defaults (all projects)
./CLAUDE.md                   # Project-specific overrides
./docs/AGENTS.md              # Detailed guidelines
```

Reference chain:
```markdown
# ~/.config/claude/CLAUDE.md
[Global conventions for all Swift projects]

# ./CLAUDE.md
See also: docs/AGENTS.md for detailed guidelines.
Override: Use pnpm instead of npm (global default).
```

### Pattern: Task-Specific Includes

```markdown
## Task-Specific Guidelines

### When adding a new transformation:
1. Create `Sources/OptimusClipCore/<Name>Transformation.swift`
2. Add protocol conformance to `Transformation`
3. Register in `TransformationPipeline.swift`
4. Add tests in `Tests/OptimusClipTests/<Name>TransformationTests.swift`
5. Update CHANGELOG.md

### When modifying clipboard monitoring:
1. Read `docs/spec.md` for polling/timing requirements
2. Test with various clipboard content types
3. Verify no infinite loops (self-write marker)
```

### Pattern: Architecture Decision Records

Reference ADRs in CLAUDE.md:

```markdown
## Architecture
See `docs/adr/` for architectural decisions:
- `001-transformation-pipeline.md` — Why we use a pipeline pattern
- `002-clipboard-polling.md` — Why polling instead of notifications
- `003-self-write-marker.md` — How we prevent infinite loops
```

### Pattern: Conditional Behavior

```markdown
## Environment-Specific Behavior

### Development (debug builds)
- Sparkle auto-update disabled
- Bundle ID: com.example.optimus-clip.debug
- Extra logging enabled

### Production (release builds)
- Sparkle auto-update enabled
- Bundle ID: com.example.optimus-clip
- Minimal logging
```

---

## Summary

Effective agent configuration requires:

1. **Clear structure**: Organized sections that agents can scan
2. **Explicit commands**: No guesswork about how to build/test/deploy
3. **Examples**: Show naming patterns, code snippets, commit messages
4. **Safety guards**: Prevent destructive operations
5. **Config files**: Machine-readable standards that agents understand
6. **CI as authority**: What CI requires = what agents must do
7. **Testing**: Verify agent behavior with specific prompts

The goal is to make the agent a **productive team member** who understands your project's conventions, respects its boundaries, and generates code that passes review on the first try.
