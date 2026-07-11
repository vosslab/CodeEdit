enum PlainEditorTextCleaner {
    /// Target line-ending style for `normalizeLineEndings` and `ensureFinalNewline`.
    /// String-backed so callers can round-trip through `rawValue` (for example
    /// persisting a chosen style to settings) instead of a manual switch.
    enum LineEndingStyle: String {
        case lf = "\n"
        case crlf = "\r\n"
    }

    static func trimTrailingHorizontalWhitespace(in text: String) -> String {
        var output = ""
        var line = ""

        // Iterate by unicode scalar, not Character: Swift merges a "\r\n"
        // pair into a single extended grapheme cluster, which would never
        // match a bare "\n" or "\r" comparison and would leave CRLF-ended
        // lines completely untrimmed.
        for scalar in text.unicodeScalars {
            if scalar == "\n" || scalar == "\r" {
                output += line.trimmingTrailingSpacesAndTabs()
                output.unicodeScalars.append(scalar)
                line = ""
            } else {
                line.unicodeScalars.append(scalar)
            }
        }

        output += line.trimmingTrailingSpacesAndTabs()
        return output
    }

    /// Rewrites every line ending (LF, CRLF, or lone CR) to the requested style.
    static func normalizeLineEndings(in text: String, to style: LineEndingStyle) -> String {
        var output = ""
        let scalars = Array(text.unicodeScalars)
        var index = 0

        // Index-based walk (not a for-in over unicodeScalars) so a "\r"
        // can peek at the following scalar and collapse a "\r\n" pair into
        // a single replacement instead of emitting the target ending twice.
        while index < scalars.count {
            let scalar = scalars[index]
            if scalar == "\r" {
                output += style.rawValue
                let nextIndex = index + 1
                if nextIndex < scalars.count && scalars[nextIndex] == "\n" {
                    index = nextIndex + 1
                } else {
                    index += 1
                }
            } else if scalar == "\n" {
                output += style.rawValue
                index += 1
            } else {
                output.unicodeScalars.append(scalar)
                index += 1
            }
        }

        return output
    }

    /// Appends the requested line ending if the text does not already end with one.
    /// An empty document is left empty; there is no line to terminate.
    static func ensureFinalNewline(in text: String, using style: LineEndingStyle = .lf) -> String {
        guard !text.isEmpty else {
            return text
        }

        // Check the trailing unicode scalar, not the trailing Character:
        // a text ending in "\r\n" has that pair merged into one grapheme
        // cluster, so a Character-level hasSuffix("\n") check would miss it.
        if let lastScalar = text.unicodeScalars.last, lastScalar == "\n" || lastScalar == "\r" {
            return text
        }

        return text + style.rawValue
    }

    /// Expands every tab to spaces, column-aware: each tab advances to the next
    /// multiple of `tabWidth`, and the column resets at each line boundary.
    static func convertTabsToSpaces(in text: String, tabWidth: Int) -> String {
        var output = ""
        var column = 0

        for scalar in text.unicodeScalars {
            if scalar == "\t" {
                let spacesToNextStop = tabWidth - (column % tabWidth)
                output += String(repeating: " ", count: spacesToNextStop)
                column += spacesToNextStop
            } else if scalar == "\n" || scalar == "\r" {
                output.unicodeScalars.append(scalar)
                column = 0
            } else {
                output.unicodeScalars.append(scalar)
                column += 1
            }
        }

        return output
    }

    /// Converts each line's leading indentation (spaces and tabs before the
    /// first non-whitespace character) into the most compact tab/space mix
    /// for `tabWidth`. Interior alignment spaces after the first non-whitespace
    /// character are left untouched, since those spaces are not indentation.
    static func convertSpacesToTabs(in text: String, tabWidth: Int) -> String {
        var output = ""
        var line = ""

        for scalar in text.unicodeScalars {
            if scalar == "\n" || scalar == "\r" {
                output += line.convertingLeadingIndentationToTabs(tabWidth: tabWidth)
                output.unicodeScalars.append(scalar)
                line = ""
            } else {
                line.unicodeScalars.append(scalar)
            }
        }

        output += line.convertingLeadingIndentationToTabs(tabWidth: tabWidth)
        return output
    }

    /// Maps curly quotes, en/em dashes, ellipsis, and similar smart-punctuation
    /// characters to plain ASCII equivalents. Every other Unicode character,
    /// including scripts and emoji, passes through unchanged. This is the
    /// explicit opt-in replacement for the deleted `PlainTextCleaner`, which
    /// mapped every codepoint above U+00FF to "?" and destroyed non-Latin text.
    static func normalizeSmartPunctuationToASCII(in text: String) -> String {
        var output = ""

        for scalar in text.unicodeScalars {
            if let replacement = smartPunctuationASCIIMap[scalar] {
                output += replacement
            } else {
                output.unicodeScalars.append(scalar)
            }
        }

        return output
    }

    private static let smartPunctuationASCIIMap: [Unicode.Scalar: String] = [
        "\u{2018}": "'", // left single quotation mark
        "\u{2019}": "'", // right single quotation mark
        "\u{201A}": "'", // single low-9 quotation mark
        "\u{201B}": "'", // single high-reversed-9 quotation mark
        "\u{201C}": "\"", // left double quotation mark
        "\u{201D}": "\"", // right double quotation mark
        "\u{201E}": "\"", // double low-9 quotation mark
        "\u{201F}": "\"", // double high-reversed-9 quotation mark
        "\u{2013}": "-", // en dash
        "\u{2014}": "--", // em dash
        "\u{2026}": "..." // horizontal ellipsis
    ]
}

private extension String {
    func trimmingTrailingSpacesAndTabs() -> String {
        var result = self
        while let last = result.last, last == " " || last == "\t" {
            result.removeLast()
        }
        return result
    }

    /// Converts only the leading run of spaces and tabs (the indentation
    /// prefix) into the smallest tab/space mix that reaches the same column,
    /// then reattaches the untouched remainder of the line.
    func convertingLeadingIndentationToTabs(tabWidth: Int) -> String {
        var column = 0
        var prefixEndIndex = startIndex

        for character in self {
            if character == " " {
                column += 1
            } else if character == "\t" {
                column += tabWidth - (column % tabWidth)
            } else {
                break
            }
            prefixEndIndex = index(after: prefixEndIndex)
        }

        let remainder = self[prefixEndIndex...]
        let tabCount = column / tabWidth
        let spaceCount = column % tabWidth
        let newPrefix = String(repeating: "\t", count: tabCount) + String(repeating: " ", count: spaceCount)
        return newPrefix + remainder
    }
}
