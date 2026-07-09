# File formats

Reference for every file format SwiftlyCodeEdit reads or writes: the text
encodings the editor itself opens and saves, the bundled Kate syntax
definition XML, and the theme YAML schema (linked, not restated).

## Text file encodings

`FileEncoding` (`CodeEdit/Features/Documents/CodeFileDocument/FileEncoding.swift`)
enumerates every encoding the editor supports, in detection order:

- `utf8`
- `utf16BE` / `utf16LE`
- `windows1252`
- `latin1`

`CodeFileDocument.decode(data:)` (`CodeEdit/Features/Documents/CodeFileDocument/CodeFileDocument.swift`)
applies these in three passes:

1. **BOM-less UTF-16 plausibility check.** A file with no byte-order mark is
   sampled (first 4 KiB, byte pairs) for an interleaved-0x00 pattern typical
   of ASCII-range UTF-16 text. Over 60% of sampled pairs matching one
   direction (LE or BE) selects that encoding before Foundation's heuristic
   runs, because the heuristic otherwise misreads BOM-less UTF-16 as UTF-8
   (the interleaved NULs are valid standalone UTF-8 NULs) and lets NUL bytes
   leak into the decoded string uncaught.
2. **Foundation's encoding heuristic.** Runs over the ``FileEncoding`` cases
   with lossy conversion disallowed, resolving byte-order-marked UTF-8/16/32
   and other confident Unicode matches.
3. **Windows-1252 fallback.** Catches short, mostly-ASCII files carrying a
   single high byte that the heuristic misjudges as UTF-8 and fails to
   convert. This fallback also covers ISO Latin-1 text, since bytes
   0xA0-0xFF decode identically in both encodings. Five Windows-1252
   byte values are undefined (0x81, 0x8D, 0x8F, 0x90, 0x9D) and deliberately
   fail every path.

A file whose bytes match none of these encodings fails the whole decode:
`read(from:ofType:)` throws `CodeFileError.failedToDecode`, NSDocument
presents a real error alert, and no window opens. The editor never opens a
silent blank document for an undecodable file. `sourceEncoding` stores
whichever `FileEncoding` case decoded the file, so `data(ofType:)` saves back
to that same encoding; line endings are preserved as-is (the encoding layer
does no line-ending normalization). The status bar reports "Unknown" only
when no decoding was actually applied (`sourceEncoding` is `nil`), never a
false "UTF-8" claim.

## Kate syntax definition XML

Syntax highlighting is driven by upstream KDE/Kate XML syntax definitions,
bundled under `Packages/CodeEditSyntaxDefinitions/Sources/CodeEditSyntaxDefinitions/Resources/Vendor/Kate/`
(409 files at last count, one per language). `CodeEditSyntaxDefinitions`
parses each file into a `SyntaxDefinition` (contexts, rules, attribute
mappings) and runs it through a context-scoped interpreter to produce
`TokenRun`s and then `HighlightSpan`s; see
[docs/CODE_ARCHITECTURE.md](CODE_ARCHITECTURE.md) for the parse/interpret/
span-map pipeline stages and their performance seams (`FirstCharFilter`,
`CompiledRegexCache`).

A drop-in user syntax directory (a Kate XML file placed under
`~/Library/Application Support/SwiftlyCodeEdit/Syntax/` highlighting a new
language after a relaunch, no rebuild required) is planned but not yet
wired up: `UserDataDirectories` (`CodeEdit/Features/Support/UserDataDirectories.swift`)
already defines the `Syntax/` subdirectory path and a `discoverFiles`
helper, but no caller yet feeds discovered files into
`SyntaxDefinitionRepository`. Tracked in [docs/ROADMAP.md](ROADMAP.md).

## Theme YAML

Syntax highlighting color themes are one YAML (or JSON) file per theme,
with a versioned schema, light/dark variants, and a token-key fallback
chain. The full schema, semantic token keys, and malformed-file handling
live in [docs/THEME_FORMAT.md](THEME_FORMAT.md); this file only points there
so the schema has one canonical home. `UserDataDirectories` reserves the
matching `Themes/` subdirectory for user-supplied theme files, on the same
"not yet wired to a loader" basis as the syntax directory above.
