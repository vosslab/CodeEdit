# TODO

Backlog scratchpad for small tasks without timelines. Large or milestone-scale
work belongs in [ROADMAP.md](ROADMAP.md) or a dedicated plan under
`docs/active_plans/`, not here.

## Code polish

- Consolidate the scattered `debugRuntimeLog` call sites in
  `PlainSyntaxHighlighter.swift` and `PlainTextEditorView.swift` into a
  single logging seam; all sites are already `#if DEBUG` guarded so this is
  polish, not a correctness fix (noted in
  `docs/active_plans/audits/ms_entry_criteria_scout.md`).

## Verification follow-ups

- Confirm the status bar's encoding label refreshes when
  `CodeFileDocument.read(from:ofType:)` re-detects a different encoding on an
  external reload; the refresh currently relies on the SwiftUI
  `@Published`/`@ObservedObject` update cycle rather than an explicit call
  from the reload path (LOW Finding 7 in
  `docs/active_plans/audits/document_lifecycle_audit.md`).
- Extend `scripts/plain_editor_smoke.sh` with a literal save-to-disk and
  reopen-from-disk round-trip step; the current run exercises the in-memory
  lifecycle via the command self-test (insert/undo/redo/copy/cut/paste/
  cleanText) but never writes the edited buffer to disk and reloads it, so
  save-path regressions are invisible to smoke (found by the WP-P5 reviewer,
  2026-07-09).
