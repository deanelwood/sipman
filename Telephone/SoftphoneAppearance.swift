//
//  SoftphoneAppearance.swift
//  Telephone
//
//  Copyright © 2026 SIPMan
//
//  Telephone is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Telephone is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//

import AppKit
import SwiftUI

enum SoftphoneAppearanceMode: String {
    case light
    case dark

    init(isDarkModeEnabled: Bool) {
        self = isDarkModeEnabled ? .dark : .light
    }

    var isDarkModeEnabled: Bool {
        self == .dark
    }

    var colorScheme: ColorScheme {
        isDarkModeEnabled ? .dark : .light
    }

    var nsAppearanceName: NSAppearance.Name {
        isDarkModeEnabled ? .darkAqua : .aqua
    }

    var toggled: SoftphoneAppearanceMode {
        isDarkModeEnabled ? .light : .dark
    }
}

enum SoftphoneAppearance {
    static let userDefaultsKey = "SIPManAppearanceMode"
}

struct SoftphoneWindowAppearanceBinder: NSViewRepresentable {
    let mode: SoftphoneAppearanceMode

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        applyAppearance(to: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        applyAppearance(to: nsView)
    }

    private func applyAppearance(to view: NSView) {
        guard let appearance = NSAppearance(named: mode.nsAppearanceName) else {
            return
        }

        view.appearance = appearance
        NSApp.appearance = appearance

        DispatchQueue.main.async {
            view.window?.appearance = appearance
        }
    }
}
