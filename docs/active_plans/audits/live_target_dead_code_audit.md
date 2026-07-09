# Live target dead code audit

Read-only reference-count audit of the live compile surface, covering dead code
that the WP-P1/WP-P2 known-dead lists do not name. Scope: unreferenced types,
orphan files, dead env hooks, and tests exercising dead code inside the live
SwiftPM target. No production code, tests, or `Package.swift` were edited;
deletions execute in a later work package after manager review.

Author: dead-code-sweep. Date: 2026-07-09. Plan: `scope_closure_plan.md` milestone MP.

## Live compile surface

Established from `Package.swift` (the `exclude:` array is now empty, so the whole
`CodeEdit/` tree compiles):

- Executable target `CodeEdit`: 68 Swift files under `CodeEdit/`.
- Test target `CodeEditTests`: 7 files under `CodeEditTests/PackageSmoke/`.
- Six declared package dependencies, all product-linked to the `CodeEdit` target:
  `AboutWindow`, `CodeEditHighlighting`, `CodeEditLanguages`, `CodeEditTextView`,
  `CodeEditSyntaxDefinitions`, `CodeEditSymbols`.

Everything flagged below lives inside that surface. Evidence is word-boundary
`grep` reference counting across `CodeEdit` and `CodeEditTests/PackageSmoke`,
excluding each symbol's own declaring file. The final correctness gate is the
deletion agent's `swift build` / `swift test`; this audit does not run them.

## Summary counts

- DELETE-NOW: 50 whole files + 2 in-file symbol removals (plus 2 orphaned package
  trees, below).
- DELETE-WITH-WP: 2 package dependencies (`AboutWindow`, `CodeEditSymbols`),
  orphaned only because the dead About subtree imports them; removal needs the
  same deletion WP plus `Package.swift` edits.
- KEEP: 4 packages, the undo test suite, and the live editor/menu symbols listed
  at the end.

Largest single DELETE-NOW item: the `CodeEdit/Features/About/` subtree (10 files),
which also drags the `AboutWindow` and `CodeEditSymbols` package dependencies dead.

## Known leads (verified first)

### PlainEditorCommands -- DELETE-NOW

- Location: `CodeEdit/CodeEditApp.swift:440` (`private struct PlainEditorCommands: Commands`),
  body spans lines 440-545 (~106 lines).
- Evidence: `grep -rnw PlainEditorCommands CodeEdit/ CodeEditTests/ Packages/`
  gives 1 hit (the declaration). Zero references.
- Cleared hazards: it conforms to SwiftUI's `Commands` protocol, which is only
  consumable from a SwiftUI `App`'s `.commands { }`. `grep -rn "\.commands|: App|some Scene|WindowGroup|DocumentGroup" CodeEdit/`
  returns 0 hits: the app is a hand-built AppKit `@main enum CodeEditMain` +
  `PlainEditorMainMenu.make()`, so nothing can instantiate it. It is `private`,
  so no out-of-file reference is possible.
- Action: delete lines 440-545 of `CodeEdit/CodeEditApp.swift`.

### UndoManagerRegistration / UndoManagerRegistrationTests -- KEEP

- There is no `UndoManagerRegistration.swift` in the tracked tree
  (`git ls-files | grep -i undomanager` returns only the test file and the
  package's `Packages/CodeEditTextView/.../CEUndoManager.swift`). The type the
  lifecycle audit named was already removed in the WP-P1 purge.
- `CodeEditTests/PackageSmoke/UndoManagerRegistrationTests.swift` exercises
  `CEUndoManager` and `TextView.setUndoManager` from the `CodeEditTextView`
  package. This is NOT dead code: `TextView` creates a `CEUndoManager` in its
  init (`Packages/CodeEditTextView/.../TextView.swift:354`), and the live menu
  undo/redo calls `activeTextView?.undoManager?.undo()`
  (`CodeEdit/CodeEditApp.swift:295-302`, `CodeFileView.swift:39-40`), which
  returns that `CEUndoManager`. The test validates the live undo machinery.
- Note: the test file name references a deleted type. A rename to
  `CEUndoManagerTests` would remove the misnomer, but that is cleanup, not dead
  code, and is out of this audit's scope.

### Packages/AboutWindow -- DELETE-WITH-WP (orphaned)

- It is a declared dependency AND product-linked (`Package.swift:18,29`).
- But `grep -rln "import AboutWindow" CodeEdit/` returns 3 files, all inside the
  dead About subtree: `Features/About/AboutFooterView.swift`,
  `Features/About/Contributors/ContributorsView.swift`,
  `Features/About/Acknowledgements/Views/AcknowledgementsView.swift`.
- Reachable only from dead code. Once the About subtree is deleted, remove the
  `Packages/AboutWindow` tree and its two `Package.swift` lines (dependency 18,
  product 29).

### Packages/CodeEditHighlighting -- KEEP (verified, nothing extra orphaned)

- Confirmed live (prior WP-P1 scout; `HighlightSpan` used by
  `PlainSyntaxHighlighter.swift` and `CodeFileView.swift`).
- No additional orphan surfaced inside it in this pass; per-file audit of a kept
  package's internal sources is a package-scoped follow-up if desired.

## Additional orphaned package dependency

### Packages/CodeEditSymbols -- DELETE-WITH-WP (orphaned)

- `grep -rln "import CodeEditSymbols" CodeEdit/` returns exactly one file:
  `Features/About/Contributors/ContributorRowView.swift`, inside the dead About
  subtree. Reachable only from dead code.
- Once the About subtree is deleted, remove the `Packages/CodeEditSymbols` tree
  and its two `Package.swift` lines (dependency 23, product 34).

`CodeEditLanguages`, `CodeEditTextView`, and `CodeEditSyntaxDefinitions` are KEEP:
`CodeLanguage` is used in `CodeFileDocument.swift:395-399` and
`PlainSyntaxHighlighter.swift:60-73`; `TextView` backs the live editor
(`PlainTextEditorView.swift`); the syntax engine drives highlighting.

## DELETE-NOW clusters (whole files)

### About subtree -- 10 files

Nothing outside `CodeEdit/Features/About/` references it:
`grep -rn "About|Acknowledge|Contributor" CodeEdit/ --include=*.swift -l | grep -v "Features/About/"`
returns 0, and there is no About menu item or About-panel selector
(`grep -n "About|aboutPanel|orderFrontStandard" CodeEdit/CodeEditApp.swift`
returns 0). The subtree only references itself. Each type also has zero external
references in the type sweep (`AboutFooterView`, `AboutSubtitleView`,
`AcknowledgementsView`, `AcknowledgementsViewModel`, `AcknowledgementRowView`,
`AcknowledgementPin`, `AcknowledgementPackageState`, `BlurButtonStyle`,
`ContributorsView`, `ContributorsViewModel`, `ContributorRowView`, `Contributor`).

```
git rm CodeEdit/Features/About/AboutFooterView.swift
git rm CodeEdit/Features/About/AboutSubtitleView.swift
git rm CodeEdit/Features/About/Acknowledgements/ViewModels/AcknowledgementsViewModel.swift
git rm CodeEdit/Features/About/Acknowledgements/Views/AcknowledgementRowView.swift
git rm CodeEdit/Features/About/Acknowledgements/Views/AcknowledgementsView.swift
git rm CodeEdit/Features/About/Acknowledgements/Views/ParsePackagesResolved.swift
git rm CodeEdit/Features/About/BlurButtonStyle.swift
git rm CodeEdit/Features/About/Contributors/ContributorRowView.swift
git rm CodeEdit/Features/About/Contributors/ContributorsView.swift
git rm CodeEdit/Features/About/Contributors/Model/Contributor.swift
```

### Keybindings feature -- 3 files + 1 resource

`CommandManager`, `KeybindingManager`, `KeyboardShortcutWrapper`, `Command`, and
`EventModifierEnvironmentKey` each appear only in their own files (self-
referential singletons; `grep -rnw` shows every hit inside `Features/Keybindings/`).
The menu is hand-built with hardcoded key equivalents, so `CommandManager.shared`
and `KeybindingManager.shared` are never invoked. The `default_keybindings.json`
resource is loaded only by the dead `KeybindingManager.swift:39`.

```
git rm CodeEdit/Features/Keybindings/CommandManager.swift
git rm CodeEdit/Features/Keybindings/KeybindingManager.swift
git rm CodeEdit/Features/Keybindings/ModifierKeysObserver.swift
git rm CodeEdit/Features/Keybindings/default_keybindings.json
```

Also remove the resource line in `Package.swift:39`
(`.process("Features/Keybindings/default_keybindings.json")`).

### KeyChain cluster -- 3 files

`CodeEditKeychain` has zero external references (`grep -rnw CodeEditKeychain`
= 2 hits, both in its own file). `CodeEditKeychainConstants` and
`CodeEditKeychainAccessOptions` (declared in the misnamed
`KeychainSwiftAccessOptions.swift`) are referenced only within the cluster.

```
git rm CodeEdit/Utils/KeyChain/CodeEditKeychain.swift
git rm CodeEdit/Utils/KeyChain/CodeEditKeychainConstants.swift
git rm CodeEdit/Utils/KeyChain/KeychainSwiftAccessOptions.swift
```

### SmokeTesting AppIntents -- 1 file

`CodeEdit/Features/SmokeTesting/PlainEditorSmokeIntents.swift`: every symbol
(`PlainEditorSmokeIntentRunner`, `PlainEditorSmokeIntentError`, and the five
`AppIntent` structs) is referenced only inside this file. Cleared hazards:
`grep -rn "Intent|shortcuts|AppIntent|SmokeTesting" scripts/ tests/e2e/`
returns 0 -- the live smoke path is env-var + screenshot driven
(`scripts/plain_editor_smoke.sh`), not intent driven, and the SwiftPM build has
no AppIntents metadata-extraction phase to auto-register the intents. Superseded
scaffolding.

```
git rm CodeEdit/Features/SmokeTesting/PlainEditorSmokeIntents.swift
```

### Utils standalone -- 5 files

Type-name sweep shows zero external references for `RegexFormatter`,
`TrimWhitespaceFormatter`, `Limiter`, `Loopable` (no conformers), and
`SearchableSettingsPage` (no conformers). The `Formatter`-override method names
(`getObjectValue`, `isPartialStringValid`) that a member sweep flags as "used"
are generic collisions, not real references.

```
git rm CodeEdit/Utils/Formatters/RegexFormatter.swift
git rm CodeEdit/Utils/Formatters/TrimWhitespaceFormatter.swift
git rm CodeEdit/Utils/Limiter.swift
git rm CodeEdit/Utils/Protocols/Loopable.swift
git rm CodeEdit/Utils/Protocols/SearchableSettingsPage.swift
```

### Utils extensions and helpers -- 27 files

Only two Utils files are live: `Utils/DebugRuntimeLog.swift` (`debugRuntimeLog`
used across the app) and `Utils/Extensions/String/String+Lines.swift`
(`getFirstLines`/`getLastLines` used in `CodeFileDocument.swift:401-402`).
`Utils/SceneID.swift` and `Utils/WindowObserver.swift` were checked separately
(SceneID is live; `WindowObserver` is dead, listed below). Every other Utils
extension/helper is dead: distinctive-token greps
(`.md5`, `.sha256`, `.second`, `[safe:`, `.if(`, `isHovering`, `caption3`,
`hexString`, `semverString`, `versionString`, `@FocusedValue`, `unzipItem`,
`NSTableView`, `.localized`, etc.) return zero live call sites outside `Utils/`
and the dead About subtree. Files in the About-only second order
(`Color+HEX`, `Bundle+Info`, `OperatingSystemVersion+String`, `Int+HexString`)
are consumed only by the dead About views.

```
git rm CodeEdit/Utils/Extensions/Array/Array+Index.swift
git rm CodeEdit/Utils/Extensions/Array/Array+SortURLs.swift
git rm CodeEdit/Utils/Extensions/Bundle/Bundle+Info.swift
git rm CodeEdit/Utils/Extensions/Collection/Collection+subscript_safe.swift
git rm CodeEdit/Utils/Extensions/Color/Color+HEX.swift
git rm CodeEdit/Utils/Extensions/FileManager/FileManager+MakeExecutable.swift
git rm CodeEdit/Utils/Extensions/FileManager/FileManager+Unzip.swift
git rm CodeEdit/Utils/Extensions/Int/Int+HexString.swift
git rm CodeEdit/Utils/Extensions/NSApplication/NSApp+openWindow.swift
git rm CodeEdit/Utils/Extensions/NSTableView/NSTableView+Background.swift
git rm CodeEdit/Utils/Extensions/NSWindow/NSWindow+Child.swift
git rm CodeEdit/Utils/Extensions/OperatingSystemVersion/OperatingSystemVersion+String.swift
git rm CodeEdit/Utils/Extensions/String/String+AppearancesOfSubstring.swift
git rm CodeEdit/Utils/Extensions/String/String+Character.swift
git rm CodeEdit/Utils/Extensions/String/String+Escaped.swift
git rm CodeEdit/Utils/Extensions/String/String+HighlightOccurrences.swift
git rm CodeEdit/Utils/Extensions/String/String+MD5.swift
git rm CodeEdit/Utils/Extensions/String/String+Ranges.swift
git rm CodeEdit/Utils/Extensions/String/String+RemoveOccurrences.swift
git rm CodeEdit/Utils/Extensions/String/String+SHA256.swift
git rm CodeEdit/Utils/Extensions/String/String+ValidFileName.swift
git rm CodeEdit/Utils/Extensions/Text/Font+Caption3.swift
git rm CodeEdit/Utils/Extensions/View/View+focusedValue.swift
git rm CodeEdit/Utils/Extensions/View/View+if.swift
git rm CodeEdit/Utils/Extensions/View/View+isHovering.swift
git rm CodeEdit/Utils/Extensions/ZipFoundation/ZipFoundation+ErrorDescrioption.swift
git rm CodeEdit/Utils/FocusedValues.swift
```

### WindowObserver -- 1 file

`CodeEdit/WindowObserver.swift`: `struct WindowObserver` has zero external
references (`grep -rnw WindowObserver` = 2 hits, both own file). Not used by
`WindowCodeFileView` or any live view.

```
git rm CodeEdit/WindowObserver.swift
```

### Localized+Ex -- 1 file (medium confidence)

`CodeEdit/Localization/Localized+Ex.swift`: `grep -rn "\.localized" CodeEdit/`
outside its own file and the dead About subtree returns 0. Medium confidence
because `.localized` can visually collide with SwiftUI's native
`String(localized:)`; let the deletion agent's `swift build` confirm.

```
git rm CodeEdit/Localization/Localized+Ex.swift
```

## DELETE-NOW in-file symbol edits

- `CodeEdit/CodeEditApp.swift:440-545` -- delete `PlainEditorCommands` (above).
- `CodeEdit/Features/Editor/Views/PlainSyntaxHighlighter.swift:263-269` and the
  `static let rotated` variant near line 294 -- the `SYNTAX_THEME_VARIANT=="rotated"`
  branch is a legacy debug hook. `grep -rn SYNTAX_THEME_VARIANT scripts/ tests/`
  returns 0: nothing sets it, unlike the load-bearing hooks below. Removing the
  branch collapses `PlainSyntaxTheme.current` to `.standard`. Small in-file edit;
  low priority. Verify `PlainSyntaxTheme.rotated` has no other reference before
  removing it.

## Environment-variable hooks (item 4)

Load-bearing, KEEP:

- `SOURCE_FILE` / `CODEEDIT_DEBUG_SOURCE_FILE` (`CodeEditApp.swift:111`): set by
  `scripts/plain_editor_smoke.sh:44` and `tests/e2e/e2e_launch_time.py:109`.
- `CODEEDIT_PLAIN_EDITOR_COMMAND_SELF_TEST` (`CodeFileDocument.swift:101`,
  `PlainSyntaxHighlighter.swift:83`, `CodeFileView.swift:157`): set by the smoke
  script (line 45) and `e2e_launch_time.py:110`. This means
  `PlainEditorCommandSelfTest` (`CodeFileView.swift:153`, scheduled at line 82)
  is live, not dead.

Legacy, remove:

- `SYNTAX_THEME_VARIANT` (`PlainSyntaxHighlighter.swift:264`): set by nothing
  (see in-file edit above).

## KEEP (verified live, do not delete)

- Packages: `CodeEditHighlighting`, `CodeEditLanguages`, `CodeEditTextView`,
  `CodeEditSyntaxDefinitions`.
- `CodeEditTests/PackageSmoke/UndoManagerRegistrationTests.swift` (tests live
  `CEUndoManager`).
- App/editor symbols with intra-file live parents: `PlainEditorAppDelegate` and
  `PlainEditorMainMenu` (used by `@main` `main()`), `PlainEditorCommandSelfTest`,
  `PlainEditorChromeModel`, `PlainEditorCommandBar`, `PlainEditorStatusBar`
  (used by the live `CodeFileView`), `PlainSyntaxTheme` (minus the rotated branch).
- Utils: `DebugRuntimeLog.swift`, `Extensions/String/String+Lines.swift`,
  `SceneID.swift`.

## Outside the live compile surface (route to the purge WP, not this scope)

Three items flagged after dispatch are tracked but sit OUTSIDE the SwiftPM compile
surface: they are not under the `CodeEdit/` target path and not declared package
paths, and `grep -rn "CodeEditUI|AppCast" Package.swift build_debug.sh build_release.sh scripts/`
returns 0. `swift build` never compiles them, so they are dead weight but belong
to the WP-P1-style purge of non-compiled trees, not the live-target audit.

- `CodeEditUI/src/Preferences/ViewOffsetPreferenceKey.swift` -- stray tracked
  Swift file, not in any target. Dead.
- `AppCast/` -- Sparkle appcast Jekyll site (`.gitignore`, `Gemfile`,
  `appcast.xml`, `_plugins/signature_filter.rb`, etc.). Auto-update feed
  infrastructure for a repo with zero releases. Dead until releases exist.
- `Documentation.docc/CodeEditUI/` -- DocC docs for the removed CodeEditUI
  component (surfaced alongside the stray above). Dead.

## Coverage: swept vs sampled

- Fully swept: every top-level type (`struct`/`class`/`enum`/`protocol`/`actor`)
  in all 68 live `CodeEdit/` files, each grep'd for an external reference
  (type-name sweep). Every `CodeEdit/Utils/` file also went through a member-level
  orphan sweep plus distinctive-token verification. The six package dependencies
  were each checked for a live importer.
- Sampled, not exhaustively swept: dead extension methods and free functions on
  live types outside `Utils/` (for example a single unused method added to a
  `String`/`View` extension living in a live editor file). Extension-heavy trees
  that were themselves flagged (About, Keybindings, all of Utils) are covered;
  the residual gap is a stray dead method inside an otherwise-live file, which
  `swift build` warnings and a future targeted pass would surface.
- Confirmed by re-verification after dispatch: `CodeEditKeychain`
  (`grep -rn "CodeEditKeychain\b"` = 2 hits, both own file) and `Loopable`
  (5 hits, all own file including the `/// struct Author: Loopable` doc example)
  are genuinely dead; the "TODO markers" that surfaced them are in-file comments,
  not references. Both remain DELETE-NOW.

## Items to re-verify with the build

The Utils extension deletions rest on distinctive-token greps, which are strong
but cannot see every implicit AppKit/SwiftUI dispatch. Before finalizing, confirm
`String+Lines.swift` (KEEP) does not call any of the deleted string extensions,
and let `swift build` catch any transitive break. Everything named DELETE-NOW is
grep-clean; the build is the final correctness gate the deletion agent owns.
