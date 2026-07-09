# Usage

SwiftlyCodeEdit is a native macOS plain-text and code editor built with
SwiftUI. This doc covers using the built app day to day; for build,
packaging, and benchmark scripts, see
[docs/DEVELOPER_USAGE.md](DEVELOPER_USAGE.md).

## Quick start

1. Build and launch the app (see [docs/INSTALL.md](INSTALL.md) for setup):
   ```bash
   ./build_debug.sh
   ```
2. Choose **File > Open...** (`Cmd+O`) and pick a file, or **File > New**
   (`Cmd+N`) to start an empty document.
3. Edit the text, then save with **File > Save** (`Cmd+S`) or
   **File > Save As...** (`Cmd+Shift+S`).

## Menu commands

The app replaces the standard File and Edit menus with these commands:

- **New** (`Cmd+N`) / **Open...** (`Cmd+O`) / **Open Example Source**: open a
  bundled example file directly, useful for a first look at syntax
  highlighting.
- **Save** (`Cmd+S`) / **Save As...** (`Cmd+Shift+S`) / **Close** (`Cmd+W`).
- **Undo** (`Cmd+Z`) / **Redo** (`Cmd+Shift+Z`).
- **Cut** (`Cmd+X`) / **Copy** (`Cmd+C`) / **Paste** (`Cmd+V`) /
  **Select All** (`Cmd+A`).
- **Find...** (`Cmd+F`) / **Find and Replace...** (`Cmd+Option+F`).
- **Clean Text**: runs the built-in text cleaner (normalizes line endings and
  trims trailing whitespace) on the active document.

## Command bar and fonts

The command bar above the editor shows Save/Undo/Redo/Clean Text state and
font controls:

- `A-` / `A+` buttons shrink or grow the editor font size within its allowed
  range.
- A reset control restores the default font family and size.
- Font family and size are persisted across launches via `UserDefaults` keys
  `PlainEditor.fontFamily` and `PlainEditor.fontSize`.

## Status bar

The bottom status bar reports, for the active document:

- Cursor position and current selection.
- Word count.
- Indentation style (tabs vs. spaces).
- Line ending style (LF, CRLF, or lone CR).
- Detected file encoding (for example UTF-8, Windows-1252, Latin-1, or
  "Unknown" when no decoding was actually applied).
- Detected language, used to select the syntax-highlighting definition.

## Syntax highlighting

Opening a recognized source file applies Kate-XML-derived syntax
highlighting automatically; the first highlight pass runs off the main
thread so the window appears immediately rather than blocking on a
synchronous highlight pass. See
[docs/CODE_ARCHITECTURE.md](CODE_ARCHITECTURE.md) for the parse, interpret,
and span-map pipeline stages.

## Inputs and outputs

- **Inputs**: any text file opened via **Open...** or **New**; encoding is
  auto-detected with a Windows-1252/Latin-1 fallback for non-UTF-8 files,
  with an error alert if a file cannot be decoded at all.
- **Outputs**: the edited file, written back to disk on **Save**/**Save
  As...**; no other artifacts are produced by normal editing.

## Known gaps

- [ ] Document the exact font family choices and size range once
  `PlainEditorFontSettings` is reviewed for its full set of allowed values.
- [ ] Confirm whether unsaved-changes prompts appear on Close/Quit, and
  document that flow if so.
