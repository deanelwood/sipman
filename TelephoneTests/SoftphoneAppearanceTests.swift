//
//  SoftphoneAppearanceTests.swift
//  TelephoneTests
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

import SwiftUI
import XCTest

final class SoftphoneAppearanceTests: XCTestCase {
    func testMapsDarkModeToggleToAppearanceMode() {
        XCTAssertEqual(SoftphoneAppearanceMode(isDarkModeEnabled: true), .dark)
        XCTAssertEqual(SoftphoneAppearanceMode(isDarkModeEnabled: false), .light)
    }

    func testMapsAppearanceModeToColorScheme() {
        XCTAssertEqual(SoftphoneAppearanceMode.dark.colorScheme, .dark)
        XCTAssertEqual(SoftphoneAppearanceMode.light.colorScheme, .light)
    }

    func testMapsAppearanceModeToMacAppearance() {
        XCTAssertEqual(SoftphoneAppearanceMode.dark.nsAppearanceName, .darkAqua)
        XCTAssertEqual(SoftphoneAppearanceMode.light.nsAppearanceName, .aqua)
    }

    func testTogglesAppearanceMode() {
        XCTAssertEqual(SoftphoneAppearanceMode.light.toggled, .dark)
        XCTAssertEqual(SoftphoneAppearanceMode.dark.toggled, .light)
    }

    func testUsesStableUserDefaultsKey() {
        XCTAssertEqual(SoftphoneAppearance.userDefaultsKey, "SIPManAppearanceMode")
    }
}
