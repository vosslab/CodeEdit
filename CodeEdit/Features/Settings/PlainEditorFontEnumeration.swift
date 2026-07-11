//
//  PlainEditorFontEnumeration.swift
//  CodeEdit
//
//  Created by Claude on 2026-07-10.
//

import CoreText

/// Enumerates the fixed-pitch (monospace) font families installed on the
/// system, so the Settings scene's font picker (`FontSettingsView`) always
/// reflects what is actually installed instead of a hardcoded list. This
/// uses CoreText, not AppKit: `CTFontManagerCopyAvailableFontFamilyNames`
/// and `CTFontGetSymbolicTraits` are pure font-data queries, so this helper
/// can live outside the AppKit-boundary allowlist files.
enum PlainEditorFontEnumeration {
    /// Every installed font family whose font is fixed-pitch (monospace),
    /// sorted alphabetically. A newly installed monospace font appears here
    /// without a rebuild, since the query runs against the live system font
    /// registry each time it is called.
    static func installedFixedPitchFamilies() -> [String] {
        let familyNames = CTFontManagerCopyAvailableFontFamilyNames() as? [String] ?? []
        let fixedPitchFamilies = familyNames.filter { isFixedPitchFamily($0) }
        return fixedPitchFamilies.sorted()
    }

    /// Whether the named family's regular-weight font carries CoreText's
    /// monospace symbolic trait. A representative 12pt instance is enough
    /// to read the trait; the trait does not vary with point size.
    private static func isFixedPitchFamily(_ family: String) -> Bool {
        let font = CTFontCreateWithName(family as CFString, 12.0, nil)
        let traits = CTFontGetSymbolicTraits(font)
        return traits.contains(.traitMonoSpace)
    }
}
