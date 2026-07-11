//
//  ThemeParser.swift
//  CodeEdit
//
//  Created by Claude on 2026-07-09.
//

import CodeEditHighlighting
import Foundation

/// A theme file failed to parse into a usable `SyntaxTheme`. Callers (see
/// `ThemeRepository`) catch this, log a warning naming the offending file and
/// reason, and fall back to the bundled default per docs/THEME_FORMAT.md rule
/// 3; a malformed theme never blocks startup or crashes the editor.
struct ThemeParseError: Error, CustomStringConvertible {
    let reason: String
    var description: String { reason }
}

/// Parses theme files against the docs/THEME_FORMAT.md schema. Runs off the
/// main actor: every type it produces (`SyntaxTheme`, `ThemeVariant`,
/// `ThemeColor`) is `Sendable`, and parsing itself touches no actor-isolated
/// state.
enum ThemeParser {
    /// Parses theme file contents. `fileExtension` selects the reader: `yaml`
    /// or `yml` uses the schema-specific YAML-subset reader below; `json`
    /// uses `JSONSerialization`, since docs/THEME_FORMAT.md documents the
    /// schema as format-neutral and accepts either extension.
    static func parse(contents: String, fileExtension: String) throws -> SyntaxTheme {
        let rawVariants: RawThemeDocument
        switch fileExtension.lowercased() {
        case "yaml", "yml":
            rawVariants = try parseYAMLSubset(contents)
        case "json":
            rawVariants = try parseJSON(contents)
        default:
            throw ThemeParseError(reason: "unsupported theme file extension '\(fileExtension)'")
        }
        return try build(from: rawVariants)
    }

    // A flat, format-neutral intermediate: both the YAML-subset reader and
    // the JSON reader produce this same shape, so validation and theme
    // construction below has exactly one implementation to maintain.
    private struct RawThemeDocument {
        var version: Int?
        var name: String?
        // "light"/"dark" -> flat key:hexString mapping for that variant.
        var variants: [String: [String: String]] = [:]
    }

    // MARK: - YAML-subset reader

    // docs/THEME_FORMAT.md's schema is exactly three levels deep (top-level
    // scalars, "variants", then one flat mapping per "light"/"dark"), so this
    // reads it as a small directive sequence rather than a general recursive
    // YAML parser: every line is either a top-level scalar assignment, the
    // "variants:" section header, a "light:"/"dark:" variant header, or a
    // key: "value" pair belonging to the current variant.
    private static func parseYAMLSubset(_ text: String) throws -> RawThemeDocument {
        var document = RawThemeDocument()
        var sawVariantsHeader = false
        var currentVariantKey: String?

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            guard let (key, value) = try parsedLine(String(rawLine)) else {
                continue // blank line or full-line comment
            }

            if !sawVariantsHeader {
                switch key {
                case ThemeSchemaKeys.versionKey:
                    guard let value, let versionNumber = Int(value) else {
                        throw ThemeParseError(reason: "'version' must be an integer")
                    }
                    document.version = versionNumber
                case ThemeSchemaKeys.nameKey:
                    guard let value, !value.isEmpty else {
                        throw ThemeParseError(reason: "'name' must be a non-empty string")
                    }
                    document.name = value
                case ThemeSchemaKeys.variantsKey where value == nil:
                    sawVariantsHeader = true
                default:
                    throw ThemeParseError(reason: "unexpected top-level key '\(key)' before 'variants:'")
                }
                continue
            }

            if key == ThemeSchemaKeys.lightVariantKey || key == ThemeSchemaKeys.darkVariantKey, value == nil {
                currentVariantKey = key
                document.variants[key] = document.variants[key] ?? [:]
                continue
            }

            guard let currentVariantKey else {
                throw ThemeParseError(reason: "key '\(key)' appears outside of a 'light:' or 'dark:' section")
            }
            guard let value else {
                throw ThemeParseError(reason: "key '\(key)' under '\(currentVariantKey)' has no value")
            }
            document.variants[currentVariantKey, default: [:]][key] = value
        }

        return document
    }

    // Splits one line into (key, value). Value is nil for a section header
    // ("variants:", "light:", "dark:"); otherwise it is the trimmed scalar,
    // unquoted if the source quoted it. Returns nil for a blank or
    // full-line-comment line, which the caller skips.
    private static func parsedLine(_ line: String) throws -> (key: String, value: String?)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed.hasPrefix("#") {
            return nil
        }
        guard let colonIndex = trimmed.firstIndex(of: ":") else {
            throw ThemeParseError(reason: "expected 'key: value' syntax on line: \(trimmed)")
        }
        let key = String(trimmed[trimmed.startIndex..<colonIndex]).trimmingCharacters(in: .whitespaces)
        var rest = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
        if rest.isEmpty {
            return (key, nil)
        }
        if rest.hasPrefix("\"") {
            let afterOpeningQuote = rest.index(after: rest.startIndex)
            guard let closingQuoteIndex = rest[afterOpeningQuote...].firstIndex(of: "\"") else {
                throw ThemeParseError(reason: "unterminated quoted value on line: \(trimmed)")
            }
            return (key, String(rest[afterOpeningQuote..<closingQuoteIndex]))
        }
        // Unquoted scalar (the integer version, or the bare snake_case name):
        // strip a trailing inline comment, if any.
        if let hashIndex = rest.firstIndex(of: "#") {
            rest = String(rest[..<hashIndex])
        }
        return (key, rest.trimmingCharacters(in: .whitespaces))
    }

    // MARK: - JSON reader

    private static func parseJSON(_ text: String) throws -> RawThemeDocument {
        guard let data = text.data(using: .utf8) else {
            throw ThemeParseError(reason: "theme file is not valid UTF-8")
        }
        guard let topLevel = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ThemeParseError(reason: "theme file is not a valid JSON object")
        }

        var document = RawThemeDocument()
        document.version = topLevel[ThemeSchemaKeys.versionKey] as? Int
        document.name = topLevel[ThemeSchemaKeys.nameKey] as? String

        guard let variantsObject = topLevel[ThemeSchemaKeys.variantsKey] as? [String: Any] else {
            throw ThemeParseError(reason: "theme file is missing a 'variants' object")
        }
        for variantKey in [ThemeSchemaKeys.lightVariantKey, ThemeSchemaKeys.darkVariantKey] {
            guard let variantObject = variantsObject[variantKey] as? [String: Any] else { continue }
            var flatVariant: [String: String] = [:]
            for (colorKey, colorValue) in variantObject {
                if let stringValue = colorValue as? String {
                    flatVariant[colorKey] = stringValue
                }
            }
            document.variants[variantKey] = flatVariant
        }
        return document
    }

    // MARK: - Building the validated theme

    private static func build(from document: RawThemeDocument) throws -> SyntaxTheme {
        guard let version = document.version else {
            throw ThemeParseError(reason: "theme file is missing 'version'")
        }
        guard version == 1 else {
            throw ThemeParseError(reason: "unsupported theme schema version \(version)")
        }
        guard let name = document.name else {
            throw ThemeParseError(reason: "theme file is missing 'name'")
        }

        // Rule 1 (docs/THEME_FORMAT.md): a variant missing `base_text` (or
        // `background`, also required so a theme file is self-contained) is
        // itself treated as malformed and dropped; rule 2's missing-variant
        // fallback then applies as long as the other variant is valid.
        let lightVariant = try? buildVariant(document.variants[ThemeSchemaKeys.lightVariantKey])
        let darkVariant = try? buildVariant(document.variants[ThemeSchemaKeys.darkVariantKey])

        guard let theme = SyntaxTheme(version: version, name: name, light: lightVariant, dark: darkVariant) else {
            throw ThemeParseError(reason: "theme '\(name)' has no usable 'light' or 'dark' variant")
        }
        return theme
    }

    private static func buildVariant(_ rawColors: [String: String]?) throws -> ThemeVariant {
        guard let rawColors else {
            throw ThemeParseError(reason: "variant is absent")
        }
        guard let baseTextHex = rawColors[ThemeSchemaKeys.baseTextKey],
              let baseText = ThemeColor(hex: baseTextHex) else {
            throw ThemeParseError(reason: "variant is missing a valid 'base_text' color")
        }
        guard let backgroundHex = rawColors[ThemeSchemaKeys.backgroundKey],
              let background = ThemeColor(hex: backgroundHex) else {
            throw ThemeParseError(reason: "variant is missing a valid 'background' color")
        }

        var tokens = [HighlightToken: ThemeColor]()
        for (token, key) in ThemeSchemaKeys.tokenKeysByToken {
            guard let hex = rawColors[key], let color = ThemeColor(hex: hex) else {
                continue // missing/invalid token color falls back to base_text at lookup time.
            }
            tokens[token] = color
        }

        var styles = [String: ThemeColor]()
        for (styleName, key) in ThemeSchemaKeys.styleKeysByStyleName {
            guard let hex = rawColors[key], let color = ThemeColor(hex: hex) else {
                continue // style keys are optional; missing ones fall back to the token color.
            }
            styles[styleName] = color
        }

        return ThemeVariant(baseText: baseText, background: background, tokens: tokens, styles: styles)
    }
}
