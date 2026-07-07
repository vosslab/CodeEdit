//
//  PlainSyntaxHighlighter.swift
//  CodeEdit
//
//  Created by Codex on 2026-07-07.
//

import AppKit
import Foundation
import CodeEditHighlighting
import CodeEditLanguages
import CodeEditSyntaxDefinitions

enum PlainSyntaxHighlighter {
    static func highlight(storage: NSTextStorage, language: CodeLanguage) {
        let fullRange = NSRange(location: 0, length: storage.length)
        guard fullRange.length > 0 else { return }

        let text = storage.string
        let spans = CodeEditSyntaxDefinitions.highlightSpans(text: text, language: language.tsName)
        storage.setAttributes([.foregroundColor: NSColor.textColor], range: fullRange)
        apply(spans: spans, storage: storage, text: text)
    }

    private static func apply(spans: [HighlightSpan], storage: NSTextStorage, text: String) {
        for span in spans {
            let range = NSRange(span.range, in: text)
            storage.setAttributes([.foregroundColor: color(for: span.token)], range: range)
        }
    }

    private static func color(for token: HighlightToken) -> NSColor {
        switch token {
        case .comment:
            return .systemGreen
        case .string:
            return .systemRed
        case .keyword:
            return .systemBlue
        case .number:
            return .systemPurple
        case .function:
            return .systemOrange
        case .type:
            return .systemTeal
        case .operatorToken:
            return .secondaryLabelColor
        case .markup:
            return .systemPink
        case .plainText:
            return .textColor
        }
    }
}
