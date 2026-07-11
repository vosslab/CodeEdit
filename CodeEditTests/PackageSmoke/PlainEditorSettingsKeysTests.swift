//
//  PlainEditorSettingsKeysTests.swift
//  CodeEditTests
//
//  Created by Claude on 2026-07-10.
//

import Foundation
import Testing
@testable import CodeEdit

@Suite
struct PlainEditorSettingsKeysTests {
    @Test
    func currentThemeNameFallsBackToTheBundledDefaultWhenUnset() {
        withRestoredThemeNameDefault {
            UserDefaults.standard.removeObject(forKey: PlainEditorSettingsKeys.themeName)
            #expect(PlainEditorSettingsKeys.currentThemeName() == ThemeRepository.bundledDefaultThemeName)
        }
    }

    @Test
    func currentThemeNameReadsAnExplicitlyStoredName() {
        withRestoredThemeNameDefault {
            UserDefaults.standard.set("solarized", forKey: PlainEditorSettingsKeys.themeName)
            #expect(PlainEditorSettingsKeys.currentThemeName() == "solarized")
        }
    }

    @Test
    func indentationStyleDisplayNamesAreDistinctForEachCase() {
        let names = Set(IndentationStyle.allCases.map(\.displayName))
        #expect(names.count == IndentationStyle.allCases.count)
    }

    @Test
    func lineEndingPreferenceRawValuesRoundTrip() {
        for preference in LineEndingPreference.allCases {
            #expect(LineEndingPreference(rawValue: preference.rawValue) == preference)
        }
    }

    /// Runs `body` with `UserDefaults.standard`'s theme-name key restored to
    /// its prior value afterward, since that key is process-wide shared
    /// state and this suite must not leak a stub value into other tests.
    private func withRestoredThemeNameDefault(_ body: () -> Void) {
        let key = PlainEditorSettingsKeys.themeName
        let previousValue = UserDefaults.standard.string(forKey: key)
        defer {
            if let previousValue {
                UserDefaults.standard.set(previousValue, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        body()
    }
}
