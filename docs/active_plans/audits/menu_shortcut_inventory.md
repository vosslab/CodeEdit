# Menu shortcut inventory

Ground-truth inventory of PlainEditorMainMenu items and shortcuts, captured
2026-07-09 before the WP-S2 SwiftUI Commands migration. Feeds the WP-S2
shortcut-parity gate.

## Summary counts

19 table rows: 16 actionable menu items + 3 separators. 14 of 16 actionable
items carry a shortcut; 2 do not (Open Example Source, Clean Text). 2 dead
shortcuts today (Find..., Find and Replace...).

## Inventory table

| Menu | Item title | Shortcut | Action/selector | Target | Notes |
| --- | --- | --- | --- | --- | --- |
| SwiftlyCodeEdit (app menu) | Quit SwiftlyCodeEdit | Cmd+Q | #selector(NSApplication.terminate(_:)) | nil (first responder / NSApp) | System-standard; representable via CommandGroup(replacing: .appTermination). |
| File | New | Cmd+N | newDocumentMenuItem(_:) -> NSDocumentController.shared.newDocument(sender) | appDelegate | Standard .newItem shape. |
| File | Open... | Cmd+O | openDocumentMenuItem(_:) -> NSOpenPanel then openDocument(at:) | appDelegate | Standard shape. |
| File | Open Example Source | none | openExampleSourceMenuItem(_:) -> opens hardcoded CodeEdit/Features/Documents/CodeFileDocument/CodeFileDocument.swift relative to CWD | appDelegate | No shortcut; dev-convenience item; path resolves only when launched from repo root. |
| File | (separator) | n/a | n/a | n/a | NSMenuItem.separator(), empty title. |
| File | Save | Cmd+S | saveMenuItem(_:) -> NSApp.sendAction(#selector(NSDocument.save(_:)), to: nil, from: nil) | appDelegate | Standard shape. |
| File | Save As... | Cmd+Shift+S | saveAsMenuItem(_:) -> NSApp.sendAction(#selector(NSDocument.saveAs(_:)), to: nil, from: nil) | appDelegate | keyEquivalentModifierMask=[.command,.shift] set explicitly after construction; representable with KeyboardShortcut("s", modifiers: [.command, .shift]). |
| File | Close | Cmd+W | closeMenuItem(_:) -> NSApp.sendAction(#selector(NSWindow.performClose(_:)), to: NSApp.keyWindow, from: sender) | appDelegate | Sends explicitly to NSApp.keyWindow rather than nil/first-responder; SwiftUI's default per-window Close (Cmd+W) may already cover this -- confirm semantics match rather than assuming. |
| Edit | Undo | Cmd+Z | undoMenuItem(_:) -> PlainEditorActionRouter.shared.undo() | appDelegate | Router needs a registered activeTextView (see CodeFileView.swift:78); silent no-op otherwise. |
| Edit | Redo | Cmd+Shift+Z | redoMenuItem(_:) -> actionRouter.redo() | appDelegate | keyEquivalentModifierMask=[.command,.shift] set explicitly. |
| Edit | (separator) | n/a | n/a | n/a | Empty title. |
| Edit | Cut | Cmd+X | cutMenuItem(_:) -> actionRouter.cut() | appDelegate | Standard shape. |
| Edit | Copy | Cmd+C | copyMenuItem(_:) -> actionRouter.copy() | appDelegate | Standard shape. |
| Edit | Paste | Cmd+V | pasteMenuItem(_:) -> actionRouter.paste() | appDelegate | Reads NSPasteboard.general directly (2026-07-09 fix); standard shape. |
| Edit | Select All | Cmd+A | selectAllMenuItem(_:) -> actionRouter.selectAll() | appDelegate | Standard shape. |
| Edit | (separator) | n/a | n/a | n/a | Empty title. |
| Edit | Clean Text | none | cleanTextMenuItem(_:) -> actionRouter.cleanText() | appDelegate | No shortcut; trims trailing horizontal whitespace via PlainEditorTextCleaner. |
| Find | Find... | Cmd+F | #selector(NSTextView.performFindPanelAction(_:)) | nil (first responder) | DEAD TODAY: live text view class TextView (Packages/CodeEditTextView/Sources/CodeEditTextView/TextView/TextView.swift:37) subclasses NSView, not NSTextView; performFindPanelAction is never implemented anywhere in Packages/. No find panel exists in the app. |
| Find | Find and Replace... | Cmd+Option+F | #selector(NSTextView.performFindPanelAction(_:)), tag=12 | nil (first responder) | DEAD TODAY, same reason. tag=12 is set but never read anywhere. Cmd+Option+F is representable in SwiftUI's KeyboardShortcut (arbitrary EventModifiers sets are supported) -- the blocker is behavioral, not a Commands API limitation. |

## Orphaned extension

CodeEdit/CodeEditApp.swift:440-450 has `extension TextView { @objc func
cleanText(_ sender: Any?) }` that is never wired to any menu item, key
equivalent, or #selector reference anywhere in the repo. The live "Clean
Text" item routes through
PlainEditorAppDelegate.cleanTextMenuItem(_:) -> PlainEditorActionRouter.cleanText(),
not this orphaned extension method.

## Smoke script marker

scripts/plain_editor_smoke.sh:101 -> wait_for_line "Main menu items:"
wait_for_line (scripts/plain_editor_smoke.sh:70-83) does `grep -F "$needle"
"$RUNTIME_LOG"` -- a fixed-string SUBSTRING match. It only asserts a line
containing the literal prefix "Main menu items:" exists; it asserts nothing
about submenu content, item count, or ordering.

That line is emitted by PlainEditorAppDelegate.logMenuState()
(CodeEdit/CodeEditApp.swift:262-276, DEBUG-only) from NSApp.mainMenu, joining
top-level titles with " | " and each submenu's item titles with ", "
(separators print as empty-string titles, so they show as a blank entry
between commas). Given the current menu, the full line reads:

Main menu items: SwiftlyCodeEdit: [Quit SwiftlyCodeEdit] | File: [New, Open...,
Open Example Source, , Save, Save As..., Close] | Edit: [Undo, Redo, , Cut,
Copy, Paste, Select All, , Clean Text] | Find: [Find..., Find and Replace...]

Because the gate only checks the prefix, WP-S2 can change submenu
content/order/titles freely and this smoke gate will still pass -- it does
not substitute for the parity table above.
