RULE 1 – ABSOLUTE (DO NOT EVER VIOLATE THIS)

You may NOT delete any file or directory unless I explicitly give the exact command **in this session**.

- This includes files you just created (tests, tmp files, scripts, etc.).
- You do not get to decide that something is “safe” to remove.
- If you think something should be removed, stop and ask. You must receive clear written approval **before** any deletion command is even proposed.

Treat “never delete files without permission” as a hard invariant.

---

### IRREVERSIBLE GIT & FILESYSTEM ACTIONS

Absolutely forbidden unless I give the **exact command and explicit approval** in the same message:

- `git reset --hard`
- `git clean -fd`
- `rm -rf`
- Any command that can delete or overwrite code/data

Rules:

1. If you are not 100% sure what a command will delete, do not propose or run it. Ask first.
2. Prefer safe tools: `git status`, `git diff`, `git stash`, copying to backups, etc.
3. After approval, restate the command verbatim, list what it will affect, and wait for confirmation.
4. When a destructive command is run, record in your response:
   - The exact user text authorizing it
   - The command run
   - When you ran it

If that audit trail is missing, then you must act as if the operation never happened.

---

### Code Editing Discipline

- Do **not** run scripts that bulk-modify code (codemods, invented one-off scripts, giant `sed`/regex refactors).
- Large mechanical changes: break into smaller, explicit edits and review diffs.
- Subtle/complex changes: edit by hand, file-by-file, with careful reasoning.

---

### Backwards Compatibility & File Sprawl

We optimize for a clean architecture now, not backwards compatibility.

- No “compat shims” or “v2” file clones.
- When changing behavior, migrate callers and remove old code **inside the same file**.
- New files are only for genuinely new domains that don’t fit existing modules.
- The bar for adding files is very high.

---

### Third-Party Libraries

When unsure of an API, look up current docs (late-2025) rather than guessing.



## MCP Agent Mail — Multi-Agent Coordination

Agent Mail is already available as an MCP server; do not treat it as a CLI you must shell out to.

What it gives:

- Identities, inbox/outbox, searchable threads.
- Advisory file reservations (leases) to avoid agents clobbering each other.
- Persistent artifacts in git (human-auditable).

Core patterns:

1. **Same repo**
   - Register identity:
     - `ensure_project` then `register_agent` with the repo’s absolute path as `project_key`.
   - Reserve files before editing:
     - `file_reservation_paths(project_key, agent_name, ["src/**"], ttl_seconds=3600, exclusive=true)`.
   - Communicate:
     - `send_message(..., thread_id="FEAT-123")`.
     - `fetch_inbox`, then `acknowledge_message`.
   - Fast reads:
     - `resource://inbox/{Agent}?project=<abs-path>&limit=20`.
     - `resource://thread/{id}?project=<abs-path>&include_bodies=true`.
   - Optional:
     - Set `AGENT_NAME` so the pre-commit guard can block conflicting commits.
     - `WORKTREES_ENABLED=1` and `AGENT_MAIL_GUARD_MODE=warn` during trials.
     - Check hooks with `mcp-agent-mail guard status .` and identity with `mcp-agent-mail mail status .`.

2. **Multiple repos in one product**
   - Option A: Same `project_key` for all; use specific reservations (`frontend/**`, `backend/**`).
   - Option B: Different projects linked via:
     - `macro_contact_handshake` or `request_contact` / `respond_contact`.
     - Use a shared `thread_id` (e.g., ticket key) for cross-repo threads.

Macros vs granular:

- Prefer macros when speed is more important than fine-grained control:
  - `macro_start_session`, `macro_prepare_thread`, `macro_file_reservation_cycle`, `macro_contact_handshake`.
- Use granular tools when you need explicit behavior.

Product bus:

- Create/ensure product: `mcp-agent-mail products ensure MyProduct --name "My Product"`.
- Link repo: `mcp-agent-mail products link MyProduct .`.
- Inspect: `mcp-agent-mail products status MyProduct`.
- Search: `mcp-agent-mail products search MyProduct "bd-123 OR \"release plan\"" --limit 50`.
- Product inbox: `mcp-agent-mail products inbox MyProduct YourAgent --limit 50 --urgent-only --include-bodies`.
- Summaries: `mcp-agent-mail products summarize-thread MyProduct "bd-123" --per-thread-limit 100 --no-llm`.

Server-side tools (for orchestrators) include:

- `ensure_product(product_key|name)`
- `products_link(product_key, project_key)`
- `resource://product/{key}`
- `search_messages_product(product_key, query, limit=20)`

Common pitfalls:

- “from_agent not registered” → call `register_agent` with correct `project_key`.
- `FILE_RESERVATION_CONFLICT` → adjust patterns, wait for expiry, or use non-exclusive reservation.
- Auth issues with JWT+JWKS → bearer token with `kid` matching server JWKS; static bearer only when JWT disabled.

---

## Issue Tracking with bd (beads)

All issue tracking goes through **bd**. No other TODO systems.

Key invariants:

- `.beads/` is authoritative state and **must always be committed** with code changes.
- Do not edit `.beads/*.jsonl` directly; only via `bd`.

### Basics

Check ready work:

```bash
bd ready --json
```

Create issues:

```bash
bd create "Issue title" -t bug|feature|task -p 0-4 --json
bd create "Issue title" -p 1 --deps discovered-from:bd-123 --json
```

Update:

```bash
bd update bd-42 --status in_progress --json
bd update bd-42 --priority 1 --json
```

Complete:

```bash
bd close bd-42 --reason "Completed" --json
```

Types:

- `bug`, `feature`, `task`, `epic`, `chore`

Priorities:

- `0` critical (security, data loss, broken builds)
- `1` high
- `2` medium (default)
- `3` low
- `4` backlog

Agent workflow:

1. `bd ready` to find unblocked work.
2. Claim: `bd update <id> --status in_progress`.
3. Implement + test.
4. If you discover new work, create a new bead with `discovered-from:<parent-id>`.
5. Close when done.
6. Commit `.beads/` in the same commit as code changes.

Auto-sync:

- bd exports to `.beads/issues.jsonl` after changes (debounced).
- It imports from JSONL when newer (e.g. after `git pull`).

Never:

- Use markdown TODO lists.
- Use other trackers.
- Duplicate tracking.

---

### Using bv as an AI Sidecar

`bv` is a terminal UI + analysis layer for `.beads/beads.jsonl`. It precomputes graph metrics so you don’t have to.

Useful robot commands:

- `bv --robot-help` – overview
- `bv --robot-insights` – graph metrics (PageRank, betweenness, HITS, critical path, cycles)
- `bv --robot-plan` – parallelizable execution plan with unblocks info
- `bv --robot-priority` – priority suggestions with reasoning
- `bv --robot-recipes` – list recipes; apply via `bv --recipe <name>`
- `bv --robot-diff --diff-since <commit|date>` – JSON diff of issue changes

Use `bv` instead of rolling your own dependency graph logic.

---

### cass — Cross-Agent Search

`cass` indexes prior agent conversations (Claude Code, Codex, Cursor, Gemini, ChatGPT, etc.) so we can reuse solved problems.

Rules:

- Never run bare `cass` (TUI). Always use `--robot` or `--json`.

Examples:

```bash
cass health
cass search "authentication error" --robot --limit 5
cass view /path/to/session.jsonl -n 42 --json
cass expand /path/to/session.jsonl -n 42 -C 3 --json
cass capabilities --json
cass robot-docs guide
```

Tips:

- Use `--fields minimal` for lean output.
- Filter by agent with `--agent`.
- Use `--days N` to limit to recent history.

stdout is data-only, stderr is diagnostics; exit code 0 means success.

Treat cass as a way to avoid re-solving problems other agents already handled.

---

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
