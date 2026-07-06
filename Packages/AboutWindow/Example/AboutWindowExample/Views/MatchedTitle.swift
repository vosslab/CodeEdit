//
//  MatchedTitle.swift
//  AboutWindowExample
//
//  Created by Giorgi Tchelidze on 07.06.25.
//

import SwiftUI
import AboutWindow

struct MatchedTitle: View {
    @EnvironmentObject var namespaceWrapper: NamespaceWrapper
    @Environment(\.aboutWindowNavigation)
    private var aboutWindow

    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        VStack(alignment: .center) {
            Text(title)
                .matchedGeometryEffect(
                    id: AboutNamespaceID.title,
                    in: namespaceWrapper.namespace,
                    properties: .position,
                    anchor: .center
                )
            Button("Go Back") {
                aboutWindow?.pop()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
