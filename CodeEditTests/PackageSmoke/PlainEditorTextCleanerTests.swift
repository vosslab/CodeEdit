//
//  PlainEditorTextCleanerTests.swift
//  CodeEditTests
//
//  Created by Codex on 2026-07-07.
//

import Testing
@testable import CodeEdit

@Suite
struct PlainEditorTextCleanerTests {
    @Test
    func trimsTrailingSpaces() {
        let input = "line one   \nline two"
        let output = PlainEditorTextCleaner.trimTrailingHorizontalWhitespace(in: input)

        #expect(output == "line one\nline two")
    }

    @Test
    func trimsTrailingTabs() {
        let input = "line one\t\t\nline two"
        let output = PlainEditorTextCleaner.trimTrailingHorizontalWhitespace(in: input)

        #expect(output == "line one\nline two")
    }

    @Test
    func trimsMixedTrailingSpacesAndTabs() {
        let input = "line one \t \nline two\t  "
        let output = PlainEditorTextCleaner.trimTrailingHorizontalWhitespace(in: input)

        #expect(output == "line one\nline two")
    }

    @Test
    func preservesCarriageReturnLineFeedEndings() {
        let input = "line one  \r\nline two\t\r\n"
        let output = PlainEditorTextCleaner.trimTrailingHorizontalWhitespace(in: input)

        #expect(output == "line one\r\nline two\r\n")
    }

    @Test
    func handlesEmptyInput() {
        let output = PlainEditorTextCleaner.trimTrailingHorizontalWhitespace(in: "")

        #expect(output.isEmpty)
    }

    @Test
    func preservesLoneCarriageReturnEndings() {
        let input = "line one \t\rline two  \r"
        let output = PlainEditorTextCleaner.trimTrailingHorizontalWhitespace(in: input)

        #expect(output == "line one\rline two\r")
    }

    @Test
    func trimsTrailingWhitespaceOnFinalLineWithoutNewline() {
        let input = "line one\nline two\t  "
        let output = PlainEditorTextCleaner.trimTrailingHorizontalWhitespace(in: input)

        #expect(output == "line one\nline two")
    }

    // MARK: - normalizeLineEndings

    @Test
    func normalizesCRLFToLF() {
        let input = "line one\r\nline two\r\n"
        let output = PlainEditorTextCleaner.normalizeLineEndings(in: input, to: .lf)

        #expect(output == "line one\nline two\n")
    }

    @Test
    func normalizesLFToCRLF() {
        let input = "line one\nline two\n"
        let output = PlainEditorTextCleaner.normalizeLineEndings(in: input, to: .crlf)

        #expect(output == "line one\r\nline two\r\n")
    }

    @Test
    func normalizesLoneCarriageReturnToLF() {
        let input = "line one\rline two\r"
        let output = PlainEditorTextCleaner.normalizeLineEndings(in: input, to: .lf)

        #expect(output == "line one\nline two\n")
    }

    @Test
    func normalizesMixedLineEndingsToOneStyle() {
        // Proves the CRLF pair is treated as one line ending (not two),
        // despite Swift merging "\r\n" into a single Character: a naive
        // per-Character walk that also matched bare "\r" and "\n" would
        // double the ending count and duplicate the replacement here.
        let input = "one\r\ntwo\nthree\rfour"
        let output = PlainEditorTextCleaner.normalizeLineEndings(in: input, to: .crlf)

        #expect(output == "one\r\ntwo\r\nthree\r\nfour")
        #expect(output.components(separatedBy: "\r\n").count == 4)
    }

    // MARK: - ensureFinalNewline

    @Test
    func addsFinalNewlineWhenMissing() {
        let output = PlainEditorTextCleaner.ensureFinalNewline(in: "line one", using: .lf)

        #expect(output == "line one\n")
    }

    @Test
    func doesNotDuplicateExistingFinalLFNewline() {
        let output = PlainEditorTextCleaner.ensureFinalNewline(in: "line one\n", using: .lf)

        #expect(output == "line one\n")
    }

    @Test
    func doesNotDuplicateExistingFinalCRLFNewline() {
        // The trailing "\r\n" is a single Swift Character, so this proves
        // the scalar-level check recognizes it as an ending rather than
        // appending a second one on top of the merged grapheme cluster.
        let output = PlainEditorTextCleaner.ensureFinalNewline(in: "line one\r\n", using: .lf)

        #expect(output == "line one\r\n")
    }

    @Test
    func appendsRequestedCRLFStyleWhenMissing() {
        let output = PlainEditorTextCleaner.ensureFinalNewline(in: "line one", using: .crlf)

        #expect(output == "line one\r\n")
    }

    @Test
    func leavesEmptyInputEmpty() {
        let output = PlainEditorTextCleaner.ensureFinalNewline(in: "", using: .lf)

        #expect(output.isEmpty)
    }

    // MARK: - convertTabsToSpaces

    @Test
    func expandsLeadingTabToFullWidth() {
        let output = PlainEditorTextCleaner.convertTabsToSpaces(in: "\tfoo", tabWidth: 4)

        #expect(output == "    foo")
    }

    @Test
    func expandsTabColumnAwareToNextStop() {
        // "a" occupies column 0, so the tab only needs 3 spaces to reach
        // column 4, not a full 4-space tab width.
        let output = PlainEditorTextCleaner.convertTabsToSpaces(in: "a\tb", tabWidth: 4)

        #expect(output == "a   b")
    }

    @Test
    func resetsTabColumnAtLineBoundary() {
        let input = "ab\tc\na\tb"
        let output = PlainEditorTextCleaner.convertTabsToSpaces(in: input, tabWidth: 4)

        #expect(output == "ab  c\na   b")
    }

    @Test
    func resetsTabColumnAcrossCRLFBoundary() {
        // Proves the column reset happens on the CRLF pair even though
        // Swift merges "\r\n" into a single Character.
        let input = "ab\tc\r\na\tb"
        let output = PlainEditorTextCleaner.convertTabsToSpaces(in: input, tabWidth: 4)

        #expect(output == "ab  c\r\na   b")
    }

    // MARK: - convertSpacesToTabs

    @Test
    func convertsFullLeadingIndentWidthToOneTab() {
        let output = PlainEditorTextCleaner.convertSpacesToTabs(in: "    foo", tabWidth: 4)

        #expect(output == "\tfoo")
    }

    @Test
    func convertsPartialRemainderToTrailingSpaces() {
        // 6 leading spaces at tabWidth 4 is one full tab stop (4) plus a
        // 2-space remainder that cannot become another tab.
        let output = PlainEditorTextCleaner.convertSpacesToTabs(in: "      foo", tabWidth: 4)

        #expect(output == "\t  foo")
    }

    @Test
    func preservesInteriorAlignmentSpaces() {
        // Only the leading indentation is converted; the spaces used to
        // align "= 1" after the assignment must stay spaces.
        let input = "    let x     = 1"
        let output = PlainEditorTextCleaner.convertSpacesToTabs(in: input, tabWidth: 4)

        #expect(output == "\tlet x     = 1")
    }

    @Test
    func leavesLinesWithNoLeadingWhitespaceUnchanged() {
        let output = PlainEditorTextCleaner.convertSpacesToTabs(in: "foo bar", tabWidth: 4)

        #expect(output == "foo bar")
    }

    @Test
    func convertsIndentationOnEveryLineIndependently() {
        let input = "    one\ntwo\n        three"
        let output = PlainEditorTextCleaner.convertSpacesToTabs(in: input, tabWidth: 4)

        #expect(output == "\tone\ntwo\n\t\tthree")
    }

    // MARK: - normalizeSmartPunctuationToASCII

    @Test
    func convertsCurlyQuotesToStraightQuotes() {
        let input = "\u{201C}hello\u{201D} and \u{2018}world\u{2019}"
        let output = PlainEditorTextCleaner.normalizeSmartPunctuationToASCII(in: input)

        #expect(output == "\"hello\" and 'world'")
    }

    @Test
    func convertsEnAndEmDashes() {
        let input = "pages 1\u{2013}9, a clause\u{2014}like this"
        let output = PlainEditorTextCleaner.normalizeSmartPunctuationToASCII(in: input)

        #expect(output == "pages 1-9, a clause--like this")
    }

    @Test
    func convertsEllipsisToThreeDots() {
        let input = "wait for it\u{2026}"
        let output = PlainEditorTextCleaner.normalizeSmartPunctuationToASCII(in: input)

        #expect(output == "wait for it...")
    }

    @Test
    func preservesNonSmartPunctuationUnicode() {
        // Regression guard for the deleted PlainTextCleaner defect, which
        // mapped every codepoint above U+00FF to "?". Greek, CJK, and emoji
        // must all survive normalization untouched.
        let input = "\u{03B1}\u{03B2}\u{03B3} \u{4F60}\u{597D} \u{1F600}"
        let output = PlainEditorTextCleaner.normalizeSmartPunctuationToASCII(in: input)

        #expect(output == input)
    }

    // MARK: - convertSpacesToTabs: mixed leading indentation

    @Test
    func convertsMixedLeadingSpaceTabIndentationToTabs() {
        // A leading " \t " run: one space (column 1), then a tab that jumps
        // to the next tabWidth-4 stop (column 4), then one more space
        // (column 5). Column 5 at tabWidth 4 is one full tab plus a
        // 1-space remainder.
        let output = PlainEditorTextCleaner.convertSpacesToTabs(in: " \t foo", tabWidth: 4)

        #expect(output == "\t foo")
    }

    // MARK: - convertTabsToSpaces / convertSpacesToTabs: tabWidth == 1

    @Test
    func convertsTabsToSpacesWithTabWidthOne() {
        // At tabWidth 1, every tab is exactly one space, since a width-1
        // stop is reached from any column with a single space.
        let output = PlainEditorTextCleaner.convertTabsToSpaces(in: "a\tb\tc", tabWidth: 1)

        #expect(output == "a b c")
    }

    @Test
    func convertsSpacesToTabsWithTabWidthOne() {
        // At tabWidth 1, every leading space becomes its own tab, with no
        // spaces remainder possible.
        let output = PlainEditorTextCleaner.convertSpacesToTabs(in: "   foo", tabWidth: 1)

        #expect(output == "\t\t\tfoo")
    }

    // MARK: - Idempotence

    @Test
    func trimTrailingHorizontalWhitespaceIsIdempotent() {
        let input = "line one   \nline two\t"
        let once = PlainEditorTextCleaner.trimTrailingHorizontalWhitespace(in: input)
        let twice = PlainEditorTextCleaner.trimTrailingHorizontalWhitespace(in: once)

        #expect(once == twice)
    }

    @Test
    func normalizeLineEndingsIsIdempotent() {
        let input = "one\r\ntwo\rthree\n"
        let once = PlainEditorTextCleaner.normalizeLineEndings(in: input, to: .crlf)
        let twice = PlainEditorTextCleaner.normalizeLineEndings(in: once, to: .crlf)

        #expect(once == twice)
    }

    @Test
    func ensureFinalNewlineIsIdempotent() {
        let input = "line one"
        let once = PlainEditorTextCleaner.ensureFinalNewline(in: input, using: .lf)
        let twice = PlainEditorTextCleaner.ensureFinalNewline(in: once, using: .lf)

        #expect(once == twice)
    }

    @Test
    func convertTabsToSpacesIsIdempotent() {
        let input = "a\tb\tc"
        let once = PlainEditorTextCleaner.convertTabsToSpaces(in: input, tabWidth: 4)
        let twice = PlainEditorTextCleaner.convertTabsToSpaces(in: once, tabWidth: 4)

        #expect(once == twice)
    }

    @Test
    func convertSpacesToTabsIsIdempotent() {
        let input = "      foo\n    bar"
        let once = PlainEditorTextCleaner.convertSpacesToTabs(in: input, tabWidth: 4)
        let twice = PlainEditorTextCleaner.convertSpacesToTabs(in: once, tabWidth: 4)

        #expect(once == twice)
    }

    @Test
    func normalizeSmartPunctuationToASCIIIsIdempotent() {
        let input = "\u{201C}hello\u{201D}\u{2014}world\u{2026}"
        let once = PlainEditorTextCleaner.normalizeSmartPunctuationToASCII(in: input)
        let twice = PlainEditorTextCleaner.normalizeSmartPunctuationToASCII(in: once)

        #expect(once == twice)
    }
}
