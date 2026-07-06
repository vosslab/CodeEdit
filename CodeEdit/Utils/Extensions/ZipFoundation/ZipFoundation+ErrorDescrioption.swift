//
//  ZipFoundation+ErrorDescrioption.swift
//  CodeEdit
//
//  Created by Khan Winter on 8/14/25.
//

import Foundation

enum ArchiveExtractionError: LocalizedError {
    case cancelledOperation
    case unreadableArchive
    case unwritableArchive
    case invalidEntryPath
    case invalidCompressionMethod
    case invalidCRC32
    case invalidBufferSize
    case invalidEntrySize
    case invalidLocalHeaderDataOffset
    case invalidLocalHeaderSize
    case invalidCentralDirectoryOffset
    case invalidCentralDirectorySize
    case invalidCentralDirectoryEntryCount
    case missingEndOfCentralDirectoryRecord
    case uncontainedSymlink
    case unzipToolUnavailable(underlyingError: Error)
    case unzipFailed(terminationStatus: Int32, output: String)

    var errorDescription: String? {
        switch self {
        case .cancelledOperation:
            "Operation cancelled."
        case .unreadableArchive, .unzipToolUnavailable:
            "Unreadable archive."
        case .unwritableArchive:
            "Unwritable archive."
        case .invalidEntryPath:
            "Invalid entry path."
        case .invalidCompressionMethod:
            "Invalid compression method."
        case .invalidCRC32:
            "Invalid checksum."
        case .invalidBufferSize:
            "Invalid buffer size."
        case .invalidEntrySize:
            "Invalid entry size."
        case .invalidLocalHeaderDataOffset,
                .invalidLocalHeaderSize,
                .invalidCentralDirectoryOffset,
                .invalidCentralDirectorySize,
                .invalidCentralDirectoryEntryCount,
                .missingEndOfCentralDirectoryRecord,
                .unzipFailed:
            "Invalid file detected."
        case .uncontainedSymlink:
            "Uncontained symlink detected."
        }
    }

    var failureReason: String? {
        switch self {
        case .invalidLocalHeaderDataOffset:
            "Invalid local header data offset."
        case .invalidLocalHeaderSize:
            "Invalid local header size."
        case .invalidCentralDirectoryOffset:
            "Invalid central directory offset."
        case .invalidCentralDirectorySize:
            "Invalid central directory size."
        case .invalidCentralDirectoryEntryCount:
            "Invalid central directory entry count."
        case .missingEndOfCentralDirectoryRecord:
            "Missing end of central directory record."
        case .unzipFailed(let terminationStatus, let output):
            let outputDescription = output.isEmpty ? "No output." : output
            return "unzip exited with status \(terminationStatus): \(outputDescription)"
        case .unzipToolUnavailable(let underlyingError):
            return underlyingError.localizedDescription
        default:
            return nil
        }
    }
}
