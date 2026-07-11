import Foundation
import Testing
@testable import CodeEditSyntaxDefinitions

@Suite("User syntax directory merge")
struct UserSyntaxDirectoryMergeTests {
    // Every test writes its fixtures under a fresh temp directory and passes it
    // as `overrideRoot`, so no test ever touches or creates the real
    // ~/Library/Application Support/SwiftlyCodeEdit/Syntax/ directory.
    private func makeTempOverrideRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "UserSyntaxDirectoryMergeTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func syntaxDirectory(under root: URL) throws -> URL {
        let directory = root
            .appending(path: "SwiftlyCodeEdit", directoryHint: .isDirectory)
            .appending(path: "Syntax", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    // A minimal but real Kate XML definition: one context with one styled rule,
    // enough for `SyntaxDefinitionLoader.load` to parse and for
    // `highlightSpans` to return a non-empty result.
    private func kateXML(languageName: String, keyword: String) -> String {
        """
        <language name="\(languageName)" section="Test" version="1" kateversion="5.0">
          <highlighting>
            <contexts>
              <context name="Normal" attribute="Normal Text" lineEndContext="#stay">
                <StringDetect attribute="Keyword" String="\(keyword)"/>
              </context>
            </contexts>
          </highlighting>
        </language>
        """
    }

    @Test
    func discoverFileURLsReturnsEmptyMapWhenTheDirectoryDoesNotExistYet() throws {
        let root = try makeTempOverrideRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        // No Syntax subdirectory has been created under `root` at all.
        let discovered = UserSyntaxDirectory.discoverFileURLs(overrideRoot: root)
        #expect(discovered.isEmpty)
    }

    @Test
    func discoverFileURLsFindsXMLFilesKeyedByLowercasedFilenameStem() throws {
        let root = try makeTempOverrideRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let syntaxDirectory = try syntaxDirectory(under: root)
        let fileURL = syntaxDirectory.appending(path: "MyLang.xml")
        try kateXML(languageName: "MyLang", keyword: "letme").write(to: fileURL, atomically: true, encoding: .utf8)

        let discovered = UserSyntaxDirectory.discoverFileURLs(overrideRoot: root)
        // Compare resolved paths: `FileManager.contentsOfDirectory` returns
        // paths through `/private/var/...` on macOS, while `fileURL` was built
        // from the unresolved `/var/...` temp-directory symlink.
        #expect(discovered["mylang"]?.resolvingSymlinksInPath() == fileURL.resolvingSymlinksInPath())
    }

    @Test
    func mergedFileURLsLetsAUserFileWinOnACollidingKey() throws {
        let bundledURL = URL(fileURLWithPath: "/bundled/python.xml")
        let userURL = URL(fileURLWithPath: "/user/python.xml")
        let merged = SyntaxDefinitionLoader.mergedFileURLs(
            bundled: ["python": bundledURL, "rust": URL(fileURLWithPath: "/bundled/rust.xml")],
            user: ["python": userURL]
        )

        #expect(merged["python"] == userURL)
        #expect(merged["rust"] == URL(fileURLWithPath: "/bundled/rust.xml"))
    }

    @Test
    func newLanguageDroppedIntoTheSyntaxDirectoryHighlightsAfterRelaunchWithNoRebuild() throws {
        // "After relaunch with no rebuild" is proven at the repository-API level:
        // building a fresh repository instance (standing in for a fresh process
        // launch) from a merged map that includes a brand-new user-authored
        // language, then confirming it parses to real highlight spans.
        let root = try makeTempOverrideRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let syntaxDirectory = try syntaxDirectory(under: root)
        let fileURL = syntaxDirectory.appending(path: "userlang.xml")
        try kateXML(languageName: "UserLang", keyword: "hello")
            .write(to: fileURL, atomically: true, encoding: .utf8)

        let userFileURLs = UserSyntaxDirectory.discoverFileURLs(overrideRoot: root)
        let repository = SyntaxDefinitionRepository(
            fileURLs: SyntaxDefinitionLoader.mergedFileURLs(bundled: [:], user: userFileURLs)
        )

        let spans = repository.highlightSpans(text: "hello world", language: "userlang")
        #expect(spans.contains { $0.styleName == "Keyword" })
    }

    @Test
    func userFileWinsACollisionAndItsRulesAreWhatActuallyHighlight() throws {
        let root = try makeTempOverrideRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let syntaxDirectory = try syntaxDirectory(under: root)
        // The user override recognizes "overridekeyword", which the bundled
        // stand-in definition below does not define at all.
        let overrideURL = syntaxDirectory.appending(path: "collidinglang.xml")
        try kateXML(languageName: "CollidingLang", keyword: "overridekeyword")
            .write(to: overrideURL, atomically: true, encoding: .utf8)

        // The bundled stand-in lives in its own scoped temp subdirectory so its
        // cleanup is as contained as the override root above.
        let bundledStandInRoot = try makeTempOverrideRoot()
        defer { try? FileManager.default.removeItem(at: bundledStandInRoot) }
        let bundledStandInURL = bundledStandInRoot
            .appending(path: "collidinglang-bundled-\(UUID().uuidString).xml")
        try kateXML(languageName: "CollidingLang", keyword: "bundledonlykeyword")
            .write(to: bundledStandInURL, atomically: true, encoding: .utf8)

        let userFileURLs = UserSyntaxDirectory.discoverFileURLs(overrideRoot: root)
        let merged = SyntaxDefinitionLoader.mergedFileURLs(
            bundled: ["collidinglang": bundledStandInURL],
            user: userFileURLs
        )
        let repository = SyntaxDefinitionRepository(fileURLs: merged)

        let spans = repository.highlightSpans(text: "overridekeyword", language: "collidinglang")
        #expect(spans.contains { $0.styleName == "Keyword" })
    }

    @Test
    func malformedUserXMLIsSkippedWithoutCrashingAndOtherDefinitionsStillLoad() throws {
        let root = try makeTempOverrideRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let syntaxDirectory = try syntaxDirectory(under: root)
        // `SyntaxDefinitionLoader.load` requires a `<language ... name="...">`
        // tag to match at all; content with no such tag is what actually fails
        // to parse (unlike a merely-unclosed-but-still-matching tag).
        let malformedURL = syntaxDirectory.appending(path: "brokenlang.xml")
        try "this file has no language tag at all, it is not Kate XML".write(
            to: malformedURL,
            atomically: true,
            encoding: .utf8
        )
        let validURL = syntaxDirectory.appending(path: "goodlang.xml")
        try kateXML(languageName: "GoodLang", keyword: "fine").write(to: validURL, atomically: true, encoding: .utf8)

        let userFileURLs = UserSyntaxDirectory.discoverFileURLs(overrideRoot: root)
        let repository = SyntaxDefinitionRepository(
            fileURLs: SyntaxDefinitionLoader.mergedFileURLs(bundled: [:], user: userFileURLs)
        )

        // The malformed file's own language yields no definition (skipped, not
        // a crash), while the sibling valid file keeps working normally.
        #expect(repository.definition(forLanguage: "brokenlang") == nil)
        let goodSpans = repository.highlightSpans(text: "fine", language: "goodlang")
        #expect(goodSpans.contains { $0.styleName == "Keyword" })
    }
}
