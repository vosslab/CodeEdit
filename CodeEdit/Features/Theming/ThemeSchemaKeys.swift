//
//  ThemeSchemaKeys.swift
//  CodeEdit
//
//  Created by Claude on 2026-07-09.
//

import CodeEditHighlighting
import Foundation

/// The schema key vocabulary from docs/THEME_FORMAT.md's "Semantic token
/// color keys" section: one source of truth for both the parser (reading
/// theme files) and the bundled default theme (writing them), so the two
/// never drift apart.
enum ThemeSchemaKeys {
    static let versionKey = "version"
    static let nameKey = "name"
    static let variantsKey = "variants"
    static let lightVariantKey = "light"
    static let darkVariantKey = "dark"
    static let baseTextKey = "base_text"
    static let backgroundKey = "background"

    /// Token keys, one per `HighlightToken` case, in schema-doc order.
    static let tokenKeysByToken: [HighlightToken: String] = [
        .comment: "comment",
        .string: "string",
        .keyword: "keyword",
        .number: "number",
        .function: "function",
        .type: "type",
        .operatorToken: "operator",
        .markup: "markup",
        .plainText: "plain_text"
    ]

    /// Style refinement keys, mapped to the Kate `styleName` the highlighter
    /// matches case-insensitively, matching `PlainSyntaxHighlighter`'s prior
    /// hardcoded `styleColors` table.
    static let styleKeysByStyleName: [String: String] = [
        "imports": "style_imports",
        "variable": "style_variable",
        "data type": "style_data_type",
        "function": "style_function",
        "annotation": "style_annotation",
        "string interpolation": "style_string_interpolation"
    ]
}
