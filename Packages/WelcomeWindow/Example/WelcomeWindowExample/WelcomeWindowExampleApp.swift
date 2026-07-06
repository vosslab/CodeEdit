//
//  CodeEditWelcomeWindowExampleApp.swift
//  CodeEditWelcomeWindowExample
//
//  Created by Giorgi Tchelidze on 24.05.25.
//

import SwiftUI
import WelcomeWindow

@main
struct WelcomeWindowExampleApp: App {

    @Environment(\.openWindow)
    private var openWindow

    var body: some Scene {
        Group {
            WelcomeWindow(
                actions: { dismiss in
                    WelcomeButton(
                        iconName: "circle.fill",
                        title: "New Text Document",
                        action: {
                            NSDocumentController.shared.createFileDocumentWithDialog(
                                configuration: .init(title: "Create new text document"),
                                onCompletion: { dismiss() }
                            )
                        }
                    )
                    WelcomeButton(
                        iconName: "triangle.fill",
                        title: "Open Text Document or Folder",
                        action: {
                            NSDocumentController.shared.openDocumentWithDialog(
                                configuration: .init(canChooseDirectories: true),
                                onCompletion: { dismiss() },
                                onCancel: { openWindow(id: "welcome") }
                            )
                        }
                    )
                },
                onDrop: { url, dismiss in
                    print("File dropped at: \(url.path)")

                    Task {
                        NSDocumentController.shared.openDocument(at: url, onCompletion: { dismiss() })
                    }
                }
            )
        }
    }
}
