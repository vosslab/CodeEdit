# Troubleshooting

Known issues and fixes for SwiftlyCodeEdit development and smoke testing. See
[SMOKE_TEST.md](SMOKE_TEST.md) for the full smoke test contract.

## Smoke screenshot shows SKIPPED instead of an image

- Symptom: `./scripts/plain_editor_smoke.sh` prints
  `SKIPPED: screenshot capture, helper ran but produced no file (likely denied
  screen-recording permission)`, or `SKIPPED: screenshot capture, missing
  helper <path>`.
- Cause: Screenshot capture depends on `~/nsh/easy-screenshot/run.sh` and the
  macOS screen-recording TCC grant, neither of which is a repo correctness
  concern; it never fails the run.
- Fix: Grant screen-recording permission to the terminal or tool running the
  smoke script (System Settings > Privacy & Security > Screen Recording), then
  rerun. Pass `--no-screenshot` to skip the diagnostic entirely when a
  screenshot is not needed; the run still passes on hard gates alone.

## Can't tell if a smoke run passed or failed

- Symptom: The console log is long and it is unclear whether the run
  ultimately passed.
- Cause: Pass/fail is not obvious from mid-log lines alone.
- Fix: The smoke script always writes `SMOKE_EXIT=<code>` to stderr on both
  success and failure, on every exit path. Check for `SMOKE_EXIT=0` (success)
  versus a nonzero code (failure); no wrapper or redirection is needed.

## Smoke highlight wait times out intermittently

- Symptom: The `Plain editor Swift syntax highlight:` wait step times out
  (for example `elapsedMs=6158`) and the run reports `SMOKE_EXIT=1`, even
  though the code under test did not change.
- Cause: Cold syntax-highlight compute competes for CPU with other concurrent
  builds or app launches on the same machine; this is a known cold-compute
  contention knife-edge (see
  `docs/active_plans/active/scope_closure_plan.md`).
- Fix: Rerun the smoke script on an otherwise idle machine, with no other
  builds or launches in progress. A clean rerun reporting `SMOKE_EXIT=0`
  confirms the earlier failure was contention, not a regression.

## Autosave overwrote a real source file during manual testing

- Symptom: A file open in the editor during manual paste testing gets
  overwritten with pasted test content, including loss of the trailing
  newline.
- Cause: The editor's 2-second autosave writes real files to disk. If a live
  tracked source file is open in the editor while pasting test content, the
  autosave writes that test content over the real file.
- Fix: Never paste or type test content into a live tracked source file. Copy
  the file to a scratch location first, or open a throwaway file, before
  manual paste/typing tests.

## File shows "Unknown" encoding or fails to open

- Symptom: The status bar reports "Unknown" encoding, or the file fails to
  open with an explicit error alert.
- Cause: The file's bytes do not match any supported decoding (UTF-8, UTF-16
  BE, UTF-16 LE, Windows-1252, or ISO Latin-1). This includes BOM-less
  UTF-16 files, which are now detected by a plausibility pre-check rather
  than being misread as UTF-8.
- Fix: Confirm the file is actually one of the supported encodings; there is
  no automatic recovery for other encodings. The editor now always shows
  either real decoded text or an explicit error alert, never a silent blank
  window, so an error alert reflects the true encoding rather than a bug.

## Large files are slow to show syntax highlighting on first open

- Symptom: Opening a large Swift file (roughly 1 MB or more) takes several
  seconds before syntax highlighting appears.
- Cause: Highlighting still computes spans for the full document before
  showing color; viewport-first (visible-lines-only) highlighting has not
  landed yet.
- Fix: Expect a multi-second wait on very large files until viewport-first
  highlighting ships as future work; no current user action resolves it.

## App launched with `open` leaves a stray running instance

- Symptom: A LaunchServices `open` of the built `.app` bundle (for example to
  capture Dock icon evidence) leaves a running instance that a script cannot
  terminate.
- Cause: There is no agent-side kill path for `open`-launched instances, since
  `pkill`/`kill` are denied in every agent context and `open` does not accept
  the app's `--kill-after=N` flag.
- Fix: For any launch that needs an automatic quit, launch the binary
  directly with `--kill-after=N` (as `build_debug.sh` and the smoke script
  do) instead of `open`. If `open` was used for Dock-icon evidence, quit the
  app manually afterward from the Dock or with Cmd+Q.
