# Code architecture

## Architecture boundary

SwiftUI-first, Swift-native, AppKit only as a last-resort escape hatch: SwiftUI owns app
lifecycle, document scenes, the Commands menu, chrome, settings, and panels. AppKit is used only
when a specific user-facing behavior cannot be achieved reliably in SwiftUI or pure Swift
(IME/text-input edge cases, native undo integration, accessibility gaps, responder-chain
behavior), and every such use is isolated behind a replaceable adapter. AppKit must never be the
app architecture; `NSDocument`, hand-built `NSMenu`, `NSWindowController`, and delegate-chain
patterns outside the isolated editor-surface adapter are defects once the SwiftUI migration
lands. See [HUMAN_GUIDANCE.md](HUMAN_GUIDANCE.md) for the decision record.

## Overview

This repo is being cut over to a lightweight macOS text editor, not a full IDE. The required path is the plain editor shell, file-backed editing, saving/reopening, command and status bars, Clean Text, syntax highlighting, and data-driven syntax definitions.

SwiftUI owns the app shell. AppKit and TextKit own the editor surface through a narrow bridge in `PlainTextEditorView` and `CodeEditTextView`.

## Major components

- [CodeEditApp.swift](../CodeEdit/CodeEditApp.swift): app entry point and scene setup.
- [CodeFileView.swift](../CodeEdit/Features/Editor/Views/CodeFileView.swift): document-to-editor bridge used by the plain editor surface.
- [PlainTextEditorView.swift](../CodeEdit/Features/Editor/Views/PlainTextEditorView.swift): AppKit/TextKit wrapper around `CodeEditTextView.TextView`.
- `CodeEdit/Features/Editor/PlainEditorTextCleaner.swift`: deterministic text-cleaning helpers used by the Clean Text command.
- `CodeEdit/Features/Editor/PlainEditorStatusReporter.swift`: shared status-label logic for cursor, words, indentation, encoding, line endings, and language labels.
- [CodeFileDocument.swift](../CodeEdit/Features/Documents/CodeFileDocument/CodeFileDocument.swift): document model for open, edit, autosave, and external-change handling.
- `CodeEditHighlighting`: shared highlighting model and Kate XML interpreter.
- `CodeEditTextView`: local text-view package that provides the editable text surface.
- `CodeEditLanguages`: language metadata used for syntax selection.
- `CodeEditSyntaxDefinitions`: syntax definition data files and the display-free syntax-highlight
  pipeline (see below).
- `DefaultThemes`: theme data files.

`Packages/CodeEditSourceEditor` is not a build dependency in
[Package.swift](../Package.swift); it is retained on disk as the harvest source for WP-F1
(porting editor-surface behavior into the plain-editor path), not as live app code.

## Syntax-highlight pipeline

`CodeEditSyntaxDefinitions` exposes the highlight pipeline as separately callable, display-free
stages ("ammeter" seams: each stage can be timed in isolation, like a meter clamped onto a
circuit). `CodeEditSyntaxDefinitions.highlightSpans(text:language:)` composes all three for the
common case; each stage is also public on its own:

- Parse: Kate XML text -> `SyntaxDefinition` (`parseDefinition(kateXML:)` for an uncached, single
  parse; `definition(forLanguage:)` for the cached lookup used in production, via
  `SyntaxDefinitionRepository`).
- Interpret: text + `SyntaxDefinition` -> `[TokenRun]` (`tokenRuns(text:definition:)`), walking the
  Kate context/rule state machine and emitting UTF-16 `location`/`length` offsets directly (no
  `String.Index` work in this stage).
- Span-map: `[TokenRun]` -> `[HighlightSpan]` (`spans(from:in:)`), resolving each token run's
  UTF-16 range to a `String.Index` range once and carrying the UTF-16 `nsRange` forward on the
  span so later consumers never reconvert.

Attribute application (`[HighlightSpan]` -> `NSTextStorage` attributes) is the one display-side
stage, and it lives in the app's `PlainSyntaxHighlighter`, outside this package.

Two process-wide caches keep repeated passes cheap: a `FirstCharFilter` prefilter skips a rule's
regex whenever the current UTF-16 code unit is provably not a character the rule's pattern can
start with, and `CompiledRegexCache` shares compiled `NSRegularExpression` instances across every
open document and pass instead of recompiling per interpreter run.

Each stage is independently timeable via the headless benchmark
(`scripts/highlight_benchmark.sh`), which prints per-stage `HIGHLIGHT_BENCH_STAGES` timings
(`parseMs`/`interpretMs`/`spanMapMs`) alongside the overall `HIGHLIGHT_BENCH` totals line and
writes both to the `test-results/perf/highlight_cold_pass.txt` artifact.

## Required build path

The plain-editor build should compile the app shell, editor view chain, settings, welcome/about surfaces, and shared UI helpers needed by the editor.

Required path:

- App shell and scene setup.
- Plain file-backed window shell for the editor.
- Plain editor view bridge.
- Document model, autosave, and external file-change reload.
- Top command bar and bottom status bar.
- Clean Text trailing space/tab trimming.
- Context-preserving Kate XML syntax highlighting for Swift.
- Syntax mode and text-format reporting.
- Deterministic live smoke and App Intents package smoke validation.
- Smoke output saved under `test-results/plain_editor_smoke/`.
- Data bundles for themes and syntax definitions.

## Outside this milestone

These surfaces remain legacy or optional during the cutover:

- Source control.
- Find/replace beyond the standard menu placeholder.
- LSP and semantic-token plumbing.
- Navigator UI.
- Inspector UI.
- Activity/task/notification chrome tied to the old IDE shell.
- Terminal and utility panes not required for the plain editor path.
- Old `SourceEditor`-style editor surfaces that duplicate the plain text editor path.

## Ownership split

- SwiftUI owns app structure, windows, commands, and standard controls.
- AppKit owns the text view bridge and other narrow platform behaviors.
- TextKit owns the actual editor editing mechanics through `CodeEditTextView`.
- Data files own syntax definitions and themes so new content can be added without rebuilding app logic.
- App Intents in this repo are smoke-test hooks only, not a user-facing automation product surface.

## Product shell styling

The Milestone 2 shell keeps Liquid Glass/system styling on control chrome only.
The top command bar and bottom status bar use standard SwiftUI buttons, text,
semantic colors, and `.regularMaterial`. The editor content remains on
`NSColor.textBackgroundColor` so dense code stays readable in light, dark, high
contrast, and reduced-transparency contexts.

## Known gaps

- The target still contains legacy folders that are being removed from the required build path.
- Some old feature trees remain in the repo for reference while the plain-editor cutover finishes.
- Light/dark visual validation uses semantic system materials and colors. Screenshot evidence still depends on display access; current smoke logs record ScreenCaptureKit TCC denial when capture is unavailable.
- Find and Replace are menu placeholders only in Milestone 2. Active in-editor find/replace and regex behavior are deferred.
- Ambiguous BOM-less non-UTF files may not be reliably distinguished by Foundation's current decoding path; the editor keeps the fallback non-blocking.
