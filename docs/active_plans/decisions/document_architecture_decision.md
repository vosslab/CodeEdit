# Document architecture decision

## Verdict

Keep the AppKit `NSDocument` subclass `CodeFileDocument` as the document model and
present it through a SwiftUI shell bridge (`NSDocumentController` hosting under a
SwiftUI `App`, not `DocumentGroup`; see the architect bridge-mechanism decision
below). A SwiftUI-native
`ReferenceFileDocument` cannot replace it: the measured prototype fails two of the
four required gates on macOS 26. Encoding round-trips port cleanly to
`ReferenceFileDocument`, but the two behaviors that depend on the AppKit document
lifecycle -- a 2-second autosave debounce and an external-change reload that writes
into the same `NSTextStorage` the views already hold -- have no equivalent in the
`ReferenceFileDocument` model.

This mirrors the text-engine spike outcome in
[text_engine_decision.md](text_engine_decision.md): SwiftUI owns the app shell,
AppKit survives only as a narrow, documented-swap-path adapter. Here the retained
AppKit surface is the document model, not the editor surface.

## Gate results

All numbers come from `swift run DocArchSpike` in the throwaway SwiftPM package at
`/private/tmp/claude-501/wp-s0-prototype/` (outside the repo tree). Results are
stable across five runs.

| Gate | Result | Measured evidence |
| --- | --- | --- |
| 1. Autosave debounce parity (2 s +/- 500 ms) | FAIL | A genuinely dirty document (`isDocumentEdited=true`, `hasUnautosavedChanges=true`, `autosavesInPlace=true`, wrapper class `FileWrapperPlatformDocument`) produced no on-disk autosave within 8 s. The documented undo-registration path did not even mark the document edited (`isDocumentEdited=false` after the edit). `ReferenceFileDocument` exposes no `scheduleAutosaving()` override to install a 2 s debounce. |
| 2. Save As preserves encoding byte-for-byte (UTF-8, Windows-1252, Latin-1) | PASS | `saveas_byte_identical=true` for all three encodings. |
| 3. External reload into the same `NSTextStorage` (`===` identity) | FAIL | An external rewrite produced no in-place reload within 8 s (`doc_inits 1 -> 1`, no new read). A looser-timed run instead produced a fresh `CodeRefDocument` via `init(configuration:)` with a new `NSTextStorage` (`doc_inits 0 -> 1`, `same_storage_identity=false`). Neither path writes into the storage the view held. |
| 4. Open-edit-save round-trip byte-identical (UTF-8, UTF-16 BE, UTF-16 LE, Windows-1252, Latin-1) | PASS | `noedit_bytes_identical=true` and `edit_roundtrips=true` for all five encodings. |

Verbatim gate lines from one representative run:

```text
GATE2 save-as encoding overall: PASS
GATE4 encoding round-trip overall: PASS
GATE3 diag: file_read_via_init(configuration:)=true, doc_inits_after_open=1, editor_mounts_after_open=2
GATE3 external reload: FAIL (reload_observed=false, doc_inits 1->1, same_storage_identity=true, same_editor_identity=true)
GATE3 external reload (looser-timed run1): FAIL (reload_observed=true, doc_inits 0->1, same_storage_identity=false)
GATE1 diag: after undo-registered edit -> isDocumentEdited=false, hasUnautosavedChanges=false, autosavesInPlace=true, class=FileWrapperPlatformDocument
GATE1 diag: after forced changeDone -> isDocumentEdited=true, hasUnautosavedChanges=true, autosavesInPlace=true, class=FileWrapperPlatformDocument
GATE1 autosave debounce: FAIL (no autosave observed on disk within 8.0 s; ReferenceFileDocument exposes no scheduleAutosaving override to set a 2 s debounce)
```

## Mechanical verdict

The decision rule is mechanical: all four gates pass selects
`ReferenceFileDocument`; any single failure selects the NSDocument-behind-DocumentGroup
bridge. Gates 1 and 3 fail, so the verdict is the bridge. No interpretation is
applied; the two passing encoding gates do not offset the two lifecycle failures.

## What was measured and how

A throwaway SwiftUI `DocumentGroup` app defines `CodeRefDocument`, a
`ReferenceFileDocument` that holds a shared `NSTextStorage` and preserves the source
encoding using the exact decode/encode logic ported from `CodeFileDocument` and
`FileEncoding` (five encodings, BOM-less UTF-16 pre-check, Windows-1252 fallback). An
`NSViewRepresentable` editor mounts the document's `NSTextStorage` and records the
object identity it holds.

- Gates 2 and 4 exercise the ported codec directly: encode a fixture per encoding,
  decode it, re-encode, and compare bytes; and edit, save, reopen, and confirm the
  edit round-trips losslessly. This is the same codec a real `ReferenceFileDocument`
  calls from `init(configuration:)` and `fileWrapper(snapshot:configuration:)`, so it
  measures the document type's encoding capability.
- Gate 3 opens a fixture through `NSDocumentController.shared.openDocument`, records
  the `NSTextStorage` identity the document and editor hold, rewrites the file on
  disk with a fresh modification date, waits up to 8 s, and checks whether any reload
  landed in the same storage instance.
- Gate 1 opens a fixture, requests a dirty-making edit through the SwiftUI
  environment `UndoManager`, confirms the wrapped `NSDocument`'s dirty state, force-
  dirties it via `updateChangeCount(.changeDone)` as a fallback so the timing
  question is isolated from the change-plumbing question, then polls the file on disk
  for the autosaved write and compares the delay against the 2 s window.

The prototype prints greppable `GATE*` lines and self-terminates with `exit(0)`.

## The bridge

The bridge keeps these `NSDocument` responsibilities in `CodeFileDocument`
([CodeFileDocument.swift](../../../CodeEdit/Features/Documents/CodeFileDocument/CodeFileDocument.swift)):

- Ownership of the shared `NSTextStorage` with stable object identity across an
  external reload (gate 3), so the editor `TextView` and `PlainSyntaxHighlighter`
  keep pointing at one buffer.
- The 2-second autosave debounce via the `scheduleAutosaving()` override (gate 1).
- Encoding decode and encode for all five encodings via `read(from:ofType:)` and
  `data(ofType:)` (gates 2 and 4). These pass under `ReferenceFileDocument` too, but
  stay with the document model so all four responsibilities share one owner.
- External-change reload written into the same storage via `presentedItemDidChange`,
  plus the document-lifecycle correctness work tracked as WP-L1 through WP-L4.
- Undo integration with the editor `TextView`.

These responsibilities move to SwiftUI:

- The app entry point (`App`, replacing `@main enum CodeEditMain`).
- The document scene, hosted through `NSDocumentController` under a SwiftUI `App`
  (see the architect bridge-mechanism decision below), not `DocumentGroup`.
- The `Commands` menu, replacing the hand-built `NSMenu` (`PlainEditorMainMenu`).
- Window and scene lifecycle and chrome.

`DocumentGroup` accepts only `FileDocument` or `ReferenceFileDocument`, so the bridge
needs one reconciling file: the single place that presents the retained
`CodeFileDocument` inside the SwiftUI scene graph (hosting document windows through
`NSDocumentController` under the SwiftUI `App`, or a thin `ReferenceFileDocument`
facade that delegates lifecycle to the retained `CodeFileDocument`). The single
sanctioned document-layer AppKit allowlist file is:

- `CodeEdit/Features/Documents/CodeFileDocument/CodeFileDocumentBridge.swift` (new,
  created by WP-S1).

This is the only new AppKit boundary at the document layer, alongside the editor
adapter `PlainTextEditorView.swift` sanctioned by
[text_engine_decision.md](text_engine_decision.md). No other file added by the shell
migration may import AppKit at the document layer.

### Bridge mechanism (architect decision 2026-07-09)

Chosen fork: host document windows through `NSDocumentController` under a plain
SwiftUI `App` scene. Do not use `DocumentGroup` for the document scene. This
resolves the open fork in the paragraph above and refines the mechanical verdict's
"NSDocument-behind-DocumentGroup" label: "DocumentGroup" there denotes the SwiftUI
document-app path generically, and the concrete scene is a plain `App`, not the
`DocumentGroup` scene type.

Why: the fork must let `CodeFileDocument` keep sole ownership of the 2 s autosave
debounce (gate 1), the `NSFilePresenter` external-reload path, and the shared
`NSTextStorage` identity (gate 3). A `ReferenceFileDocument` facade under
`DocumentGroup` cannot deliver this. `DocumentGroup` always manages its own private
`NSDocument` around the facade, so keeping `CodeFileDocument` alive underneath means
two `NSDocument` instances and two `NSFilePresenter` registrations per file URL, a
double-owner conflict with duplicate change notifications. Gate 3 measured the
failure directly: `DocumentGroup`'s reload recreates the document with a new
`NSTextStorage`, breaking `===`; gate 1 showed its autosave cannot be debounced,
because those behaviors live on `DocumentGroup`'s private `NSDocument`, which exposes
no `scheduleAutosaving` or `presentedItemDidChange` override. Suppressing both so the
facade could delegate would also suppress `DocumentGroup`'s dirty-state, close-save,
and Save chrome, so the facade earns nothing. A single `NSDocumentController` keeps
exactly one document owner and one file presenter per URL, the only shape that
satisfies gates 1 and 3.

Undo-manager ownership: bypass. Do not set `\.environment(\.undoManager)` on the
hosted SwiftUI tree. `CodeFileDocument.undoManager` (the `NSDocument` undo manager),
wired to the editor `TextView`, is the single undo owner, consistent with WP-L1 and
WP-L4; a SwiftUI environment undo manager would create a second competing stack.

Guidance for WP-S1: `@main` is the SwiftUI `App`; give it a `Settings` scene plus the
`Commands` menu, and route File > New and File > Open to `NSDocumentController.shared`
(`newDocument(_:)` / `openDocument(_:)`). `CodeFileDocument.makeWindowControllers()`
builds an `NSWindowController` whose `contentViewController` is an
`NSHostingController` hosting `CodeFileView(document:)`. Keep every new AppKit
reference for this window hosting -- the `NSDocumentController` glue, the
`NSWindowController`, and the `NSHostingController` construction -- inside
`CodeEdit/Features/Documents/CodeFileDocument/CodeFileDocumentBridge.swift`, the
single sanctioned document-layer bridge file; `CodeFileDocument.swift` stays the
document model and delegates window construction into the bridge.

## Swap path if later reversed

The re-evaluation trigger is the next macOS SDK. Re-run this prototype against the
new SDK. If all four gates pass -- specifically if `ReferenceFileDocument` gains an
in-place external-reload hook that preserves the `NSTextStorage` object identity and
a configurable autosave debounce -- then conform the document model to
`ReferenceFileDocument`, delete `CodeFileDocumentBridge.swift` and the AppKit
document backbone, and keep only the editor adapter. Keep the bridge boundary small
enough that this swap does not touch the SwiftUI shell.

## Measurement environment

- macOS 26.5.2 (build 25F84).
- Swift 6.3.3 (`swiftlang-6.3.3.1.3 clang-2100.1.1.101`), target `arm64-apple-macosx26.0`.
- `hw.model` MacBookPro18,3.

## Document state contract

Canonical definitions for document lifecycle state, written against the live code paths audited
in [docs/active_plans/audits/document_lifecycle_audit.md](../audits/document_lifecycle_audit.md)
(`CodeFileDocument.swift`, `CodeFileView.swift`). This section is the target contract: some rows
are already true of today's code, others are pinned as expected-fail regression tests in
`CodeEditTests/PackageSmoke/CodeFileDocumentLifecycleGapTests.swift` (Findings 1-4) until the
named work packages land.

### Saved text identity

"Saved text" is the exact string content of `content: NSTextStorage?` at the moment the most
recent successful `write(to:ofType:)` or initial `read(from:ofType:)` completed, decoded/encoded
using the document's `sourceEncoding`. Two buffers are the same saved text when their `.string`
values are byte-for-byte equal after that round trip; encoding metadata is not part of the
identity, only the decoded characters are.

### File modification date advancement

`fileModificationDate` (inherited from `NSDocument`, distinct from the on-disk mtime read via
`getModificationDate()`) advances only when the in-memory document has actually observed and
accepted the corresponding on-disk state:

- On initial open, it is set to the file's mtime at open time.
- On save, it is set to the newly written file's mtime.
- On a successful silent reload (clean document, valid external change), it is set to the new
  mtime, because the buffer now matches what is on disk.
- It must **not** advance when the reload did not actually succeed (undecodable external change);
  advancing it there would falsely claim the in-memory document is caught up with disk. WP-L3
  closes the case where today's code advances this date incorrectly.
- On a dirty-document conflict (dirty + decodable external change), it advances to the observed
  on-disk mtime as an acknowledgement that this external version was seen, so the same change is
  not re-prompted; this is bookkeeping, not a reload, and the buffer is not overwritten until the
  user resolves the conflict. WP-L2 implements this acknowledgement (the F2 regression test pins
  `fileModificationDate` advancing to the on-disk mtime as the reachable proxy for "the conflict
  was surfaced"); the old code left the date stale because it dropped the conflict entirely.

### Dirty flag (`isDocumentEdited`) semantics

The dirty flag reflects "does the in-memory buffer differ from the last saved text," not merely
"has any change notification fired." Concretely:

- It sets to `true` on any forward edit that changes the buffer's decoded string away from the
  saved text.
- It clears to `false` (via `.changeCleared`) on a successful save.
- Undo back to the saved text must clear it to `false`; redo away from the saved text (after that
  undo) must set it back to `true`. `NSDocument.updateChangeCount` supports this distinction via
  `.changeDone` / `.changeUndone` / `.changeRedone` / `.changeCleared`; today's code calls
  `.changeDone` unconditionally for every text-storage mutation (`CodeFileView.swift:68`), so undo
  and redo never clear or restore the flag correctly. WP-L1 closes this gap.
- An external reload that leaves the buffer matching the new on-disk text should also result in
  `isDocumentEdited == false`, since the buffer once again matches what NSDocument understands as
  saved.

### Undo history across save and reload

- Across a **save**, undo history is preserved unchanged: the operations already registered with
  `TextView.undoManager` remain valid, because save does not mutate the buffer's offsets.
- Across a **reload** (external-change path, `CodeFileDocument.swift:159-168`), any undo
  operations registered before the reload reference offsets and substrings of the pre-reload text
  and are no longer valid against the reloaded buffer. The undo stack must be reset (cleared) as
  part of the reload so a subsequent undo is a no-op rather than replaying a stale operation
  against mismatched content. Today's reload mutates the shared `NSTextStorage` directly and never
  touches `textView.undoManager`, so stale operations survive and can corrupt the reloaded buffer.
  WP-L4 closes this gap.

### External-change matrix

| Document state | External change | Outcome |
| --- | --- | --- |
| Clean | Valid (decodable) | Silent reload; buffer replaced with new decoded text; encoding label refreshed; `fileModificationDate` advances to the new mtime. |
| Dirty | Valid (decodable) | Prompt the user (keep my edits, or reload from disk); no silent overwrite in either direction until the user decides. `fileModificationDate` advances to the observed on-disk mtime to acknowledge the conflict was seen (so it is not re-prompted); the buffer is untouched until the user chooses. Today's code (`presentedItemDidChange`, `CodeFileDocument.swift:325-341`) instead falls through silently with no prompt and no state change -- WP-L2 closes this gap. |
| Clean | Undecodable | Error alert; buffer stays untouched; `fileModificationDate` does not advance (the reload did not succeed, so the document must not claim to be caught up with disk). Today's `try?` at `CodeFileDocument.swift:335` swallows the decode error and the date advance at `CodeFileDocument.swift:332` still runs -- WP-L3 closes this gap. |
| Dirty | Undecodable | Error alert; edits are kept as-is; `fileModificationDate` does not advance. Same underlying gap as the clean+undecodable row; also closed by WP-L3. |
| File deleted or moved | n/a | Alert the user; clear the backing file association (`fileURL`) so a subsequent Save routes through Save As instead of silently failing or resurrecting the old path; edits are kept in the buffer. Not yet covered by an automated test; see residual gap note below. |

### Residual gap: file deletion/move is not package-testable today

The "file deleted or moved" row above cannot currently be exercised as a package-level
`CodeFileDocument` test: detecting deletion relies on `NSFilePresenter`/`NSFileCoordinator`
delivering a distinct notification path (not `presentedItemDidChange`'s mtime-diff check, which
requires the file to still exist to stat), and clearing `fileURL` plus rerouting Save through Save
As is driven by `NSDocumentController` machinery that is not live outside a running app with a
real window. This row is documented here as the target contract; closing it needs either a
higher-level (E2E, per `docs/E2E_TESTS.md`) test or a seam introduced by whichever work package
implements it, not a `CodeFileDocumentLifecycleGapTests` addition.
