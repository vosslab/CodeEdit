//
//  PlainTextCleaner.swift
//  CodeEdit
//
//  Created by Codex on 2026-07-07.
//

import Foundation

enum PlainTextCleaner {
    static func clean(_ text: String) -> String {
        var content = asciiText(text)

        content = content.replacingOccurrences(of: " - ", with: ", ")
        content = content.replacingOccurrences(of: "*\t", with: "* ")
        content = content.replacingOccurrences(
            of: #"([0-9]+)\.\t"#,
            with: "$1. ",
            options: .regularExpression
        )
        content = content.replacingOccurrences(
            of: #"(?m)^([0-9]+\.\s)"#,
            with: "\n$1",
            options: .regularExpression
        )
        content = content.replacingOccurrences(
            of: #"\n\n[ \t]*-[ \t]*\n"#,
            with: "\n\n",
            options: .regularExpression
        )
        content = content.replacingOccurrences(
            of: #"\n{3,}"#,
            with: "\n\n",
            options: .regularExpression
        )

        return trimTrailingWhitespace(content)
    }

    static func asciiText(_ text: String) -> String {
        var content = text
        content = content.replacingOccurrences(of: "\r\n", with: "\n")
        content = content.replacingOccurrences(of: "\r", with: "\n")
        content = content.precomposedStringWithCanonicalMapping
        content = content.folding(options: [.diacriticInsensitive, .widthInsensitive], locale: .current)

        content = content
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\u{2004}", with: " ")
            .replacingOccurrences(of: "\u{2005}", with: " ")
            .replacingOccurrences(of: "\u{FEFF}", with: " ")
            .replacingOccurrences(of: "\u{201C}", with: "\"")
            .replacingOccurrences(of: "\u{201D}", with: "\"")
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{00AB}", with: "\"")
            .replacingOccurrences(of: "\u{00BB}", with: "\"")
            .replacingOccurrences(of: "\u{2026}", with: "...")
            .replacingOccurrences(of: "\u{2192}", with: "->")
            .replacingOccurrences(of: "\u{2190}", with: "<-")
            .replacingOccurrences(of: "\u{2010}", with: "-")
            .replacingOccurrences(of: "\u{2011}", with: "-")
            .replacingOccurrences(of: "\u{2012}", with: "-")
            .replacingOccurrences(of: "\u{2013}", with: "-")
            .replacingOccurrences(of: "\u{2014}", with: "-")
            .replacingOccurrences(of: "\u{2015}", with: "-")
            .replacingOccurrences(of: "\u{2212}", with: "-")
            .replacingOccurrences(of: "\u{2043}", with: "-")
            .replacingOccurrences(of: "\u{2E3A}", with: "-")
            .replacingOccurrences(of: "\u{2E3B}", with: "-")
            .replacingOccurrences(of: "\u{FE58}", with: "-")
            .replacingOccurrences(of: "\u{FE63}", with: "-")
            .replacingOccurrences(of: "\u{FF0D}", with: "-")
            .replacingOccurrences(of: "\u{2022}", with: "*")
            .replacingOccurrences(of: "\u{00B7}", with: "*")
            .replacingOccurrences(of: "\u{2713} Yes", with: "Yes")
            .replacingOccurrences(of: "\u{2717} No", with: "No")
            .replacingOccurrences(of: "\u{03BC}", with: "&micro;")
            .replacingOccurrences(of: "\u{20AC}", with: "&euro;")
            .replacingOccurrences(of: "\u{2122}", with: "&trade;")
            .replacingOccurrences(of: "\u{2080}", with: "&#x2080;")
            .replacingOccurrences(of: "\u{00D7}", with: "x")
            .replacingOccurrences(of: "\u{00F7}", with: "/")
            .replacingOccurrences(of: "\u{2260}", with: "!=")
            .replacingOccurrences(of: "\u{2264}", with: "<=")
            .replacingOccurrences(of: "\u{2265}", with: ">=")
            .replacingOccurrences(of: "\u{00B1}", with: "+/-")
            .replacingOccurrences(of: "\u{2248}", with: "~")
            .replacingOccurrences(of: "\u{2500}", with: "-")
            .replacingOccurrences(of: "\u{2502}", with: "|")
            .replacingOccurrences(of: "\u{250C}", with: "+")
            .replacingOccurrences(of: "\u{2510}", with: "+")
            .replacingOccurrences(of: "\u{2514}", with: "+")
            .replacingOccurrences(of: "\u{2518}", with: "+")
            .replacingOccurrences(of: "\u{251C}", with: "+")
            .replacingOccurrences(of: "\u{2524}", with: "+")
            .replacingOccurrences(of: "\u{252C}", with: "+")
            .replacingOccurrences(of: "\u{2534}", with: "+")
            .replacingOccurrences(of: "\u{253C}", with: "+")
            .replacingOccurrences(of: "\u{037C}", with: "(c)")
            .replacingOccurrences(of: "\u{200E}", with: "")
            .replacingOccurrences(of: "\u{200F}", with: "")
            .replacingOccurrences(of: "\u{FFFC}", with: "")

        let scalars = content.unicodeScalars.map { scalar -> UnicodeScalar in
            scalar.value <= 0x00FF ? scalar : UnicodeScalar(63)
        }
        content = String(String.UnicodeScalarView(scalars))

        return trimTrailingWhitespace(content)
    }

    private static func trimTrailingWhitespace(_ text: String) -> String {
        text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0).replacingOccurrences(of: #"[ \t]+$"#, with: "", options: .regularExpression) }
            .joined(separator: "\n")
    }
}
