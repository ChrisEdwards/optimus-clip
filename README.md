<p align="center">
  <img src="assets/Optimus-Clip-With-Title.png" alt="Optimus Clip" width="500">
</p>

<p align="center">
  <em>More than meets the clipboard</em>
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#installation">Installation</a> •
  <a href="#usage">Usage</a> •
  <a href="#development">Development</a>
</p>

---

## Features

Optimus Clip is a macOS menu bar application that intercepts clipboard content via global hotkeys, transforms it using algorithmic rules or LLMs, and pastes the result.

- **Menu Bar Integration** - Lives unobtrusively in your menu bar
- **Global Hotkeys** - Transform clipboard content with a keystroke
- **Algorithmic Transformations** - Strip whitespace, change case, format code
- **LLM-Powered Transforms** - Use OpenAI, Anthropic, or local models
- **Clipboard History** - Quick access to recent clips

## Requirements

- macOS 15.0+
- Swift 6.0+

## Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/optimus-clip.git
cd optimus-clip

# Build and run
make start
```

## Usage

1. Launch Optimus Clip from the menu bar
2. Copy text to your clipboard
3. Press a configured hotkey to transform
4. The transformed text is automatically pasted

## Development

```bash
# Build
make build

# Run tests
make test

# Format and lint
make check

# Package app bundle
make package
```

See [CLAUDE.md](CLAUDE.md) for detailed development guidelines.

## License

MIT
