# File structure

## Top-level layout

- `CodeEdit`: active app source. `Package.swift` compiles this target with no
  exclude list; every file under `CodeEdit/` is live, compiled code.
- `Packages`: local Swift packages used by the app and editor.
  `CodeEditHighlighting`, `CodeEditLanguages`, `CodeEditTextView`, and
  `CodeEditSyntaxDefinitions` are build dependencies in
  [`Package.swift`](../Package.swift). `CodeEditSourceEditor` was kept as a WP-F1 harvest
  source (never a build dependency); patch 19 deleted it once its find-panel behavior was
  ported into `CodeEdit/Features/Find/`.
- `CodeEditTests`: unit and feature tests. Only `CodeEditTests/PackageSmoke` is
  the live SwiftPM testTarget path.
- `scripts`: shell/Python helpers invoked directly (smoke test, highlight benchmark, app
  bundle/icon generation), not part of the SwiftPM build.
- [`docs/`](.): repo guidance, architecture notes, changelog, and supporting documentation.
- `devel`: scripts and maintenance tooling (changelog rotation, release prep, version bump).
- `tests`: repo-wide Python pytest checks (lint, ASCII compliance, Markdown links, shebangs).
- `Resources`: shared app resources.
- `DefaultThemes`: theme data files (input for the WP-F2 theme-format conversion).
- `ThirdParty`: vendored upstream license/attribution notes (for example
  `ThirdParty/KSyntaxHighlighting`) credited by the syntax-highlight pipeline.

## Key subtrees

- `CodeEdit/Features/Editor`: plain editor views, document bridge, status reporting, Clean Text, and editor state.
- `CodeEdit/Features/Documents`: document model and window/document coordination.
- `CodeEdit/Features/Support`: shared Application Support directory policy.
- `CodeEditTextView`: text view implementation package.
- `CodeEditLanguages`: language metadata package.
- `CodeEditSyntaxDefinitions`: syntax definition data package.
- `CodeEditHighlighting`: shared highlighting model and Kate XML interpreter.
- `test-results/plain_editor_smoke/`: generated smoke logs for the live plain-editor validation path.

## Generated artifacts

- SwiftPM build output lives under `.build/` and `build/` (both gitignored) and is generated.
- Temporary scratch data may appear under `.tmp/` and is generated.
- `test-results/` (gitignored) holds smoke-test and benchmark output, including
  `test-results/plain_editor_smoke/` and `test-results/perf/highlight_cold_pass.txt`.
- Xcode-derived data is not part of the source layout and should stay out of the repo tree.

## Documentation map

- [`REPO_STYLE.md`](REPO_STYLE.md): repo rules and workflow.
- [`PYTHON_STYLE.md`](PYTHON_STYLE.md): Python style for `tests/` and `devel/` scripts.
- [`PYTEST_STYLE.md`](PYTEST_STYLE.md): pytest conventions for `tests/`.
- [`MARKDOWN_STYLE.md`](MARKDOWN_STYLE.md): Markdown writing conventions.
- [`SWIFT_STYLE.md`](SWIFT_STYLE.md): Swift and SwiftUI guidance.
- [`LIQUID_GLASS.md`](LIQUID_GLASS.md): macOS 26 UI guidance.
- [`SCOPE.md`](SCOPE.md): what is in and out of scope for the plain-editor cutover.
- [`HUMAN_GUIDANCE.md`](HUMAN_GUIDANCE.md): durable human preferences and decisions.
- [`CODE_ARCHITECTURE.md`](CODE_ARCHITECTURE.md): intended post-cutover architecture.
- [`FILE_STRUCTURE.md`](FILE_STRUCTURE.md): this folder map.
- [`CHANGELOG.md`](CHANGELOG.md): change history.

## Where to add new work

- Editor features: `CodeEdit/Features/Editor/`.
- Document behavior: `CodeEdit/Features/Documents/`.
- Shared packages: `Packages/`.
- Tests: `CodeEditTests/PackageSmoke/`.
- Docs and repo notes: `docs/`.
- Build or maintenance scripts: `devel/` or the repo root for small wrappers.

## Legacy tree removal

WP-P1 (2026-07-09) deleted every tree the Package.swift exclude list had
carved out of the build path, plus the matching legacy test/UI-test trees and
dead root-level helper-app directories. `Package.swift` now compiles
`CodeEdit/` with no exclude list. See `docs/CHANGELOG.md` for the removed
tree list.

WP-P5 (2026-07-09) removed dead code inside that live compile surface,
verified by reference-count audit
(`docs/active_plans/audits/live_target_dead_code_audit.md`): the About
window feature (`CodeEdit/Features/About/`) and its now-orphaned
`Packages/AboutWindow` and `Packages/CodeEditSymbols` dependencies, the
Keybindings feature, the KeyChain cluster, the dead SmokeTesting App
Intents file, unused Utils standalone types and extensions, the
`PlainEditorCommands` SwiftUI Commands struct (unreachable from the
hand-built AppKit menu), the legacy `SYNTAX_THEME_VARIANT=rotated` syntax
theme branch, `CodeEditUI/` (its only tracked file), and `AppCast/`.
