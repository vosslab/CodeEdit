# Milestone 3 To-Do Checklist

Milestone 3 tracks the major feature gaps between docs/SCOPE.md must-haves and the code as it
stands after Milestone 1 and Milestone 2. Every box below is unchecked: nothing in this file is
done yet, even where a foundation already shipped (noted in prose next to the relevant item).
Execution detail, owners, and acceptance criteria for each gap live in
docs/active_plans/active/scope_closure_plan.md; this checklist is the human-readable tracking
layer over those work packages, not a replacement for them.

---

## AppKit shell to SwiftUI (MS, WP-S1..S3)

Goal: replace the AppKit app shell with a SwiftUI `App` + `DocumentGroup`, keeping AppKit only
inside the isolated `TextView` bridge adapter.

- [ ] App launches via a SwiftUI `App` + `DocumentGroup` scene, replacing `@main enum
  CodeEditMain` and the hand-built `NSDocument`/`NSWindow` chain in `CodeEdit/CodeEditApp.swift`.
  Document-model decision (WP-S0): keep `CodeFileDocument` as the `NSDocument` model behind a
  `DocumentGroup` bridge, not a SwiftUI-native `ReferenceFileDocument` -- a measured prototype
  failed the autosave-debounce and same-`NSTextStorage`-reload gates -- with the single sanctioned
  document-layer AppKit bridge file `CodeFileDocumentBridge.swift` created by WP-S1; see
  docs/active_plans/decisions/document_architecture_decision.md.
- [ ] SwiftUI `Commands` menu replaces the hand-built `NSMenu` (`PlainEditorMainMenu`); every
  File/Edit/Find command reaches the active editor and keyboard shortcuts still work.
- [ ] AppKit survives only inside the isolated `TextView` bridge adapter
  (`PlainTextEditorView.swift` over `CodeEditTextView.TextView`), per the SwiftUI-first
  principle recorded in docs/HUMAN_GUIDANCE.md. Spike decision: SwiftUI's `TextEditor` failed
  the editor gates (keystroke p95 140.56 ms vs a 16 ms budget, span-apply 159.07 ms vs 50 ms,
  cursor collapses to end-of-file on every attribute write, and a ~1 MB document never mounts),
  so the TextKit bridge stays as the one replaceable adapter -- see
  docs/active_plans/decisions/text_engine_decision.md.
- [ ] Superseded AppKit shell code (`PlainEditorMainMenu`, the old `NSDocument`-driven window
  creation path, and any dead `PlainEditorCommands`) is deleted, not left dormant.

## Find and Replace (WP-F1)

Goal: give the editor a working in-document find/replace surface; today the Find menu items send
`NSTextView.performFindPanelAction` to a `TextView` that is a plain `NSView` and never responds.

- [ ] Cmd-F opens a find bar with literal and regex modes.
- [ ] Next/previous match navigation moves the visible selection.
- [ ] Replace and Replace All mutate the active document and are undoable as a single operation.
- [ ] The panel is ported from the CodeEditSourceEditor find implementation
  (`Packages/CodeEditSourceEditor`), not built from scratch.

## Theme data files (WP-F2)

Goal: move syntax colors out of hardcoded Swift and into the data-driven format already
specified in docs/THEME_FORMAT.md.

- [ ] A loader reads themes from the docs/THEME_FORMAT.md YAML schema (schema already shipped;
  the loader and runtime wiring are not).
- [ ] Bundled default light and dark themes ship as data files, not Swift structs.
- [ ] User themes load from `~/Library/Application Support/SwiftlyCodeEdit/Themes/` with live
  switching, no rebuild required.
- [ ] The hardcoded `PlainSyntaxTheme` palette in `PlainSyntaxHighlighter.swift` is removed.

## User syntax definitions (WP-F3)

Goal: let users add a new highlighted language without rebuilding the app; today all 409 Kate
XML definitions are compiled into the bundle.

- [ ] A Kate XML file dropped into
  `~/Library/Application Support/SwiftlyCodeEdit/Syntax/` highlights a new language after a
  relaunch, with no rebuild.
- [ ] A user syntax file wins over a bundled file on name collision.
- [ ] A malformed user XML file is logged and skipped; the app keeps running.

## Clean Text menu (WP-F4)

Goal: grow Clean Text from the single trailing-whitespace-trim action shipped in Milestone 2
into the full safe cleaning set.

- [ ] Normalize line endings to LF or CRLF.
- [ ] Ensure a final newline.
- [ ] Convert tabs to spaces.
- [ ] Convert spaces to tabs.
- [ ] Normalize smart punctuation to ASCII as an explicit opt-in action (never applied silently).
- [ ] Each action is undoable and covered by a unit test with inline fixtures. Trailing-whitespace
  trim already shipped in Milestone 2 and is the one action already meeting this bar.

## Proper settings dialog (WP-F5)

Goal: replace command-bar-only controls for static preferences with a standard macOS Settings
scene; candidate WP-F5, user-requested 2026-07-09, with execution detail to be added to
`docs/active_plans/active/scope_closure_plan.md`.

- [x] A standard macOS Settings scene (Cmd+,) built in SwiftUI per the SwiftUI-first principle in
  `docs/HUMAN_GUIDANCE.md`, replacing command-bar-only controls for static or permanent
  preferences. Closed 2026-07-10, WP-F5 review PASS: Settings scene (patches 15-16) built via
  the standard Cmd+, SwiftUI Settings scene.
- [x] Font family and size selection persisted across launches. Foundation already shipped: the
  `PlainEditor.fontFamily` and `PlainEditor.fontSize` AppStorage keys are currently driven from the
  command bar's A- and A+ controls. Closed 2026-07-10, WP-F5 review PASS: font family/size now
  live in the Settings scene with the same persisted AppStorage keys, gated by the
  `SETTINGS_APPLIED` fontSize marker in `scripts/plain_editor_smoke.sh`.
- [x] Theme selection surface that binds to the WP-F2 theme loader when it lands. Closed
  2026-07-10, WP-F5 review PASS: theme picker binds to the WP-F2 in-memory theme registry, gated
  by the `SETTINGS_APPLIED` theme marker in the smoke script.
- [x] Editor defaults for indentation (tabs versus spaces, width) and the default line ending for
  new files. Closed 2026-07-10, WP-F5 review PASS: indentation style/width and default line
  ending are persisted Settings-scene fields per the WP-F5 review.
- [x] Settings changes apply live to open windows without relaunch. Closed 2026-07-10, WP-F5
  review PASS: live-apply observability seam plus `SETTINGS_APPLIED` fontSize/theme gates in
  `scripts/plain_editor_smoke.sh` confirm changes reach open windows without relaunch.

## Large-file performance (WP-Q1 follow-on / WP-Q2)

Goal: keep typing responsive on large files; today every keystroke triggers a full-document
rehighlight and a full status recomputation.

- [ ] Highlighting is viewport-first so a 1 MB-plus file paints fast on cold open. Cold highlight
  already improved from 6293 ms to 67 ms on normal-sized files in earlier work, but that gain does
  not yet extend to viewport-first behavior on very large files.
- [ ] Keystroke-triggered rehighlighting is bounded to the edited region (edited-line window or
  visible range), not the whole document.
- [ ] Status bar recomputation no longer rescans the full document on every keystroke.
- [ ] A repeatable benchmark proves p95 keystroke handling under 16 ms on a 1 MB source file,
  recorded in `test-results/`. Per-stage benchmark seams already exist from earlier profiling
  work; the bounded-rehighlight implementation and the gate itself do not yet exist.

## Liquid Glass chrome (WP-G1)

Goal: move the command ribbon and status bar from legacy `.regularMaterial` to macOS 26
`glassEffect` styling per docs/LIQUID_GLASS.md.

- [ ] Command ribbon adopts `glassEffect` per docs/LIQUID_GLASS.md.
- [ ] Status bar adopts `glassEffect` per docs/LIQUID_GLASS.md.
- [ ] The editor text surface itself is left untouched by glass styling; only chrome changes.
- [ ] Captured evidence exists for light mode, dark mode, and reduced-transparency. Milestone 2
  captured only one light-mode screenshot; no dark-mode or reduced-transparency evidence exists
  anywhere in the repo today.

## Document lifecycle correctness (candidate work packages from docs/active_plans/audits/document_lifecycle_audit.md)

Goal: close the four HIGH-severity findings from the pre-migration document lifecycle audit
before or during the SwiftUI shell migration.

- [ ] Undo/redo clears the document's dirty flag once the buffer matches the last-saved content,
  instead of `updateChangeCount(.changeDone)` firing unconditionally on every text-change
  callback including undo/redo replays.
- [ ] An external file change while the document has unsaved edits surfaces a conflict to the
  user instead of the current silent no-op (`presentedItemDidChange`'s guard falls through with
  no reload and no alert when `isDocumentEdited` is true).
- [ ] Reload surfaces decode errors instead of swallowing them with `try?`, so an external
  rewrite in an unsupported encoding produces a visible alert rather than a stale window with an
  already-advanced modification date.
- [ ] Reload resets the `TextView`'s undo stack after loading new content into the shared text
  storage, so a post-reload Undo cannot replay a stale operation against offsets that no longer
  match the current text.

---

## Milestone 3 verification

- [ ] `pytest tests/test_markdown_links.py` passes.
- [ ] `pytest tests/test_ascii_compliance.py` passes.
- [ ] `./build_debug.sh` passes.
- [ ] `./scripts/plain_editor_smoke.sh` passes.
- [ ] `swift test` passes.
- [ ] `docs/CHANGELOG.md` records each closed gap.
