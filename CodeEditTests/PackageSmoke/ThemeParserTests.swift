//
//  ThemeParserTests.swift
//  CodeEditTests
//
//  Created by Claude on 2026-07-09.
//

import Testing
@testable import CodeEdit

@Suite
struct ThemeParserTests {
    @Test
    func parsesACompleteTwoVariantYAMLTheme() throws {
        let theme = try ThemeParser.parse(contents: Self.completeTwoVariantYAML, fileExtension: "yaml")

        #expect(theme.name == "solarized")
        #expect(theme.light != nil)
        #expect(theme.dark != nil)
        #expect(theme.light?.baseText == ThemeColor(hex: "#657B83"))
        #expect(theme.dark?.baseText == ThemeColor(hex: "#839496"))
    }

    @Test
    func parsesAMinimalOneVariantYAMLThemeWithNoStyleKeys() throws {
        let theme = try ThemeParser.parse(contents: Self.minimalOneVariantYAML, fileExtension: "yaml")

        #expect(theme.name == "minimal_dark")
        #expect(theme.light == nil)
        #expect(theme.dark != nil)
        #expect(theme.dark?.styles.isEmpty == true)
    }

    @Test
    func acceptsAnEquivalentJSONTheme() throws {
        let theme = try ThemeParser.parse(contents: Self.minimalOneVariantJSON, fileExtension: "json")

        #expect(theme.name == "minimal_dark")
        #expect(theme.dark?.baseText == ThemeColor(hex: "#D4D4D4"))
    }

    @Test
    func missingTokenKeyFallsBackToBaseTextAtLookupTime() throws {
        let theme = try ThemeParser.parse(contents: Self.minimalOneVariantYAML, fileExtension: "yaml")
        let variant = theme.variant(forDarkAppearance: true)

        // "markup" is present in the fixture, but a token never defined at all
        // (there is no key for it in this schema beyond the documented set) falls
        // back to base_text through the same resolution path a present-but-unknown
        // style name would use.
        #expect(variant.color(forToken: .plainText, styleName: nil) == variant.baseText)
    }

    @Test
    func styleKeyOverridesItsTokenColorAndUnknownStyleFallsBackToToken() throws {
        let theme = try ThemeParser.parse(contents: Self.completeTwoVariantYAML, fileExtension: "yaml")
        let variant = theme.variant(forDarkAppearance: false)

        #expect(variant.color(forToken: .function, styleName: "function") == ThemeColor(hex: "#268BD2"))
        #expect(variant.color(forToken: .function, styleName: "unknown style") == ThemeColor(hex: "#268BD2"))
    }

    @Test
    func missingVariantFallsBackToThePresentVariantForBothAppearances() throws {
        let theme = try ThemeParser.parse(contents: Self.minimalOneVariantYAML, fileExtension: "yaml")

        #expect(theme.variant(forDarkAppearance: true) == theme.variant(forDarkAppearance: false))
    }

    @Test
    func unknownSchemaVersionIsMalformed() {
        #expect(throws: ThemeParseError.self) {
            try ThemeParser.parse(contents: Self.unknownVersionYAML, fileExtension: "yaml")
        }
    }

    @Test
    func variantMissingBaseTextIsMalformedAndDroppedNotCrashed() throws {
        // The dark variant lacks base_text; light is valid, so the theme as a
        // whole still parses per rule 2 (missing/invalid variant falls back to
        // the other present one), matching docs/THEME_FORMAT.md rule 1's
        // "the whole variant is treated as malformed" wording.
        let theme = try ThemeParser.parse(contents: Self.variantMissingBaseTextYAML, fileExtension: "yaml")

        #expect(theme.light != nil)
        #expect(theme.dark == nil)
    }

    @Test
    func noUsableVariantAtAllIsMalformed() {
        #expect(throws: ThemeParseError.self) {
            try ThemeParser.parse(contents: Self.noUsableVariantYAML, fileExtension: "yaml")
        }
    }

    @Test
    func malformedSyntaxIsRejected() {
        #expect(throws: ThemeParseError.self) {
            try ThemeParser.parse(contents: "this is not : : valid\nkey without colon", fileExtension: "yaml")
        }
    }

    @Test
    func unsupportedFileExtensionIsRejected() {
        #expect(throws: ThemeParseError.self) {
            try ThemeParser.parse(contents: Self.minimalOneVariantYAML, fileExtension: "txt")
        }
    }

    // MARK: - Fixtures

    private static let completeTwoVariantYAML = """
    version: 1
    name: solarized
    variants:
      light:
        base_text: "#657B83"
        background: "#FDF6E3"
        comment: "#93A1A1"
        string: "#2AA198"
        keyword: "#859900"
        number: "#D33682"
        function: "#268BD2"
        type: "#B58900"
        operator: "#657B83"
        markup: "#DC322F"
        plain_text: "#657B83"
        style_function: "#268BD2"
      dark:
        base_text: "#839496"
        background: "#002B36"
        comment: "#586E75"
        string: "#2AA198"
        keyword: "#859900"
        number: "#D33682"
        function: "#268BD2"
        type: "#B58900"
        operator: "#839496"
        markup: "#DC322F"
        plain_text: "#839496"
    """

    private static let minimalOneVariantYAML = """
    version: 1
    name: minimal_dark
    variants:
      dark:
        base_text: "#D4D4D4"
        background: "#1E1E1E"
        comment: "#6A9955"
        string: "#CE9178"
        keyword: "#569CD6"
        number: "#B5CEA8"
        function: "#DCDCAA"
        type: "#4EC9B0"
        operator: "#D4D4D4"
        markup: "#D16969"
        plain_text: "#D4D4D4"
    """

    private static let minimalOneVariantJSON = """
    {
        "version": 1,
        "name": "minimal_dark",
        "variants": {
            "dark": {
                "base_text": "#D4D4D4",
                "background": "#1E1E1E",
                "comment": "#6A9955"
            }
        }
    }
    """

    private static let unknownVersionYAML = """
    version: 2
    name: future_theme
    variants:
      dark:
        base_text: "#D4D4D4"
        background: "#1E1E1E"
    """

    private static let variantMissingBaseTextYAML = """
    version: 1
    name: half_broken
    variants:
      light:
        base_text: "#000000"
        background: "#FFFFFF"
      dark:
        background: "#1E1E1E"
    """

    private static let noUsableVariantYAML = """
    version: 1
    name: totally_broken
    variants:
      light:
        background: "#FFFFFF"
      dark:
        background: "#1E1E1E"
    """
}
