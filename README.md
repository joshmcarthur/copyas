# copyas

A macOS CLI that transforms clipboard text using **Apple Foundation Models** — copy as Markdown, summary, pirate speak, and more.

```bash
copyas markdown -w
copyas summary --stdin < report.txt
```

---

## Requirements

- macOS 26+ (Apple Intelligence–capable Mac)
- Apple Intelligence enabled in System Settings
- Xcode 26+ or Swift 6 toolchain

---

## For humans

### Install (development)

```bash
git clone https://github.com/joshmcarthur/copyas.git
cd copyas
swift build -c release
```

The binary is at `.build/release/copyas`. Add it to your `PATH` or symlink it:

```bash
ln -sf "$(pwd)/.build/release/copyas" /usr/local/bin/copyas
```

### Menubar app vs CLI

The menubar app uses the same transforms and model pipeline but is **clipboard-only**: no `--stdin`, `--write`, or `--no-stream`. Pick a transform from the menu; the result replaces the clipboard and a notification is shown.

Build and run:

```bash
./Scripts/build-menubar-app.sh
open dist/Copyas.app
```

The app runs as a menu bar agent (no Dock icon). Use **Quit Copyas** in the menu to exit.

To install locally:

```bash
cp -R dist/Copyas.app ~/Applications/
```

### Usage

```text
copyas <transform> [--stdin] [--write] [--no-stream]
```

Run `copyas --help` for full usage. Current version: `0.1.0` (`copyas --version` or `copyas -v`).

| Argument / flag | Short | Description |
|-----------------|-------|-------------|
| `transform` | — | **Required.** Transform to apply: `summary`, `markdown`, or `pirate` (case-insensitive) |
| `--stdin` | — | Read input from stdin instead of the clipboard |
| `--write` | `-w` | Write result to the clipboard instead of stdout (stdout stays silent on success) |
| `--no-stream` | — | Buffer the full response before writing stdout (ignored with `-w`, which always buffers) |
| `--help` | `-h` | Show usage |
| `--version` | `-v` | Show version |

**Input:** With `--stdin`, reads all of stdin until EOF (UTF-8). Otherwise reads the general pasteboard string. Trailing whitespace is trimmed; leading whitespace is preserved.

**Output:** Errors go to stderr. Transformed text goes to stdout (streamed by default) or the clipboard with `-w`.

### Transforms

| Name | What it does |
|------|----------------|
| `summary` | Bullet-point summary of the input |
| `markdown` | Converts text into structured Markdown |
| `pirate` | Rewrites text in pirate speak |

### Examples

```bash
# Transform clipboard text and write back to clipboard
copyas markdown -w

# Preview clipboard transform on stdout
copyas markdown

# Summarise a file
copyas summary --stdin < report.txt

# Pipe through other tools (streaming stdout is fine for tee)
cat draft.txt | copyas markdown --stdin | tee formatted.md

# Buffer the full response before writing stdout (for scripts expecting one write)
copyas summary --stdin --no-stream < report.txt

# Pirate speak via pipe
echo "Hello, world!" | copyas pirate --stdin

# Unknown transform → exit 64
copyas lolcat
```

### Output behaviour

By default, stdout mode **streams** the transformed text as the model generates it. Use `--no-stream` to wait for the full response before writing stdout. Clipboard mode (`-w`) always buffers the complete result.

Long input is split automatically when it exceeds the on-device context window (4,096 tokens). Chunking uses a LangChain-compatible splitter (`RecursiveTextSplit`); transforms declare how chunks are merged (concatenate for `markdown` / `pirate`, map-reduce for `summary`).

### Exit codes

| Code | Meaning |
|------|---------|
| `0` | Success |
| `1` | Generation failed, content blocked, context window exceeded (even after chunking), or clipboard write failed |
| `2` | Device not eligible for Apple Intelligence |
| `3` | Apple Intelligence not enabled |
| `4` | Model not ready (or model assets unavailable) |
| `5` | Model unavailable (other) |
| `6` | No input text |
| `7` | Input unsuitable (no meaningful text to transform) |
| `64` | Invalid usage (missing or unknown transform) |

Errors are printed to stderr as `error: …` (e.g. `error: unknown transform "lolcat"`).

### Formatting

This project uses [SwiftFormat](https://github.com/nicklockwood/SwiftFormat). Install and run before committing:

```bash
brew install swiftformat
swiftformat .
```

Build with warnings as errors during development:

```bash
swift build -Xswiftc -warnings-as-errors
```

### Contributing

1. Read the executable spec: [`docs/SPEC.md`](docs/SPEC.md)
2. Make focused changes aligned with one logical commit
3. Run `swiftformat .`, `swift build`, and `swift test`
4. Review your diff before committing
5. Use imperative, semantic commit messages (e.g. `feat(cli): add clipboard-first CLI`)

---

## For agents

This section is for coding agents (Cursor, Claude Code, etc.) implementing or extending **copyas**.

### Source of truth

**Read and follow [`docs/SPEC.md`](docs/SPEC.md) completely.** It defines CLI behaviour, transforms, architecture, exit codes, and the implementation commit plan. If README and SPEC disagree, SPEC wins.

### Workflow

1. **Plan from the spec** — Use §7 (implementation plan) as the default commit sequence.
2. **One logical change per commit** — Each commit should be reviewable on its own (e.g. scaffold, CLI parsing, input layer, transforms, model integration, wiring).
3. **Review before commit** — Run `git diff` (staged and unstaged). Confirm the diff matches intent and does not include unrelated edits.
4. **Lint and format proactively** — Before every commit:
   ```bash
   swiftformat .
   swift build -Xswiftc -warnings-as-errors
   ```
5. **Do not commit unless asked** — The user may request commits explicitly; otherwise leave changes uncommitted or ask.
6. **Minimal scope** — Implement only what the spec and user request. No extra transforms, flags, or dependencies without approval.

### Implementation hints

| Area | Guidance |
|------|----------|
| Package layout | SwiftPM executable target; see SPEC §6.1 |
| CLI | Prefer [swift-argument-parser](https://github.com/apple/swift-argument-parser) |
| Model | `FoundationModels`: `SystemLanguageModel.default`, `LanguageModelSession` |
| Clipboard | `NSPasteboard.general` via AppKit (macOS only) |
| Transforms | Enum + instruction strings; case-insensitive lookup |
| Testing | `swift test`; live Foundation Models tests skip on hosts without Apple Intelligence |

### Commit message format

Use [Conventional Commits](https://www.conventionalcommits.org/) style:

```text
<type>(<scope>): <short imperative summary>

Optional body explaining why, not what.
```

Types: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`.

Examples:

- `chore: initialise Swift package scaffold`
- `feat(input): read text from stdin and clipboard`
- `feat(model): integrate Foundation Models session`

### When stuck

- Foundation Models API changed → consult Apple’s current docs; preserve CLI contract in SPEC §4–§5.
- Build fails on non-Apple-Intelligence hardware → expected; verify logic structurally; note in PR that runtime tests need an eligible Mac.
- User asks for a new transform → add to SPEC §5 first, then implement in a dedicated commit.

### Files to create (greenfield)

When starting from an empty repo, expect at minimum:

```text
copyas/
├── Package.swift
├── README.md
├── docs/SPEC.md
├── Scripts/
├── Sources/
│   ├── Copyas/          # Core library (CLI, model, transforms)
│   ├── CopyasCLI/       # `copyas` executable
│   ├── CopyasMenuBar/   # Menubar app
│   └── RecursiveTextSplit/
└── Tests/
```

---

## License

TBD.
