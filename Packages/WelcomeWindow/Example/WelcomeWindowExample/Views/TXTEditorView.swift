//
//  TXTEditorView.swift
//  CodeEditWelcomeWindowExample
//
//  Created by Giorgi Tchelidze on 27.05.25.
//
import SwiftUI

struct TXTEditorView: View {
    @ObservedObject var document: TXTDocument

    var body: some View {
        TextEditor(text: $document.text)
            .font(.system(.body, design: .monospaced))
            .frame(minWidth: 600, minHeight: 400)
    }
}
