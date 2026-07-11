import Foundation

// Discovers user-authored Kate syntax XML files so `SyntaxDefinitionRepository`
// can merge them alongside the bundled corpus.
//
// This package is dependency-free (no import of the `CodeEdit` app target), and
// `CodeEdit` depends on this package, not the other way around, so this file
// cannot reuse `CodeEdit/Features/Support/UserDataDirectories.swift` directly.
// It mirrors that file's path policy instead: both must keep pointing at
// `~/Library/Application Support/SwiftlyCodeEdit/Syntax/`. `overrideRoot` gives
// tests the same temp-directory seam `UserDataDirectories` exposes, so no test
// ever touches the real Application Support directory.
enum UserSyntaxDirectory {
    static let appDirectoryName = "SwiftlyCodeEdit"
    static let subdirectoryName = "Syntax"

    // The user syntax directory URL. Does not create the directory; discovery
    // below tolerates a missing directory by returning an empty result.
    static func directoryURL(overrideRoot: URL? = nil, fileManager: FileManager = .default) -> URL {
        let applicationSupportRoot = overrideRoot ?? fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        return applicationSupportRoot
            .appending(path: appDirectoryName, directoryHint: .isDirectory)
            .appending(path: subdirectoryName, directoryHint: .isDirectory)
    }

    // Non-recursive discovery of user `.xml` syntax files, keyed the same way
    // as `SyntaxDefinitionLoader.loadBundledFileURLs` (lowercased filename stem)
    // so a same-named user file collides with, and later overrides, a bundled
    // one. Returns an empty map (never throws) when the directory does not
    // exist yet or cannot be read, so a fresh install with no user syntax files
    // behaves exactly like the bundled-only path did before this file existed.
    static func discoverFileURLs(overrideRoot: URL? = nil, fileManager: FileManager = .default) -> [String: URL] {
        let directoryURL = directoryURL(overrideRoot: overrideRoot, fileManager: fileManager)
        guard let contents = try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return [:]
        }
        let xmlFileURLs = contents.filter { candidateURL in
            candidateURL.pathExtension.lowercased() == "xml"
        }
        return Dictionary(
            uniqueKeysWithValues: xmlFileURLs.map { ($0.deletingPathExtension().lastPathComponent.lowercased(), $0) }
        )
    }
}
