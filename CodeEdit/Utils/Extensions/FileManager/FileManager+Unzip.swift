//
//  FileManager+Unzip.swift
//  CodeEdit
//
//  Created by Codex on 7/6/26.
//

import Foundation

extension FileManager {
    /// Extracts a ZIP archive into a destination directory using the system `unzip` tool.
    func unzipItem(
        at sourceURL: URL,
        to destinationURL: URL,
        progress: Progress? = nil
    ) async throws {
        if progress?.isCancelled == true {
            throw ArchiveExtractionError.cancelledOperation
        }

        try createDirectory(at: destinationURL, withIntermediateDirectories: true, attributes: nil)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = [
            "-o",
            "-q",
            sourceURL.path(percentEncoded: false),
            "-d",
            destinationURL.path(percentEncoded: false)
        ]

        let stderrPipe = Pipe()
        process.standardOutput = Pipe()
        process.standardError = stderrPipe

        let terminationStatus: Int32 = try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { process in
                continuation.resume(returning: process.terminationStatus)
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: ArchiveExtractionError.unzipToolUnavailable(underlyingError: error))
            }
        }

        if progress?.isCancelled == true {
            process.terminate()
            throw ArchiveExtractionError.cancelledOperation
        }

        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let stderr = String(decoding: stderrData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)

        guard terminationStatus == 0 else {
            throw ArchiveExtractionError.unzipFailed(
                terminationStatus: terminationStatus,
                output: stderr
            )
        }
    }
}
