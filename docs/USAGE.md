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
- **Clean Text** (submenu): each item rewrites the whole active document as a
  single undoable edit, and none of them run automatically.
  - **Trim Trailing Whitespace**: removes trailing spaces and tabs from
    every line.
  - **Normalize Line Endings to LF** / **Normalize Line Endings to CRLF**:
    rewrites every line ending in the document to the chosen style. The
    editor never rewrites line endings on its own; only these two actions
    do.
  - **Ensure Final Newline**: appends a trailing newline if the document
    does not already end with one.
  - **Convert Tabs to Spaces** / **Convert Spaces to Tabs**: expands or
    collapses each line's leading indentation at a 4-column tab width (a
    hardcoded default; a future Settings scene will make this configurable).
  - **Convert Smart Punctuation to ASCII**: an explicit opt-in action that
    maps curly quotes, en/em dashes, and ellipsis characters to their ASCII
    equivalents. Nothing else in the app applies this silently.

## Command bar and fonts

The command bar above the editor shows Save/Undo/Redo/Clean Text state and
font controls:

- `A-` / `A+` buttons shrink or grow the editor font size within its allowed
  range.
- A reset control restores the default font family and size.
- Font family and size are persisted across launches via `UserDefaults` keys
  `PlainEditor.fontFamily` and `PlainEditor.fontSize`.
- The Format menu carries the same size controls: **Increase Size**
  (`Cmd+=`), **Decrease Size** (`Cmd+-`), and **Reset Size** (`Cmd+0`). Both
  the ribbon buttons and these menu items call the same
  `PlainEditorFontSettings` step functions, so they always agree.
- The font-family list (both the ribbon's Settings-driven picker and the
  Settings scene's **General** pane) is enumerated live from the fixed-pitch
  (monospace) font families actually installed on the system via
  `PlainEditorFontEnumeration`; a newly installed monospace font appears
  without a rebuild. The default remains SF Mono.

## Settings window

`Cmd+,` (or **SwiftlyCodeEdit > Settings...**) opens a standard macOS Settings
window with three tabs, built entirely from standard SwiftUI controls:

- **General**: font family and size. Reuses the same `PlainEditor.fontFamily`
  and `PlainEditor.fontSize` keys the command-bar ribbon's A-/A+/Reset
  shortcuts write, so the ribbon and this pane always agree.
- **Theme**: a picker over every theme `ThemeRepository` can discover -- the
  bundled default plus any user themes under
  `~/Library/Application Support/SwiftlyCodeEdit/Themes/` (see
  [docs/THEME_FORMAT.md](THEME_FORMAT.md)). Persisted under
  `PlainEditor.themeName`.
- **Editing**: indentation style (tabs vs. spaces) and width, persisted under
  `PlainEditor.indentationStyle` and `PlainEditor.indentationWidth`; and the
  default line ending for newly created files (LF or CRLF, defaulting to LF),
  persisted under `PlainEditor.defaultLineEnding`. These two settings are
  stored and exposed today; the editor does not yet consume them for
  auto-indent behavior or new-document creation.

Changing the font or theme applies immediately to every already-open
document window -- no relaunch required. The ribbon's A-/A+/Reset buttons
remain as transient per-window shortcuts; the Settings window is where these
preferences live permanently.

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

To add or override a language, drop a Kate XML syntax definition file into
`~/Library/Application Support/SwiftlyCodeEdit/Syntax/` and relaunch the app;
no rebuild is required. A user file is matched to the built-in corpus by its
lowercased filename (minus `.xml`), so a user `python.xml` replaces the
bundled Python definition rather than adding a duplicate. A file that fails
to parse is skipped (logged to stderr) without affecting any other language.
See [docs/FILE_FORMATS.md](FILE_FORMATS.md) for the collision rule in detail.

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
