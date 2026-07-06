//
//  TXTDocument.swift
//  Tests
//
//  Created by Giorgi Tchelidze on 23.05.25.
//

import SwiftUI
import UniformTypeIdentifiers

/// Minimal in-app plain-text document.
final class TXTDocument: NSDocument, ObservableObject {

    @Published var text = ""

    override static var autosavesInPlace: Bool { true }

    override func read(from data: Data, ofType typeName: String) throws {
        guard let string = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = string
    }

    override func data(ofType typeName: String) throws -> Data {
        text.data(using: .utf8) ?? Data()
    }

    override func makeWindowControllers() {
        let root = TXTEditorView(document: self)          // 👈  SwiftUI wrapper
        let window = NSWindow(contentViewController: NSHostingController(rootView: root))
        addWindowController(NSWindowController(window: window))
    }
}
