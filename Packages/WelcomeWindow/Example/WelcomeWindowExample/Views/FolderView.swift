//
//  FolderView.swift
//  CodeEditWelcomeWindowExample
//
//  Created by Giorgi Tchelidze on 28.05.25.
//
import SwiftUI

struct FolderView: View {
    @ObservedObject var document: FolderDocument

    var body: some View {
        VStack {
            if let url = document.folderURL {
                Text("Folder: \(url.lastPathComponent)")
                List {
                    let contents =
                    (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil))
                    ?? []
                    ForEach(contents, id: \.self) { file in
                        Text(file.lastPathComponent)
                    }
                }
            } else {
                Text("No folder loaded")
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}
