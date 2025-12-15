## Issue Tracking with bd (beads)

**IMPORTANT**: This project uses **bd (beads)** for ALL issue tracking. Do NOT use markdown TODOs, task lists, or other tracking methods.

### Why bd?

- Dependency-aware: Track blockers and relationships between issues
- Git-friendly: Auto-syncs to JSONL for version control
- Agent-optimized: JSON output, ready work detection, discovered-from links
- Prevents duplicate tracking systems and confusion

### Quick Start

**Check for ready work:**
```bash
bd ready --json
```

**Create new issues:**
```bash
bd create "Issue title" -t bug|feature|task -p 0-4 --json
bd create "Issue title" -p 1 --deps discovered-from:bd-123 --json
bd create "Subtask" --parent <epic-id> --json  # Hierarchical subtask (gets ID like epic-id.1)
```

**Claim and update:**
```bash
bd update bd-42 --status in_progress --json
bd update bd-42 --priority 1 --json
```

**Complete work:**
```bash
bd close bd-42 --reason "Completed" --json
```

### Issue Types

- `bug` - Something broken
- `feature` - New functionality
- `task` - Work item (tests, docs, refactoring)
- `epic` - Large feature with subtasks
- `chore` - Maintenance (dependencies, tooling)

### Priorities

- `0` - Critical (security, data loss, broken builds)
- `1` - High (major features, important bugs)
- `2` - Medium (default, nice-to-have)
- `3` - Low (polish, optimization)
- `4` - Backlog (future ideas)

### Workflow for AI Agents

1. **Check ready work**: `bd ready` shows unblocked issues
2. **Claim your task**: `bd update <id> --status in_progress`
3. **Work on it**: Implement, test, document
4. **Discover new work?** Create linked issue:
   - `bd create "Found bug" -p 1 --deps discovered-from:<parent-id>`
5. **Complete**: `bd close <id> --reason "Done"`
6. **Commit together**: Always commit the `.beads/issues.jsonl` file together with the code changes so issue state stays in sync with code state

### Auto-Sync

bd automatically syncs with git:
- Exports to `.beads/issues.jsonl` after changes (5s debounce)
- Imports from JSONL when newer (e.g., after `git pull`)
- No manual export/import needed!

### GitHub Copilot Integration

If using GitHub Copilot, also create `.github/copilot-instructions.md` for automatic instruction loading.
Run `bd onboard` to get the content, or see step 2 of the onboard instructions.

### MCP Server (Recommended)

If using Claude or MCP-compatible clients, install the beads MCP server:

```bash
pip install beads-mcp
```

Add to MCP config (e.g., `~/.config/claude/config.json`):
```json
{
  "beads": {
    "command": "beads-mcp",
    "args": []
  }
}
```

Then use `mcp__beads__*` functions instead of CLI commands.

### Managing AI-Generated Planning Documents

AI assistants often create planning and design documents during development:
- PLAN.md, IMPLEMENTATION.md, ARCHITECTURE.md
- DESIGN.md, CODEBASE_SUMMARY.md, INTEGRATION_PLAN.md
- TESTING_GUIDE.md, TECHNICAL_DESIGN.md, and similar files

**Best Practice: Use a dedicated directory for these ephemeral files**

**Recommended approach:**
- Create a `history/` directory in the project root
- Store ALL AI-generated planning/design docs in `history/`
- Keep the repository root clean and focused on permanent project files
- Only access `history/` when explicitly asked to review past planning

**Example .gitignore entry (optional):**
```
# AI planning documents (ephemeral)
history/
```

**Benefits:**
- ✅ Clean repository root
- ✅ Clear separation between ephemeral and permanent documentation
- ✅ Easy to exclude from version control if desired
- ✅ Preserves planning history for archeological research
- ✅ Reduces noise when browsing the project

### CLI Help

Run `bd <command> --help` to see all available flags for any command.
For example: `bd create --help` shows `--parent`, `--deps`, `--assignee`, etc.

### Important Rules

- ✅ Use bd for ALL task tracking
- ✅ Always use `--json` flag for programmatic use
- ✅ Link discovered work with `discovered-from` dependencies
- ✅ Check `bd ready` before asking "what should I work on?"
- ✅ Store AI planning docs in `history/` directory
- ✅ Run `bd <cmd> --help` to discover available flags
- ❌ Do NOT create markdown TODO lists
- ❌ Do NOT use external issue trackers
- ❌ Do NOT duplicate tracking systems
- ❌ Do NOT clutter repo root with planning documents

For more details, see README.md and QUICKSTART.md.

### Using bv as an AI sidecar

bv is a fast terminal UI for Beads projects (.beads/beads.jsonl). It renders lists/details and precomputes dependency metrics (PageRank, critical path, cycles, etc.) so you instantly see blockers and execution order. For agents, it’s a graph sidecar: instead of parsing JSONL or risking hallucinated traversal, call the robot flags to get deterministic, dependency-aware outputs.

*IMPORTANT: As an agent, you must ONLY use bv with the robot flags, otherwise you'll get stuck in the interactive TUI that's intended for human usage only!*

- bv --robot-help — shows all AI-facing commands.
- bv --robot-insights — JSON graph metrics (PageRank, betweenness, HITS, critical path, cycles) with top-N summaries for quick triage.
- bv --robot-plan — JSON execution plan: parallel tracks, items per track, and unblocks lists showing what each item frees up.
- bv --robot-priority — JSON priority recommendations with reasoning and confidence.
- bv --robot-recipes — list recipes (default, actionable, blocked, etc.); apply via bv --recipe <name> to pre-filter/sort before other flags.
- bv --robot-diff --diff-since <commit|date> — JSON diff of issue changes, new/closed items, and cycles introduced/resolved.

Use these commands instead of hand-rolling graph logic; bv already computes the hard parts so agents can act safely and quickly.

## MCP Agent Mail: coordination for multi-agent workflows

What it is
- A mail-like layer that lets coding agents coordinate asynchronously via MCP tools and resources.
- Provides identities, inbox/outbox, searchable threads, and advisory file reservations, with human-auditable artifacts in Git.

Why it's useful
- Prevents agents from stepping on each other with explicit file reservations (leases) for files/globs.
- Keeps communication out of your token budget by storing messages in a per-project archive.
- Offers quick reads (`resource://inbox/...`, `resource://thread/...`) and macros that bundle common flows.

How to use effectively
1) Same repository
   - Register an identity: call `ensure_project`, then `register_agent` using this repo's absolute path as `project_key`.
   - Reserve files before you edit: `file_reservation_paths(project_key, agent_name, ["src/**"], ttl_seconds=3600, exclusive=true)` to signal intent and avoid conflict.
   - Communicate with threads: use `send_message(..., thread_id="FEAT-123")`; check inbox with `fetch_inbox` and acknowledge with `acknowledge_message`.
   - Read fast: `resource://inbox/{Agent}?project=<abs-path>&limit=20` or `resource://thread/{id}?project=<abs-path>&include_bodies=true`.
   - Tip: set `AGENT_NAME` in your environment so the pre-commit guard can block commits that conflict with others' active exclusive file reservations.

2) Across different repos in one project (e.g., Next.js frontend + FastAPI backend)
   - Option A (single project bus): register both sides under the same `project_key` (shared key/path). Keep reservation patterns specific (e.g., `frontend/**` vs `backend/**`).
   - Option B (separate projects): each repo has its own `project_key`; use `macro_contact_handshake` or `request_contact`/`respond_contact` to link agents, then message directly. Keep a shared `thread_id` (e.g., ticket key) across repos for clean summaries/audits.

Macros vs granular tools
- Prefer macros when you want speed or are on a smaller model: `macro_start_session`, `macro_prepare_thread`, `macro_file_reservation_cycle`, `macro_contact_handshake`.
- Use granular tools when you need control: `register_agent`, `file_reservation_paths`, `send_message`, `fetch_inbox`, `acknowledge_message`.

Common pitfalls
- "from_agent not registered": always `register_agent` in the correct `project_key` first.
- "FILE_RESERVATION_CONFLICT": adjust patterns, wait for expiry, or use a non-exclusive reservation when appropriate.
- Auth errors: if JWT+JWKS is enabled, include a bearer token with a `kid` that matches server JWKS; static bearer is used only when JWT is disabled.


## Integrating with Beads (dependency-aware task planning)

Beads provides a lightweight, dependency-aware issue database and a CLI (`bd`) for selecting "ready work," setting priorities, and tracking status. It complements MCP Agent Mail's messaging, audit trail, and file-reservation signals. Project: [steveyegge/beads](https://github.com/steveyegge/beads)

Recommended conventions
- **Single source of truth**: Use **Beads** for task status/priority/dependencies; use **Agent Mail** for conversation, decisions, and attachments (audit).
- **Shared identifiers**: Use the Beads issue id (e.g., `bd-123`) as the Mail `thread_id` and prefix message subjects with `[bd-123]`.
- **Reservations**: When starting a `bd-###` task, call `file_reservation_paths(...)` for the affected paths; include the issue id in the `reason` and release on completion.

Typical flow (agents)
1) **Pick ready work** (Beads)
   - `bd ready --json` → choose one item (highest priority, no blockers)
2) **Reserve edit surface** (Mail)
   - `file_reservation_paths(project_key, agent_name, ["src/**"], ttl_seconds=3600, exclusive=true, reason="bd-123")`
3) **Announce start** (Mail)
   - `send_message(..., thread_id="bd-123", subject="[bd-123] Start: <short title>", ack_required=true)`
4) **Work and update**
   - Reply in-thread with progress and attach artifacts/images; keep the discussion in one thread per issue id
5) **Complete and release**
   - `bd close bd-123 --reason "Completed"` (Beads is status authority)
   - `release_file_reservations(project_key, agent_name, paths=["src/**"])`
   - Final Mail reply: `[bd-123] Completed` with summary and links

Mapping cheat-sheet
- **Mail `thread_id`** ↔ `bd-###`
- **Mail subject**: `[bd-###] …`
- **File reservation `reason`**: `bd-###`
- **Commit messages (optional)**: include `bd-###` for traceability

Event mirroring (optional automation)
- On `bd update --status blocked`, send a high-importance Mail message in thread `bd-###` describing the blocker.
- On Mail "ACK overdue" for a critical decision, add a Beads label (e.g., `needs-ack`) or bump priority to surface it in `bd ready`.

Pitfalls to avoid
- Don't create or manage tasks in Mail; treat Beads as the single task queue.
- Always include `bd-###` in message `thread_id` to avoid ID drift across tools.

---

## Optimus Clip Project Guidelines

**Project Status:** Phase 0 (Scaffolding)
**Swift Version:** 6.0
**macOS Target:** 15.0+

### Project Overview

Optimus Clip is a macOS menu bar application that acts as intelligent clipboard middleware. It intercepts clipboard content via global hotkeys, transforms it using algorithmic rules or LLMs, and pastes the result.

**Bundle ID:** com.optimusclip
**Architecture:** SwiftUI + AppKit hybrid (menu bar + settings window)
**Concurrency Model:** Swift 6 strict concurrency with async/await

### Project Structure

```
optimus-clip/
├── Sources/
│   ├── OptimusClip/           # Main app target (executable)
│   │   ├── OptimusClipApp.swift         # @main entry point
│   │   ├── Views/                       # SwiftUI views
│   │   ├── Managers/                    # System integration
│   │   └── Models/                      # SwiftData models
│   │
│   └── OptimusClipCore/       # Shared library (importable)
│       ├── Transformation.swift         # Core protocol
│       ├── Transformations/             # Implementations
│       └── LLMClients/                  # Provider integrations
│
├── Tests/
│   └── OptimusClipTests/      # Unit tests
│
├── Scripts/                   # Build automation
│   ├── compile_and_run.sh    # Dev workflow
│   ├── package_app.sh        # Create .app bundle
│   └── kill_optimusclip.sh   # Stop running instances
│
├── version.env               # Single source of truth for versions
├── Package.swift             # SPM manifest
├── package.json              # npm scripts interface
├── Info.plist                # App configuration template
├── .swiftformat              # Code formatting rules
├── .swiftlint.yml            # Linting rules
├── AGENTS.md                 # Project guidelines (this file)
└── CLAUDE.md                 # Symlink to AGENTS.md
```

**Why split OptimusClip and OptimusClipCore?**
- OptimusClip: Platform-specific (AppKit, SwiftUI, macOS APIs)
- OptimusClipCore: Pure Swift logic (testable, reusable, cross-platform potential)

### Build Commands

Use make targets for all checks and tests (quiet output, ~99% token savings for AI agents):

```bash
make check         # Run format check and lint (quiet output)
make test          # Run unit tests (quiet output)
make test-parallel # Run tests in parallel (quiet output)
make check-test    # Run both checks and tests
make format        # Auto-format code with swiftformat
make lint          # Run swiftlint with auto-fix
make build         # Build the project (debug)
make build-release # Build the project (release)
make package       # Package app (debug build)
make package-release # Package app (release build)
make clean         # Remove build artifacts
make start         # Compile and run the app
make stop          # Stop running app instances

# Verbose output when debugging failures
make test VERBOSE=1
make check VERBOSE=1
```

**Direct commands** (verbose output, use make targets above for quiet output):
```bash
swift build              # Build (debug)
swift test               # Run tests
swiftformat .            # Format code
swiftlint lint           # Lint code
```

**Before every commit:**
```bash
make check    # Must pass (no formatting/linting issues)
make test     # Must pass (all tests green)
```

**Version management:**
- Edit `version.env` to change version or build number
- Format: `MARKETING_VERSION="0.1.0"` and `BUILD_NUMBER="1"`
- Scripts read this file and populate Info.plist automatically

### Code Style Expectations

#### Swift 6 Concurrency
- **Always** use strict concurrency checking (enabled in Package.swift)
- Mark types as `Sendable` explicitly (struct, actor, or final class with immutable state)
- Use `@MainActor` for UI types (Views, ObservableObject)
- Never use `@unchecked Sendable` without detailed justification comment
- Prefer `async/await` over completion handlers

```swift
// ✅ GOOD
struct ClipboardContent: Sendable {
    let text: String
    let timestamp: Date
}

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var apiKey: String = ""
}

// ❌ BAD
class ClipboardContent {  // Missing Sendable, should be struct
    var text: String
}
```

#### Value Types Over Reference Types
- **Prefer `struct`** for data models and transformations
- Use `class` only when:
  - Need reference semantics (shared mutable state)
  - Inheriting from Cocoa classes (NSObject, NSView)
  - Managing system resources (file handles, timers)

#### Explicit Self
- **Always use `self.`** in closures (required by SwiftFormat config)
- This prevents subtle capture bugs and aids Swift 6 concurrency checking

```swift
// ✅ GOOD
Task {
    let result = await self.transform(self.input)
}

// ❌ BAD (will fail swiftformat)
Task {
    let result = await transform(input)
}
```

#### Formatting
- **Indent:** 4 spaces (no tabs)
- **Line length:** 120 characters max
- Run `npm run format` before committing

#### Formatter/Linter Conflicts
When swiftformat and swiftlint conflict, **fix in config files** (`.swiftformat`, `.swiftlint.yml`)—never use `// swiftlint:disable` comments.

### Testing Guidelines

#### Framework
- Use **Swift Testing** framework (not XCTest) for new tests
- Async tests fully supported via `@Test` attribute
- Test Core library thoroughly (transformations, LLM clients)

#### Structure
```swift
import Testing
@testable import OptimusClipCore

@Suite("Transformation Tests")
struct TransformationTests {
    @Test("Whitespace stripping removes leading spaces")
    func testWhitespaceStripping() async throws {
        let transform = WhitespaceStripTransformation()
        let input = "  Hello\n  World"
        let output = try await transform.transform(input)
        #expect(output == "Hello\nWorld")
    }
}
```

#### Running Tests
```bash
npm run test              # Run all tests
swift test --filter "TransformationTests"  # Run specific suite
```

### Safety Guards

#### Never Commit
- API keys or secrets (use Keychain, not hardcoded strings)
- Absolute paths from your machine (`/Users/yourname/...`)
- Debug print statements (`print()`, `dump()`)

#### Always Test Before Push
```bash
npm run check    # Format and lint
npm run test     # All tests pass
npm run start    # App launches without crash
```

#### Never Auto-Release
- Don't create GitHub releases without explicit approval
- Don't bump version numbers autonomously
- Don't run signing/notarization scripts without request

### Architecture Patterns

#### Protocol-Oriented Design
Define protocols for core abstractions:
```swift
protocol Transformation: Sendable {
    func transform(_ input: String) async throws -> String
}
```

#### Dependency Injection
Pass dependencies explicitly, avoid singletons:
```swift
// ✅ GOOD
struct LLMTransformation: Transformation {
    let client: LLMClient
    func transform(_ input: String) async throws -> String {
        try await client.complete(input)
    }
}

// ❌ BAD
struct LLMTransformation {
    func transform(_ input: String) async throws -> String {
        try await OpenAIClient.shared.complete(input)  // Singleton
    }
}
```

### Common Operations

#### Adding a New Transformation
1. Create new struct in `Sources/OptimusClipCore/Transformations/`
2. Conform to `Transformation` protocol
3. Mark as `Sendable`
4. Add tests in `Tests/OptimusClipTests/`
5. Run `npm run check` and `npm run test`

#### Adding a New LLM Provider
1. Create client in `Sources/OptimusClipCore/LLMClients/`
2. Define async methods for API calls
3. Store credentials in Keychain (Phase 6) or @AppStorage (Phase 0-5)
4. Add provider section to Settings UI

### Security Considerations

#### API Keys
- **Phase 0-5:** Store in `@AppStorage` (UserDefaults) as placeholder
- **Phase 6:** Migrate to macOS Keychain via Security framework
- Never log API keys

#### Accessibility Permission
- Required for global hotkeys and paste simulation
- Check with `AXIsProcessTrusted()`
- Request with `AXIsProcessTrustedWithOptions()`

### Troubleshooting

#### Build Fails
- Check Swift version: `swift --version` (should be 6.0+)
- Check Xcode: `xcode-select -p` (should point to Xcode.app)
- Clean build: `swift package clean && swift build`

#### Tests Fail
- Check imports: `@testable import OptimusClipCore`
- Check test target in Package.swift
- Run verbose: `swift test --verbose`

#### Format/Lint Fails
- Auto-fix: `npm run format && npm run lint`
- If still fails, read error messages carefully

#### App Won't Launch
- Kill existing instances: `npm run stop`
- Check binary exists: `ls -l .build/debug/OptimusClip`
- Run directly: `.build/debug/OptimusClip`

### Phase Roadmap

- **Phase 0 (Current):** Project scaffolding, tooling setup
- **Phase 1:** Menu bar UI
- **Phase 2:** Clipboard monitoring
- **Phase 3:** Hotkeys + Settings
- **Phase 4:** Algorithmic transformations
- **Phase 5:** LLM integration
- **Phase 6:** Keychain + Launch at login
- **Phase 7:** Code signing + auto-updates

### Questions to Ask Before Acting

1. "Does this change require a test?"
2. "Does this follow Swift 6 concurrency rules?"
3. "Is this a value type or reference type? Why?"
4. "Should this be in OptimusClip or OptimusClipCore?"
5. "Will this pass swiftformat and swiftlint?"
6. "Is this security-sensitive? (API keys, clipboard, permissions)"
