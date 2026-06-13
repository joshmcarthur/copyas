# copyas — Executable Specification

**Status:** Draft  
**Version:** 0.1.0  
**Last updated:** 2026-06-13

This document is the source of truth for implementing **copyas**: a macOS CLI that reads text from the clipboard (or stdin), applies a named transform via Apple Foundation Models, and writes the result to stdout or back to the clipboard. Humans and coding agents MUST follow this spec when building or extending the project.

---

## 1. Problem statement

Users frequently copy text and want it reformatted or restyled (summarised, converted to Markdown, rewritten in a fun voice, etc.). **copyas** provides a fast, scriptable, on-device pipeline:

```
input text → transform → output text
```

It is designed for shell pipelines, clipboard workflows, and automation — not as a GUI app.

---

## 2. Goals and non-goals

### Goals

| ID | Goal |
|----|------|
| G1 | Accept text from **clipboard** by default, or **stdin** with `--stdin` |
| G2 | Apply a **named transform** via required positional argument |
| G3 | Write transformed text to **stdout** by default, or back to the clipboard with `--write` / `-w` |
| G4 | Use **Apple Foundation Models** (`FoundationModels` framework) for generation |
| G5 | Fail clearly on stderr with non-zero exit codes |
| G6 | Ship as a single executable built with **Swift Package Manager** |
| G7 | Run on **Apple Intelligence–enabled Macs** with supported OS versions |

### Non-goals (v0.1)

- Windows or Linux support
- Interactive TUI or GUI
- Custom / user-defined transforms (future work)
- Network calls or third-party LLM APIs (v0.1 uses on-device model only)
- Writing to both stdout and clipboard simultaneously

---

## 3. Platform and dependencies

| Requirement | Value |
|-------------|-------|
| Language | Swift 6.x |
| Build | Swift Package Manager (`Package.swift`) |
| Framework | `FoundationModels` (Apple) |
| Minimum OS | macOS 26.0 (Tahoe) — adjust only if build verification proves otherwise |
| Device | Apple Intelligence–capable Mac; model availability checked at runtime |
| Clipboard | `AppKit` (`NSPasteboard`) — macOS only |

### Availability handling

Before invoking the model, check `SystemLanguageModel.default.availability`. Map outcomes:

| Availability | Exit code | stderr message (approximate) |
|--------------|-----------|------------------------------|
| `.available` | — | proceed |
| `.unavailable(.deviceNotEligible)` | `2` | `error: device does not support Apple Intelligence` |
| `.unavailable(.appleIntelligenceNotEnabled)` | `3` | `error: enable Apple Intelligence in System Settings` |
| `.unavailable(.modelNotReady)` | `4` | `error: language model is not ready` |
| `.unavailable(_)` (other) | `5` | `error: language model unavailable` |

Empty input MUST exit `6` with `error: no input text`.

Unknown transform MUST exit `64` (sysexits `EX_USAGE`).

General generation failure MUST exit `1` with a concise stderr message.

---

## 4. CLI contract

### 4.1 Invocation

```text
copyas TRANSFORM [--stdin] [--write | -w] [--no-stream] [--help | -h] [--version | -v]
```

| Argument / flag | Short | Required | Description |
|-----------------|-------|----------|-------------|
| `TRANSFORM` | — | **Yes** | Positional transform name (see §5) |
| `--stdin` | — | No | Read input from stdin instead of clipboard |
| `--write` | `-w` | No | Write result to clipboard instead of stdout |
| `--no-stream` | — | No | Buffer the full response before writing to stdout |
| `--help` | `-h` | No | Print usage; exit `0` |
| `--version` | `-v` | No | Print name and version; exit `0` |

### 4.2 Input precedence

1. If `--stdin` is set → read **all** of stdin until EOF (UTF-8).
2. Else → read string from `NSPasteboard.general.string(forType: .string)`.

Trim trailing whitespace from input; do **not** trim leading whitespace (code blocks depend on it).

### 4.3 Output

- If `--write` / `-w` is set → write transformed text to the general pasteboard; **stdout stays silent** on success. Clipboard mode always buffers the full response.
- Else if `--no-stream` is set → buffer the full response, then write to **stdout** in one write (UTF-8, trailing newline optional but preferred for POSIX tools).
- Else → **stream** transformed text to **stdout** incrementally as the model generates it; append a trailing newline at the end if the response lacks one.
- Errors, warnings, progress → **stderr** only.
- No ANSI colour in v0.1.
- Clipboard write failure MUST exit `1` with `error: failed to write to clipboard`.

### 4.4 Examples (acceptance scenarios)

```bash
# Transform clipboard text and write back to clipboard
copyas markdown -w

# Preview clipboard transform on stdout
copyas markdown

# Summarise a file
copyas summary --stdin < notes.txt

# Pirate speak via pipe
echo "Hello, world!" | copyas pirate --stdin

# Buffered stdout (single write)
copyas summary --stdin --no-stream < notes.txt

# Unknown transform
copyas lolcat
# → stderr: error: unknown transform "lolcat"; exit 64
```

---

## 5. Transforms (v0.1)

Each transform is a **named preset**: a system-style instruction plus optional generation options. Transforms are registered in code (enum or registry); adding one is a discrete, reviewable change.

### 5.1 `summary`

**Purpose:** Produce a concise bullet-point summary of the input.

**Instructions to model (paraphrase allowed; intent MUST match):**

> Summarise the following text as a short list of bullet points. Use `-` for bullets. Preserve factual accuracy. Do not add information that is not in the source. Output only the summary, no preamble.

**Constraints:**

- Output MUST be plain text with bullet lines.
- If input is already very short (< ~40 chars), still return at least one bullet.

### 5.2 `markdown`

**Purpose:** Convert messy or plain text into clean Markdown.

**Instructions to model:**

> Convert the following text into well-structured Markdown. Use headings, lists, and emphasis where appropriate. Preserve all factual content. Output only the Markdown, no preamble or fenced code wrapper around the whole document.

**Constraints:**

- Do not wrap the entire response in a markdown code fence.
- Preserve links and code snippets from the source when present.

### 5.3 `pirate`

**Purpose:** Rewrite text in playful pirate speak.

**Instructions to model:**

> Rewrite the following text in exaggerated pirate speak. Keep the original meaning and approximate length. Output only the rewritten text, no preamble.

**Constraints:**

- Meaning MUST remain intelligible; this is stylistic, not a summary.

### 5.4 Transform registry

Implement a registry keyed by transform name (lowercase ASCII):

```swift
// Conceptual — exact types may vary
enum Transform: String, CaseIterable {
    case summary
    case markdown
    case pirate
}
```

`copyas summary` and `copyas SUMMARY` SHOULD accept case-insensitive names (normalise to lowercase).

---

## 6. Architecture

```text
┌─────────────┐     ┌──────────────┐     ┌─────────────────┐     ┌─────────────┐
│ InputSource │ ──► │ Transform    │ ──► │ LanguageModel   │ ──► │ OutputSink  │
│ clipboard / │     │ (instructions│     │ Session         │     │ stdout /    │
│ stdin       │     │  + prompt)   │     │ (FoundationModels)     │ clipboard   │
└─────────────┘     └──────────────┘     └─────────────────┘     └─────────────┘
       ▲                                         │
       │              ┌──────────────┐           │
       └──────────────│ CLI (Argument│◄──────────┘
                      │ Parser)      │   errors → stderr
                      └──────────────┘
```

### 6.1 Recommended module layout

| Path | Responsibility |
|------|----------------|
| `Package.swift` | Executable target `copyas`, platforms, dependencies |
| `Sources/copyas/copyas.swift` | `@main` entry, orchestration |
| `Sources/copyas/CLI/Command.swift` | Argument parsing (`ArgumentParser` recommended) |
| `Sources/copyas/Input/InputSource.swift` | clipboard vs stdin |
| `Sources/copyas/Output/OutputSink.swift` | stdout vs clipboard |
| `Sources/copyas/Transform/Transform.swift` | Transform enum + metadata |
| `Sources/copyas/Transform/TransformRegistry.swift` | Lookup + validation |
| `Sources/copyas/Model/ModelClient.swift` | Availability check + `LanguageModelSession` |
| `Sources/copyas/Model/GenerationError.swift` | Typed errors → exit codes |

Keep files focused; split further only when a file exceeds ~200 lines or mixes unrelated concerns.

### 6.2 Model session

Use `SystemLanguageModel.default` and `LanguageModelSession` from Foundation Models.

Pattern:

1. Check availability (§3).
2. Create session (reuse default model; pass transform-specific instructions via session instructions).
3. For stdout streaming (default): call `streamResponse(to:)`, emit incremental deltas to stdout, then `collect()` for the final response.
4. For buffered output (`--no-stream` or `--write` / `-w`): call `respond(to:)`.
5. Return generated string after `TransformOutput.parse`.

Session instructions SHOULD encode the transform system prompt; user content SHOULD be the input text.

### 6.3 Dependencies

| Package | Use |
|---------|-----|
| [swift-argument-parser](https://github.com/apple/swift-argument-parser) | CLI parsing |
| Apple `FoundationModels` | On-device generation |

No other runtime dependencies in v0.1.

---

## 7. Implementation plan (semantic commits)

Each row is one **logical commit**. Review `git diff` before every commit. Run format/lint (§8) before committing.

| Step | Commit message (imperative) | Deliverable |
|------|----------------------------|-------------|
| 1 | `chore: initialise Swift package scaffold` | `Package.swift`, `.gitignore`, directory layout, empty `@main` |
| 2 | `feat(cli): add argument parsing and usage text` | `-t`, `-c`, `-h`, `-v`; exit codes for usage errors |
| 3 | `feat(input): read text from stdin and clipboard` | `InputSource`, empty-input handling |
| 4 | `feat(transform): define transform registry and presets` | `Transform` enum + instruction strings |
| 5 | `feat(model): integrate Foundation Models session` | Availability checks, generation, error mapping |
| 6 | `feat: wire pipeline from input through transform to stdout` | End-to-end CLI |
| 7 | `docs: add README and executable spec` | This spec + root README (may precede code if bootstrapping docs-first) |
| 8 | `chore: add SwiftFormat and lint configuration` | `.swiftformat`, optional CI stub |

Agents MAY combine steps 1–2 or split further if it improves reviewability, but MUST keep commits semantic and atomic.

---

## 8. Code quality

### Formatting

- Use **SwiftFormat** with a committed config (`.swiftformat`).
- Run before each commit: `swiftformat .`

### Lint / analyse

- `swift build` MUST succeed with no warnings (treat warnings as failures during development).
- Prefer `swift build -Xswiftc -warnings-as-errors` when supported.

### Style

- Swift 6 concurrency: mark types `Sendable` where crossing isolation boundaries.
- Prefer `struct` + protocols over heavy class hierarchies.
- User-facing strings in transforms may be multi-line; keep code paths testable by injecting a `ModelClient` protocol in tests (tests optional for v0.1 unless requested).

### Secrets

- Never commit API keys — v0.1 uses on-device model only.

---

## 9. Verification checklist

Before marking v0.1 complete, verify:

- [ ] `swift build -c release` produces `copyas` binary
- [ ] `copyas -h` prints usage
- [ ] `copyas -v` prints version
- [ ] `copyas summary --stdin` streams transformed text to stdout incrementally
- [ ] `copyas summary --stdin --no-stream` buffers stdout output
- [ ] `copyas markdown -w` reads clipboard and writes result back (manual test on AI-enabled Mac)
- [ ] `copyas pirate --stdin` rewrites piped text
- [ ] Missing `TRANSFORM` → exit `64`
- [ ] Unknown transform → exit `64`
- [ ] Empty input → exit `6`
- [ ] stderr stays silent on success (no progress spam)

---

## 10. Future extensions (out of scope for v0.1)

Document for planners; do not implement unless requested:

- Transforms: `grammar`, `eli5`, `tweet`, `json` (structured via `@Generable`)
- `--model` flag for `SystemLanguageModel.UseCase` variants
- Shell completions via ArgumentParser
- Unit tests with mocked `ModelClient`
- Homebrew formula

---

## 11. Agent execution notes

When implementing from this spec:

1. Read `README.md` § "For agents" first.
2. Implement in commit order (§7); one commit per step unless user directs otherwise.
3. After each step: `swift build`, SwiftFormat, review diff, commit.
4. Do not skip availability handling or exit-code mapping.
5. If Foundation Models API differs from §6.2, follow Apple’s current docs but preserve observable CLI behaviour in §4–§5.
6. Ask the user before adding transforms beyond §5 or dependencies beyond §6.3.

---

## 12. Document history

| Version | Date | Change |
|---------|------|--------|
| 0.1.0 | 2026-06-13 | Initial executable spec |
