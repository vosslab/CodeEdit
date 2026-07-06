//
//  NSApp+Extensions.swift
//  Tests
//
//  Created by Giorgi Tchelidze on 23.05.25.
//

import AppKit
import SwiftUI

extension NSApplication {
    func findWindow(_ id: String) -> NSWindow? {
        windows.first { $0.identifier?.rawValue == id }
    }
}
