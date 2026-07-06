//
//  SomeActionButton.swift
//  AboutWindowExample
//
//  Created by Giorgi Tchelidze on 04.06.25.
//
import SwiftUI
import AboutWindow

public struct SomeActionButton: View, NavigableAction {
    let title: String
    let destination: AnyView

    @Environment(\.aboutWindowNavigation)
    private var aboutWindow

    public init<V: View>(title: String, @ViewBuilder destination: () -> V) {
        self.title = title
        self.destination = AnyView(destination())
    }

    public var body: some View {
        Button {
            aboutWindow?.navigate(self)
        } label: {
            Text(title)
                .padding(.horizontal, 7.5)
                .padding(.vertical, 5)
                .background(.gray.opacity(0.3))
                .clipShape(.capsule)
        }
        .buttonStyle(.plain)
    }

    public func destinationView() -> AnyView {
        destination
    }
}
