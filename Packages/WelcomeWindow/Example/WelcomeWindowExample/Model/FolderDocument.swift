//
//  FolderDocument.swift
//  CodeEditWelcomeWindowExample
//
//  Created by Giorgi Tchelidze on 28.05.25.
//

import SwiftUI
import UniformTypeIdentifiers

final class FolderDocument: NSDocument, ObservableObject {
    @Published var folderURL: URL?

    override static var autosavesInPlace: Bool { false }

    override func read(from url: URL, ofType typeName: String) throws {
        guard url.hasDirectoryPath else {
            throw NSError(
                domain: NSCocoaErrorDomain,
                code: NSFileReadUnknownError,
                userInfo: [NSLocalizedDescriptionKey: "Not a folder"]
            )
        }
        folderURL = url
    }

    override func makeWindowControllers() {
        let root = FolderView(document: self)
        let window = NSWindow(contentViewController: NSHostingController(rootView: root))
        addWindowController(NSWindowController(window: window))
    }

    // Override save to disable it or handle custom folder-based saving
    override func data(ofType typeName: String) throws -> Data {
        Data()
    }

    override static var readableTypes: [String] {
        return [UTType.folder.identifier]
    }
}
