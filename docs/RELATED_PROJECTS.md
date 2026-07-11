# Related projects

Current milestone: lightweight macOS text editor with syntax highlighting, not an IDE.

## Confirmed related projects

### CodeEdit
- Relationship: upstream source and parent project (hard fork)
- Link: https://github.com/CodeEditApp/CodeEdit
- Evidence: `git remote -v` shows `origin` as `git@github.com:vosslab/CodeEdit.git`, and the
  commit history starts from an imported CodeEdit tree before repo-specific rework began.
- Notes: useful for understanding inherited architecture, which is trimmed aggressively where it
  conflicts with the current plain-editor scope. See `docs/SCOPE.md` for scope boundaries.

### CodeEditTextView
- Relationship: direct dependency (vendored SwiftPM package)
- Link: https://github.com/CodeEditApp/CodeEditTextView
- Evidence: `Package.swift` declares `.package(path: "Packages/CodeEditTextView")` as a live
  dependency; `Packages/CodeEditTextView/README.md` links back to
  `github.com/CodeEditApp/CodeEditTextView`.
- Notes: the primary vendored text-editing surface backing the plain-editor path.

### CodeEditLanguages
- Relationship: direct dependency (vendored SwiftPM package)
- Link: https://github.com/CodeEditApp/CodeEditLanguages
- Evidence: `Package.swift` declares `.package(path: "Packages/CodeEditLanguages")` as a live
  dependency; `Packages/CodeEditLanguages/README.md` describes it as providing language
  identifiers, file-extension detection, and bundled syntax-definition resources for this repo.
- Notes: its README has been trimmed locally to drop parser-runtime language (this repo does not
  use tree-sitter parser packages); the current syntax-highlighting path is the Kate XML pipeline
  in `CodeEditSyntaxDefinitions` and `CodeEditHighlighting` instead.

### CodeEditSourceEditor (harvested and deleted)
- Was previously listed in this doc as a vendored find-panel harvest source, never declared as a
  dependency in `Package.swift`. WP-F1 patch 18 ported its find-and-replace panel behavior into
  `CodeEdit/Features/Find/`; patch 19 then deleted the 199-file vendored copy under
  `Packages/CodeEditSourceEditor/` (`git rm -r Packages/CodeEditSourceEditor`), its harvest purpose
  fulfilled. No longer present in this repo's tree; a reference clone remains at
  `OTHER_REPOS/CodeEditSourceEditor/` per `OTHER_REPOS/repos.txt`. Upstream:
  https://github.com/CodeEditApp/CodeEditSourceEditor

### KDE syntax-highlighting (KSyntaxHighlighting)
- Relationship: format source for syntax-definition data (not a code dependency)
- Link: https://github.com/KDE/syntax-highlighting
- Evidence: XML syntax-definition files bundled under `CodeEditSyntaxDefinitions` (for example
  `swift.xml`) use the Kate `<!DOCTYPE language>` XML schema; `docs/SYNTAX_RULESET_COMPARISON.md`
  and `docs/CODE_ARCHITECTURE.md` document the "Kate XML interpreter" pipeline this repo builds
  against that format.
- Notes: `CodeEditHighlighting` and `CodeEditSyntaxDefinitions` are first-party packages authored
  in this fork (no CodeEditApp upstream link in their own manifests); they consume Kate-format
  syntax-definition data rather than vendoring KDE's C++ engine or Swift code.

### CodeEditorView
- Relationship: same-domain SwiftUI code editor component, prior art
- Link: https://github.com/mchakravarty/CodeEditorView
- Evidence: cloned into `OTHER_REPOS/CodeEditorView/` as a read-only reference; the upstream
  README describes a SwiftUI code editor view for iOS, visionOS, and macOS built on TextKit 2 with
  syntax highlighting, configurable themes, inline messages, bracket matching, completion, and a
  minimap.
- Notes: useful for SwiftUI/TextKit 2 editor architecture; some features exceed the current
  plain-editor milestone.

### SwiftEdit
- Relationship: historical prior art
- Link: https://github.com/jpsim/SwiftEdit
- Evidence: cloned into `OTHER_REPOS/` per `OTHER_REPOS/repos.txt`; described upstream as a
  proof-of-concept Swift editor with Swift syntax highlighting using SourceKitten.
- Notes: old enough that it should not define current Swift 6 or macOS 26 architecture.

### SwiftCodeEditor
- Relationship: same-domain SwiftUI editor component, cautionary reference
- Link: https://github.com/jankammerath/SwiftCodeEditor
- Evidence: cloned into `OTHER_REPOS/SwiftCodeEditor/` per `OTHER_REPOS/repos.txt`; described
  upstream as a SwiftUI `TextEditor` view with syntax highlighting via Highlight.js through
  Highlightr.
- Notes: useful only as SwiftUI packaging prior art; its JavaScript-based highlighter stack does
  not match this repo's native Kate-XML-based direction.

### rich-editor-swiftui
- Relationship: adjacent editor work, low relevance
- Link: https://github.com/canopas/rich-editor-swiftui
- Evidence: cloned into `OTHER_REPOS/rich-editor-swiftui/` per `OTHER_REPOS/repos.txt`; the
  project is a SwiftUI rich-text editor wrapper, not a source-code editor.
- Notes: possibly useful for SwiftUI/AppKit bridging concepts only.

### Editor (mmackh)
- Relationship: external reference project, unevaluated
- Link: https://github.com/mmackh/Editor
- Evidence: cloned into `OTHER_REPOS/Editor/` per `OTHER_REPOS/repos.txt`.
- Notes: evaluate from the upstream README, package manifest, license, and source structure
  before assigning it architectural weight; not yet confirmed as relevant beyond the clone itself.

### Building a Code Editor Using SwiftUI (article)
- Relationship: article-level prior art
- Link: https://sebwhitfield.medium.com/building-a-code-editor-using-swiftui-bb74819b5c1f
- Evidence: listed in `OTHER_REPOS/repos.txt` and saved as an HTML capture in `OTHER_REPOS/`.
- Notes: useful as design background, not as an implementation source of truth.

## Commonly confused unrelated projects

### CodeEditKit
- Was previously listed in this doc as an inherited CodeEdit-ecosystem dependency. It shipped in
  `Packages/CodeEditKit` but was never a `Package.swift` dependency, and was deleted from the repo
  on 2026-07-09 as part of a 721-file legacy purge (see `docs/CHANGELOG.md`). No longer relevant
  to this repo's build.

### WelcomeWindow
- A local package under `Packages/WelcomeWindow` that was never a `Package.swift` dependency;
  deleted on 2026-07-09 in the same legacy purge as CodeEditKit. Not a live dependency.

### AboutWindow
- Was previously listed in this doc as a direct dependency (vendored SwiftPM package). It shipped
  in `Packages/AboutWindow` and backed the About window feature (`CodeEdit/Features/About/`), but
  WP-P5 deleted the dead About window feature and its now-orphaned `Packages/AboutWindow`
  dependency on 2026-07-09 as part of the live-target dead-code removal (see
  `docs/CHANGELOG.md`). No longer a live dependency.

### CodeEditSymbols
- Was previously listed in this doc as a direct dependency (vendored SwiftPM package). It shipped
  in `Packages/CodeEditSymbols` and supplied custom SF Symbols-derived assets for the About window
  feature, but WP-P5 deleted it on 2026-07-09 alongside the About window feature it was orphaned
  by (see `docs/CHANGELOG.md`). No longer a live dependency.

## Evidence notes

Confirmed entries come primarily from `Package.swift` (the four live SwiftPM path dependencies:
CodeEditHighlighting, CodeEditLanguages, CodeEditTextView, CodeEditSyntaxDefinitions), the
vendoring commit `a61afbd`, and the vendored packages' own README files that still link back to
`github.com/CodeEditApp/...`. `CodeEditSourceEditor` was vendored but never wired as a dependency;
WP-F1 patch 19 deleted it from the tree once its find-panel harvest was complete. `CodeEditHighlighting` and
`CodeEditSyntaxDefinitions` carry no CodeEditApp upstream link in their own manifests; their
relevant upstream is the KDE `syntax-highlighting` (KSyntaxHighlighting) project, whose XML schema
their bundled `.xml` definition files and Swift interpreter target. `OTHER_REPOS/repos.txt` is the
source list for the read-only external reference clones. AboutWindow and CodeEditSymbols were
deleted from `Package.swift` by WP-P5's dead-code purge and moved to "Commonly confused unrelated
projects" below.
