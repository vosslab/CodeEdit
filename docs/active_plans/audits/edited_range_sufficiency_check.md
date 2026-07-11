# Edited-range notification sufficiency check (M8 entry criterion)

WP-L1 delivered `CodeFileDocument.EditedTextChange`, a two-case broadcast
(`.range(replacedRange:newLength:)` or `.fullInvalidation`) so an M8 consumer
(bounded rehighlighter, incremental status bar) can bound its work to the
edited region instead of rescanning the whole document on every keystroke.
Before the M8 performance packages dispatch, this check traces all six
required cases -- typing, paste, undo, redo, reload, and Clean Text -- through
the code to confirm each one broadcasts a usable payload.

## Verdict table

| Case | Payload shape | Evidence (file:line) |
| --- | --- | --- |
| Typing | `.range` (bounded to the inserted/replaced span) | `TextView+NSTextInput.swift:55,57,105,143` call `replaceCharacters`, which fires `didReplaceContentsIn` in `TextView+ReplaceCharacters.swift:46`; `CodeFileView.swift:88-103` classifies `.edit` and calls `recordEdit`, which broadcasts `.range` at `CodeFileDocument.swift:151` |
| Paste | `.range` (bounded to the pasted span) | `CodeEditApp.swift:336` (`paste()`) and `CodeFileView.swift:281` (Cmd path) both call `activeTextView.replaceCharacters`, same `didReplaceContentsIn` -> `recordEdit` -> `.range` path as typing |
| Undo | `.range` (bounded to the replayed span) | `CEUndoManager.swift:83,115` replay a mutation via `textView.replaceCharacters`; `CodeFileView.swift:96-97` detects `undoManager?.isUndoing == true` and calls `recordEdit(.undo, ...)`, which still broadcasts `.range` (`CodeFileDocument.swift:151`) |
| Redo | `.range` (bounded to the replayed span) | Same replay path as undo; `CodeFileView.swift:98-99` detects `isRedoing == true` and calls `recordEdit(.redo, ...)` |
| Reload (external change) | `.fullInvalidation` | `CodeFileDocument.swift:195-227` (`read(from:ofType:)`) mutates `content.mutableString` directly (bypassing `TextView.replaceCharacters`) and explicitly calls `broadcast(.fullInvalidation)` at line 218; pinned by `CodeFileDocumentLifecycleTests.externalReloadBroadcastsFullInvalidation()` |
| Clean Text | `.range` (bounded to the whole pre-edit buffer, not `.fullInvalidation`) | `EditorCommandRouter.swift:326-336` (`applyCleanTransform`) and `CodeEditApp.swift:346-356` (menu-bar `cleanText()`) both call `textView.replaceCharacters(in: NSRange(location: 0, length: originalLength), with: cleaned)` -- the same mutation API as typing/paste/undo/redo, so it fires `didReplaceContentsIn` and flows through the normal `recordEdit` -> `.range` path, never bypassing the notification |

## Clean Text finding: covered, but by the range case, not full-invalidation

The open question going in was whether Clean Text mutates through
`TextView.replaceCharacters` (firing `didReplaceContentsIn` and broadcasting a
usable `.range`) or bypasses it by mutating `NSTextStorage` directly, the same
way reload does. Tracing `applyCleanTransform` and the menu-bar `cleanText()`
confirms every Clean Text action (trim trailing whitespace, line-ending
normalization, final newline, tabs/spaces conversion, smart-punctuation
normalization) replaces the whole buffer with one call to
`textView.replaceCharacters(in:with:)`. That is the identical public API
typing, paste, undo, and redo all call, and `TextView+ReplaceCharacters.swift:46`
fires `delegate?.textView(self, didReplaceContentsIn:with:)` unconditionally
for every valid replaced range inside it. `PlainTextEditorView.Coordinator`
forwards that into `codeFile.recordEdit(.edit, replacedRange:newLength:)`
(`CodeFileView.swift:88-103`), which broadcasts `.range(replacedRange:
newLength:)` (`CodeFileDocument.swift:151`) -- not `.fullInvalidation`.

**Verdict: Clean Text is covered.** An M8 consumer receives a bounded `.range`
whose `replacedRange` spans the whole pre-edit buffer (location 0, length
equal to the original text) and whose `newLength` matches the cleaned text.
That range happens to cover the entire document (Clean Text always rewrites
the whole buffer in one edit), so a range-bounded rehighlighter or status bar
still does a full-document pass for this case in practice -- but it receives
that instruction through the same explicit, typed payload as every other
edit, not through silence or an inferred heuristic.

**Documentation gap flagged (not a code bug):** the doc comment on
`CodeFileDocument.EditedTextChange.fullInvalidation`
(`CodeFileDocument.swift:105-107`) reads "The whole buffer changed (external
reload, Clean Text)," which is inaccurate -- Clean Text broadcasts `.range`,
not `.fullInvalidation`. Only the external-reload path (`read(from:ofType:)`)
broadcasts `.fullInvalidation`. This is a comment-accuracy issue for whichever
lane next touches that enum, not a functional gap; the M8 entry criterion
(a usable payload for all six cases) is satisfied either way, since a `.range`
covering the whole buffer is at least as usable to a consumer as
`.fullInvalidation`.

## Test coverage added by this check

`CodeEditTests/PackageSmoke/EditedRangeContractTests.swift` pins the Clean
Text case: it drives `EditorCommandRouter.cleanText()` against a `TextView`
wired with a delegate that forwards `didReplaceContentsIn` into
`recordEdit` (mirroring `PlainTextEditorView.Coordinator`'s production
wiring), and asserts the exact broadcast is
`.range(replacedRange: NSRange(location: 0, length: <original length>),
newLength: <cleaned length>)`. The other five cases already have coverage:
`CodeFileDocumentLifecycleTests.recordEditBroadcastsBoundedRangeChange()` and
`.externalReloadBroadcastsFullInvalidation()` pin the `.range` and
`.fullInvalidation` shapes directly; typing/paste/undo/redo all reduce to the
same `recordEdit(.edit/.undo/.redo, ...)` call already exercised there and in
`EditorCommandRouterRoutingTests.swift` and `PlainEditorClipboardTests.swift`.

## Conclusion

All six required cases broadcast a usable `EditedTextChange` payload. The
M8 entry criterion is satisfied: no case is silent, and no case forces a
consumer to guess. Clean Text uses the `.range` case (covering the whole
buffer) rather than `.fullInvalidation`; the M8 performance packages can
dispatch treating Clean Text as a (large) bounded range edit like any other,
with the doc-comment wording fix as optional follow-up cleanup.
