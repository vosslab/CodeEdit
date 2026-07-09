# Roadmap

Planned work for SwiftlyCodeEdit, in priority order. This file states priorities only; execution
detail, owners, and acceptance criteria live in
[MILESTONE3_CHECKLIST.md](../MILESTONE3_CHECKLIST.md) and
[docs/active_plans/active/scope_closure_plan.md](active_plans/active/scope_closure_plan.md).

## Planned work

1. **SwiftUI shell migration.** Replace the AppKit app shell (`@main enum CodeEditMain`, hand-built
   `NSMenu`/`NSDocument`) with a SwiftUI `App` + `DocumentGroup` and a SwiftUI `Commands` menu.
   AppKit survives only inside the isolated `TextView` bridge adapter, per the SwiftUI-first
   principle in [docs/HUMAN_GUIDANCE.md](HUMAN_GUIDANCE.md).
2. **Find and Replace.** Port the CodeEditSourceEditor find panel so Cmd-F opens a working find
   bar with literal and regex modes, next/previous navigation, and an undoable Replace/Replace All.
3. **Theme data files.** Move syntax colors out of hardcoded Swift into the data-driven format
   specified in `docs/THEME_FORMAT.md`, with bundled default light/dark themes and live-switching
   user themes loaded from Application Support.
4. **User syntax definition directories.** Let a Kate XML file dropped into Application Support
   highlight a new language after a relaunch, with no rebuild, and no rebuild required to add
   languages going forward.
5. **Clean Text menu.** Grow Clean Text from the single trailing-whitespace-trim action into the
   full safe cleaning set: line-ending normalization, final newline, tab/space conversion, and
   opt-in ASCII punctuation normalization.
6. **Large-file performance.** Make highlighting viewport-first and bound keystroke-triggered
   rehighlighting and status recomputation to the edited region, with a repeatable benchmark
   proving p95 keystroke handling under 16 ms on a 1 MB file.
7. **Liquid Glass chrome.** Move the command ribbon and status bar to macOS 26 `glassEffect`
   styling per [docs/LIQUID_GLASS.md](LIQUID_GLASS.md), leaving the editor text surface untouched,
   with captured evidence for light mode, dark mode, and reduced transparency.

## Intentionally not started

Per the non-goals in [docs/SCOPE.md](SCOPE.md), this project does not build:

- A built-in terminal, Git integration, LSP, or workspace/IDE surfaces.
- Auto-complete or a plugin/extension system.
- Cross-platform support; the target is Apple Silicon macOS 26 Tahoe or newer only.

## More detail

- [MILESTONE3_CHECKLIST.md](../MILESTONE3_CHECKLIST.md): human-readable tracking checklist for
  every gap above, plus document-lifecycle correctness fixes.
- [docs/active_plans/active/scope_closure_plan.md](active_plans/active/scope_closure_plan.md):
  the full milestone and work-package plan, including current execution status.
