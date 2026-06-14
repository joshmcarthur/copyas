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

### Menubar app

**Copyas** also ships as a minimal menubar app — a clipboard-first UI for the same transforms. Copy text, pick a transform from the menu, and the result is written back to the clipboard with a notification.

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
copyas TRANSFORM [--stdin] [--write] [--no-stream] [--help] [--version]
copyas TRANSFORM [--stdin] [-w] [--no-stream] [-h] [-v]
```

| Argument / flag | Description |
|-----------------|-------------|
| `TRANSFORM` | Transform to apply: `summary`, `markdown`, `pirate` |
| `--stdin` | Read from stdin instead of clipboard (for pipes and file redirection) |
| `-w`, `--write` | Write result to clipboard instead of stdout |
| `--no-stream` | Buffer the full response before writing to stdout |
| `-h`, `--help` | Show usage |
| `-v`, `--version` | Show version |

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
```

### Output behaviour

By default, stdout mode **streams** the transformed text as the model generates it. Use `--no-stream` to wait for the full response before writing stdout. Clipboard mode (`-w`) always buffers the complete result.

Errors are printed to **stderr**. Transformed text goes to **stdout** by default (streamed), or to the clipboard with `-w` (stdout stays silent on success).

### Exit codes

| Code | Meaning |
|------|---------|
| `0` | Success |
| `1` | Generation, clipboard write, or internal error |
| `2` | Device not eligible for Apple Intelligence |
| `3` | Apple Intelligence not enabled |
| `4` | Model not ready |
| `5` | Model unavailable (other) |
| `6` | No input text |
| `64` | Invalid usage (missing/unknown transform) |

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
3. Run `swiftformat .` and `swift build`
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
| Testing | Manual verification on AI-enabled Mac; mock `ModelClient` only if tests are requested |

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
├── docs/
│   └── SPEC.md
├── .gitignore
├── .swiftformat
└── Sources/copyas/
    └── … (see SPEC §6.1)
```

---

## License

TBD.
