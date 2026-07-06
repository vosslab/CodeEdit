//
//  AboutWindowExampleApp.swift
//  AboutWindowExample
//
//  Created by Giorgi Tchelidze on 02.06.25.
//

import SwiftUI
import AboutWindow

@main
struct AboutWindowExampleApp: App {
    var body: some Scene {
        Group {
            AboutWindow(
                actions: {
                    AboutButton(title: "Contributors", destination: {
                        ContributorsView()
                    })
                    AboutButton(title: "Acknowledgements", destination: {
                        AcknowledgementsView()
                    })
                    SomeActionButton(title: "Some Custom Stuff") {
                        MatchedTitle("Hello")
                    }
                },
                footer: {
                    FooterView(
                        primaryView: {
                            Link(destination: URL(string: "https://opensource.org/licenses/MIT")!) {
                                Text("MIT License")
                                    .underline()
                            }
                        },
                        secondaryView: {
                            Text("© 2025 Example Inc.")
                        }
                    )
                }
            )
        }
    }
}
