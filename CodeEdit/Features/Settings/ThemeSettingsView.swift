//
//  ThemeSettingsView.swift
//  CodeEdit
//
//  Created by Claude on 2026-07-10.
//

import SwiftUI

/// The Settings scene's "Theme" pane: a picker over every theme
/// `ThemeRepository` can currently discover (the bundled default plus any
/// user themes under Application Support), persisted to
/// `PlainEditorSettingsKeys.themeName`.
///
/// `PlainSyntaxHighlighter` is a plain `enum`, not a `View`, so it reads this
/// same key directly through `PlainEditorSettingsKeys.currentThemeName()`
/// rather than receiving the name as a parameter; every open document's
/// `CodeFileView` observes the same `@AppStorage` key and re-triggers a
/// highlight pass on change, so a theme switch here applies to already-open
/// windows without relaunching. `ThemeRepository.invalidateCache()` is called
/// on every picker change so a just-added or just-edited user theme file is
/// re-read from disk rather than serving a stale cached resolution.
struct ThemeSettingsView: View {
    @AppStorage(PlainEditorSettingsKeys.themeName)
    private var themeName = ThemeRepository.bundledDefaultThemeName
    @State private var availableThemeNames: [String] = [ThemeRepository.bundledDefaultThemeName]

    var body: some View {
        Form {
            Picker("Theme", selection: $themeName) {
                ForEach(availableThemeNames, id: \.self) { name in
                    Text(name).tag(name)
                }
            }
        }
        .padding(20)
        .frame(width: 360)
        .task {
            await loadAvailableThemeNames()
        }
        .onChange(of: themeName) { _, _ in
            ThemeRepository.invalidateCache()
        }
    }

    /// Discovers every theme file on disk off the main actor (theme discovery
    /// does file I/O and parsing), then hops back to update the picker's
    /// options. Always includes the bundled default name even if discovery
    /// somehow returns nothing, so the picker never shows an empty list.
    private func loadAvailableThemeNames() async {
        let names = await Task.detached(priority: .userInitiated) {
            ThemeRepository.loadAllThemes().map(\.name).sorted()
        }.value
        availableThemeNames = names.isEmpty ? [ThemeRepository.bundledDefaultThemeName] : names
    }
}
