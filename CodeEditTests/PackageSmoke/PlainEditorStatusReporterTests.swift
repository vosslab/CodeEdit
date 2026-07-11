//
//  PlainEditorStatusReporterTests.swift
//  CodeEditTests
//
//  Created by Claude on 2026-07-10.
//
//  WP-Q2 incremental status metrics. The status bar's O(n) counting functions
//  moved from Swift-String passes (whole-document splits plus a grapheme word
//  scan, the measured ~2 s per-keystroke floor) to bounded UTF-16 scans over the
//  editor's NSString backing store. These tests pin that the fast scans agree
//  with a brute-force oracle across the buffer shapes typing, paste, undo, and
//  Clean Text produce, and that the chrome model reports the counts it computes.
//

import Foundation
import Testing
@testable import CodeEdit

@Suite
struct PlainEditorStatusReporterTests {
    // Brute-force reference for word count: the original identifier-oriented
    // definition -- maximal runs of letters, digits, and underscore -- computed
    // with Swift's grapheme-aware split. Production replaces this with a UTF-16
    // scan, so this oracle pins that the scan still agrees with the obvious rule.
    private func referenceWordCount(_ text: String) -> Int {
        let words = text.split { !$0.isLetter && !$0.isNumber && $0 != "_" }
        return words.count
    }

    // The counts are a function of the final buffer text, so exercising the buffer
    // shapes that typing, paste, undo, and Clean Text leave behind covers the
    // acceptance requirement that counts stay correct after each of those.
    @Test
    func wordCountMatchesBruteForceOracleAcrossEditShapes() {
        let samples = [
            "let value = 1",                                            // typing
            "func sample_name(argument: Int) -> Int { return argument * 2 }",  // pasted block
            "",                                                         // undo back to empty
            "one\ntwo\nthree",                                          // multiline
            "let x = 1\nlet y = 2\n",                                   // Clean Text result
            "snake_case_identifier and camelCase123",                  // underscores keep one word
            "a,b;c.d  e\tf",                                            // dense separators
        ]
        for sample in samples {
            let counted = PlainEditorStatusReporter.wordCount(in: sample as NSString)
            #expect(counted == referenceWordCount(sample))
        }
    }

    @Test
    func lineCountCountsBreaksPlusOne() {
        #expect(PlainEditorStatusReporter.lineCount(in: "" as NSString) == 1)
        #expect(PlainEditorStatusReporter.lineCount(in: "one line" as NSString) == 1)
        #expect(PlainEditorStatusReporter.lineCount(in: "a\nb\nc" as NSString) == 3)
        // A trailing newline yields the conventional extra empty line.
        #expect(PlainEditorStatusReporter.lineCount(in: "a\nb\n" as NSString) == 3)
        // A CRLF pair is one break, so a Windows-lineending file is not doubled.
        #expect(PlainEditorStatusReporter.lineCount(in: "a\r\nb\r\nc" as NSString) == 3)
        #expect(PlainEditorStatusReporter.lineCount(in: "a\rb" as NSString) == 2)
    }

    // A CRLF placed so the CR ends one scan chunk and the LF starts the next pins
    // the carried-carriage-return path that keeps CRLF a single break across a
    // chunk boundary.
    @Test
    func lineCountHandlesCrlfAcrossChunkBoundary() {
        var text = String(repeating: "x", count: 8191)
        text += "\r\n"
        text += String(repeating: "y", count: 10)
        #expect(PlainEditorStatusReporter.lineCount(in: text as NSString) == 2)
    }

    @Test
    func cursorLabelReportsLineAndColumn() {
        let text = "abc\ndef\nghi" as NSString
        #expect(
            PlainEditorStatusReporter.cursorLabel(
                text: text, selection: NSRange(location: 0, length: 0), totalLines: 3
            ) == "1/3:1"
        )
        #expect(
            PlainEditorStatusReporter.cursorLabel(
                text: text, selection: NSRange(location: 6, length: 0), totalLines: 3
            ) == "2/3:3"
        )
        #expect(
            PlainEditorStatusReporter.cursorLabel(
                text: text, selection: NSRange(location: 11, length: 0), totalLines: 3
            ) == "3/3:4"
        )
    }

    // Edge case missing from the fixed-input case above: an empty document, the
    // state a brand-new or fully-cleared document is in.
    @Test
    func cursorLabelReportsFirstPositionForEmptyDocument() {
        #expect(
            PlainEditorStatusReporter.cursorLabel(
                text: "" as NSString, selection: NSRange(location: 0, length: 0), totalLines: 1
            ) == "1/1:1"
        )
    }

    // Edge case missing from the fixed-input case above: a document with no
    // trailing newline, cursor at the very end of the buffer.
    @Test
    func cursorLabelReportsEndOfBufferWithNoTrailingNewline() {
        let text = "abc\ndef" as NSString
        #expect(
            PlainEditorStatusReporter.cursorLabel(
                text: text, selection: NSRange(location: 7, length: 0), totalLines: 2
            ) == "2/2:4"
        )
    }

    @Test
    func lineEndingLabelDetectsStyleInPrecedenceOrder() {
        #expect(PlainEditorStatusReporter.lineEndingLabel(in: "a\r\nb" as NSString) == "CRLF")
        #expect(PlainEditorStatusReporter.lineEndingLabel(in: "a\rb" as NSString) == "CR")
        #expect(PlainEditorStatusReporter.lineEndingLabel(in: "a\nb" as NSString) == "LF")
        #expect(PlainEditorStatusReporter.lineEndingLabel(in: "abc" as NSString) == "Unknown")
    }

    @Test
    func indentationLabelReportsDominantStyle() {
        #expect(PlainEditorStatusReporter.indentationLabel(in: "\tfoo\n\tbar" as NSString) == "Tabs")
        #expect(PlainEditorStatusReporter.indentationLabel(in: "    foo\n    bar" as NSString) == "Soft Tabs: 4")
        #expect(PlainEditorStatusReporter.indentationLabel(in: "no indent here" as NSString) == "Unknown")
    }

    // Pins the chrome model wiring: a full refresh on a loaded document formats the
    // counts the reporter computes, so a regression in either the functions or the
    // formatting shows up here.
    @Test
    @MainActor
    func chromeRefreshReportsCountsForLoadedDocument() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let sourceURL = directory.appending(path: "counts.swift")
        let text = "let alpha = 1\nlet beta = 2\n"
        try text.write(to: sourceURL, atomically: true, encoding: .utf8)

        let codeFile = try CodeFileDocument(
            for: sourceURL, withContentsOf: sourceURL, ofType: "public.source-code"
        )
        let chrome = PlainEditorChromeModel()
        chrome.refresh(document: codeFile, selection: NSRange(location: 0, length: 0))

        #expect(chrome.characterCount == "\((text as NSString).length) characters")
        #expect(chrome.lineCount == "3 lines")
        #expect(chrome.wordCount == "6 words")
        #expect(chrome.cursorPosition == "1/3:1")
    }

    // Regression for the confirmed WP-Q2 dedup bug: the cursor-label skip was keyed
    // only on (location, length, documentLength, totalLines), so an equal-length
    // edit entirely before the cursor -- one that leaves the raw cursor offset,
    // document length, and total line count all numerically unchanged while moving
    // where a newline sits inside that prefix -- produced a bit-identical
    // signature and kept a stale column. This is exactly the shape a Find/Replace
    // regex substitution leaves behind. Sequence: an edit refresh caches "2/2:3"
    // at offset 6 in "abc\ndefghi" (10 UTF-16 units); replacing the "abc\n" prefix
    // with the equal-length "xy\nz" yields "xy\nzdefghi" -- still 10 units, still
    // one line break, cursor still at offset 6 -- so the label must recompute to
    // "2/2:4" rather than stay "2/2:3".
    @Test
    @MainActor
    func cursorLabelRecomputesAfterEqualLengthEditBeforeCursor() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let sourceURL = directory.appending(path: "prefix_edit.txt")
        let text = "abc\ndefghi"
        try text.write(to: sourceURL, atomically: true, encoding: .utf8)

        let codeFile = try CodeFileDocument(
            for: sourceURL, withContentsOf: sourceURL, ofType: "public.plain-text"
        )
        let chrome = PlainEditorChromeModel()

        // Full refresh establishes the cached total-line denominator (2), then a
        // selection move to offset 6 caches the pre-edit cursor label.
        chrome.refresh(document: codeFile, selection: NSRange(location: 0, length: 0))
        chrome.refreshForSelectionChange(document: codeFile, selection: NSRange(location: 6, length: 0))
        #expect(chrome.cursorPosition == "2/2:3")

        // The equal-length edit entirely before the cursor: "abc\n" -> "xy\nz".
        codeFile.content?.replaceCharacters(in: NSRange(location: 0, length: 4), with: "xy\nz")
        chrome.refreshForEdit(document: codeFile, selection: NSRange(location: 6, length: 0))
        #expect(chrome.cursorPosition == "2/2:4")
    }
}
