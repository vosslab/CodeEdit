//
//  PlainEditorFontSettingsTests.swift
//  CodeEditTests
//
//  Created by Codex on 2026-07-07.
//

import AppKit
import Testing
@testable import CodeEdit

@Suite
struct PlainEditorFontSettingsTests {
    @Test
    func defaultFontIsMonospace() {
        let font = PlainEditorFontSettings.font(
            family: PlainEditorFontSettings.defaultFontFamily,
            size: PlainEditorFontSettings.defaultFontSize
        )

        #expect(font.isFixedPitch)
        #expect(isSamePointSize(font.pointSize, PlainEditorFontSettings.defaultFontSize))
    }

    @Test
    func unavailableFontFallsBackToMonospace() {
        let font = PlainEditorFontSettings.font(family: "Definitely Not A Font", size: 15)

        #expect(font.isFixedPitch)
        #expect(font.pointSize == 15)
    }

    @Test
    func fontSizeIsClampedToUsableRange() {
        let small = PlainEditorFontSettings.font(family: PlainEditorFontSettings.defaultFontFamily, size: 1)
        let large = PlainEditorFontSettings.font(family: PlainEditorFontSettings.defaultFontFamily, size: 100)

        #expect(isSamePointSize(small.pointSize, PlainEditorFontSettings.minimumFontSize))
        #expect(isSamePointSize(large.pointSize, PlainEditorFontSettings.maximumFontSize))
    }

    @Test
    func availableFontFamiliesIsNonEmptyAndFixedPitch() {
        let families = PlainEditorFontSettings.availableFontFamilies

        #expect(!families.isEmpty)
        #expect(families.contains(PlainEditorFontSettings.defaultFontFamily))
        // Every enumerated family other than the guaranteed default must
        // resolve to an actual fixed-pitch NSFont, proving the enumeration
        // filtered out proportional families rather than passing everything
        // through.
        for family in families where family != PlainEditorFontSettings.defaultFontFamily {
            let font = NSFont(name: family, size: PlainEditorFontSettings.defaultFontSize)
            #expect(font?.isFixedPitch == true)
        }
    }

    @Test
    func increaseAndDecreaseFontSizeStepAndClamp() {
        let increased = PlainEditorFontSettings.increasedFontSize(from: PlainEditorFontSettings.defaultFontSize)
        #expect(isSamePointSize(increased, PlainEditorFontSettings.defaultFontSize + 1))

        let decreased = PlainEditorFontSettings.decreasedFontSize(from: PlainEditorFontSettings.defaultFontSize)
        #expect(isSamePointSize(decreased, PlainEditorFontSettings.defaultFontSize - 1))

        let clampedHigh = PlainEditorFontSettings.increasedFontSize(from: PlainEditorFontSettings.maximumFontSize)
        #expect(isSamePointSize(clampedHigh, PlainEditorFontSettings.maximumFontSize))

        let clampedLow = PlainEditorFontSettings.decreasedFontSize(from: PlainEditorFontSettings.minimumFontSize)
        #expect(isSamePointSize(clampedLow, PlainEditorFontSettings.minimumFontSize))
    }

    private func isSamePointSize(_ lhs: CGFloat, _ rhs: Double) -> Bool {
        abs(Double(lhs) - rhs) < 0.01
    }
}
