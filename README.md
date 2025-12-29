<p align="center">
  <img src="assets/Optimus-Clip-With-Title.png" alt="Optimus Clip" width="500">
</p>

<p align="center">
  <em>A transformer for your clipboard!</em>
</p>

<p align="center">
  <a href="#why-optimus-clip">Why Optimus Clip</a> •
  <a href="#features">Features</a> •
  <a href="#quick-start">Quick Start</a> •
  <a href="#ai-providers">AI Providers</a> •
  <a href="#creating-custom-transformations">Custom Transformations</a> •
  <a href="#development">Development</a>
</p>

---

## Why Optimus Clip?

**Your clipboard is dumb. Optimus Clip makes it smart.**

Every day you copy text that needs work before you can use it:
- Terminal output with awkward line breaks
- Emails wrapped at 72 characters from the 1990s
- Code snippets that need cleaning
- Notes that need formatting
- Prose that needs grammar fixes

Instead of pasting into a text editor, cleaning it up, and copying again—**press one hotkey**. Optimus Clip intercepts your clipboard, transforms it instantly, and pastes the result.

**No windows. No context switching. Just transformed text.**

## Features

### ⌨️ Hotkey-Driven Workflow
Transform clipboard content without leaving your current app. Copy text, press a hotkey, and the transformed result is instantly pasted. No windows, no context switching.

### 🧹 Clean Terminal Text
**The reason this tool exists.** If you use CLI tools like Claude Code, Cursor, or any terminal application, you know the pain: copy text and it's full of leading spaces, wrapped lines, and formatting artifacts.

Clean Terminal Text fixes this instantly—no LLM required.

<details>
<summary><strong>Example: Before & After</strong></summary>

**Input (copied from terminal):**
```
  This is a paragraph of text that was displayed in a
  terminal window with a specific width. Each line has
  leading spaces and hard line breaks that make it
  unusable when pasted elsewhere.

  Here's another paragraph with the same problem.
```

**Output (after Clean Terminal Text):**
```
This is a paragraph of text that was displayed in a terminal window with a specific width. Each line has leading spaces and hard line breaks that make it unusable when pasted elsewhere.

Here's another paragraph with the same problem.
```
</details>

### ✨ AI-Powered Transformations
The real power: create custom transformations that use AI to process your clipboard. Each transformation gets its own hotkey.

**Format As Markdown** ships as a default—paste any messy text and get clean, structured markdown:

<details>
<summary><strong>Example: Before & After</strong></summary>

**Input (copied from a webpage or document):**
```
Getting Started    First, install the dependencies. You'll need Node.js
version 18 or higher. Then run npm install.   Configuration   Create a
config.json file in the root directory. Required fields: apiKey (your
API key), endpoint (the server URL), timeout (in milliseconds).
```

**Output (after Format As Markdown):**
```markdown
## Getting Started

First, install the dependencies. You'll need Node.js version 18 or higher. Then run `npm install`.

## Configuration

Create a `config.json` file in the root directory.

**Required fields:**
- `apiKey` — your API key
- `endpoint` — the server URL
- `timeout` — in milliseconds
```
</details>

### 🎯 Unlimited Custom Transformations
Create as many transformations as you need, each with its own hotkey:

| Use Case | What It Does |
|----------|--------------|
| **Translate** | Translate any copied text to your language |
| **Summarize** | Get a concise summary of any text |
| **Extract Content** | Copy an entire webpage, extract just the article |
| **Fix Grammar** | Clean up writing without changing meaning |

### 📝 Transformation History
Every transformation is logged—search and filter through past inputs and outputs, grouped by date.

## Quick Start

### Requirements
- macOS 15.0 (Sequoia) or later
- For AI transformations: API key from any [supported provider](#ai-providers)

### Installation

**Download the latest release:**

[Download Optimus Clip v0.1.0](https://github.com/chrisedwards/optimus-clip/releases/latest)

**Or build from source:**
```bash
git clone https://github.com/chrisedwards/optimus-clip.git
cd optimus-clip
make start
```

### First Run

1. **Grant Accessibility Permission** — Required for global hotkeys and paste simulation
2. **Set Your Hotkeys** — Open Settings → Transformations and assign keyboard shortcuts
3. **(Optional) Add an AI Provider** — Enable AI transformations by adding an API key
4. **Transform!** — Copy text, press your hotkey, done

The built-in **Clean Terminal Text** transformation works immediately—no API key needed. To use **Format As Markdown** or create custom AI transformations, configure a provider in Settings.

## AI Providers

Optimus Clip supports multiple AI providers. Choose based on your needs:

- Anthropic
- OpenAI
- OpenRouter
- Ollama (local)
- AWS Bedrock

## Creating Custom Transformations

The real power of Optimus Clip is creating transformations tailored to your workflow.

### Anatomy of a Transformation

Each transformation has:
- **Name** — What you'll see in the menu and history
- **Hotkey** — The keyboard shortcut to trigger it
- **System Prompt** — Instructions telling the AI what to do

### Example Transformations

<details>
<summary><strong>Translate to Spanish</strong></summary>

```
Translate the following text to Spanish.
Maintain the original formatting (paragraphs, lists, etc.).
Return only the translation, no explanations.
```
</details>

<details>
<summary><strong>Summarize in 3 Bullets</strong></summary>

```
Summarize the following text in exactly 3 bullet points.
Each bullet should be one sentence.
Focus on the most important information.
Return only the bullet points.
```
</details>

<details>
<summary><strong>Extract Article Content</strong></summary>

```
Extract the main article content from this webpage text.
Remove navigation, ads, footers, and other non-content elements.
Preserve headings and paragraph structure.
Return only the article content in clean markdown.
```
</details>

<details>
<summary><strong>Explain Like I'm 5</strong></summary>

```
Explain the following text in simple terms a 5-year-old could understand.
Use short sentences and common words.
Include a simple analogy if helpful.
```
</details>

### Tips

- **End with "Return only..."** — Prevents the AI from adding explanations
- **Be explicit about formatting** — "Return as markdown" or "Return as plain text"
- **Test with the preview** — Use the test button in the transformation editor before saving

## Development

### Requirements

- macOS 15.0+
- Xcode 16+ (for Swift 6.0)
- Swift 6.0

### Building

```bash
# Clone the repository
git clone https://github.com/chrisedwards/optimus-clip.git
cd optimus-clip

# Build and run
make start

# Or build only
make build
```

### Development Commands

```bash
make check       # Run linting and format checks
make test        # Run all tests
make check-test  # Run both checks and tests
make format      # Auto-format code
make package     # Create .app bundle
make stop        # Stop running instances
```

### Project Structure

```
optimus-clip/
├── Sources/
│   ├── OptimusClip/           # Main app (UI, system integration)
│   │   ├── Views/             # SwiftUI views
│   │   ├── Managers/          # System managers (hotkeys, clipboard)
│   │   ├── Services/          # LLM clients, history, settings
│   │   └── Onboarding/        # First-run experience
│   │
│   └── OptimusClipCore/       # Shared library (testable, no UI)
│       ├── Transformations/   # Transformation implementations
│       ├── LLMClients/        # Provider protocols
│       └── History/           # SwiftData models
│
├── Tests/                     # Unit tests
├── Scripts/                   # Build automation
└── assets/                    # App icons and images
```

### Architecture Notes

- **Swift 6 Strict Concurrency** — All types are `Sendable`, async/await throughout
- **Protocol-Oriented** — `Transformation` protocol for all transforms, `LLMProviderClient` for providers
- **SwiftUI + AppKit Hybrid** — Menu bar with SwiftUI settings window

See [AGENTS.md](AGENTS.md) for detailed development guidelines.

## License

MIT
