//
//  SoftphoneDialPadTests.swift
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

import XCTest

final class SoftphoneDialPadTests: XCTestCase {
    func testStartsWithoutCallableDestination() {
        XCTAssertEqual(SoftphoneDialPad().destination, "")
        XCTAssertFalse(SoftphoneDialPad().canCall)
    }

    func testAppendsDialedValues() {
        var sut = SoftphoneDialPad()

        sut.append("+")
        sut.append("447700900123")

        XCTAssertEqual(sut.destination, "+447700900123")
        XCTAssertTrue(sut.canCall)
    }

    func testDeletesLastValue() {
        var sut = SoftphoneDialPad()
        sut.append("123")

        sut.deleteLast()

        XCTAssertEqual(sut.destination, "12")
    }

    func testDeletingEmptyDestinationDoesNothing() {
        var sut = SoftphoneDialPad()

        sut.deleteLast()

        XCTAssertEqual(sut.destination, "")
    }

    func testClearsDestination() {
        var sut = SoftphoneDialPad()
        sut.append("123")

        sut.clear()

        XCTAssertEqual(sut.destination, "")
        XCTAssertFalse(sut.canCall)
    }

    func testKeyboardActionAppendsDialableCharacters() {
        XCTAssertEqual(SoftphoneKeypadKeyboardAction(characters: "1", keyCode: 18), .append("1"))
        XCTAssertEqual(SoftphoneKeypadKeyboardAction(characters: "*", keyCode: 67), .append("*"))
        XCTAssertEqual(SoftphoneKeypadKeyboardAction(characters: "#", keyCode: 42), .append("#"))
        XCTAssertEqual(SoftphoneKeypadKeyboardAction(characters: "+", keyCode: 24), .append("+"))
    }

    func testKeyboardActionMapsEditingKeys() {
        XCTAssertEqual(SoftphoneKeypadKeyboardAction(characters: "\r", keyCode: 36), .submit)
        XCTAssertEqual(SoftphoneKeypadKeyboardAction(characters: nil, keyCode: 76), .submit)
        XCTAssertEqual(SoftphoneKeypadKeyboardAction(characters: nil, keyCode: 51), .deleteLast)
        XCTAssertEqual(SoftphoneKeypadKeyboardAction(characters: nil, keyCode: 117), .deleteLast)
        XCTAssertEqual(SoftphoneKeypadKeyboardAction(characters: "\u{1b}", keyCode: 53), .clear)
    }

    func testKeyboardActionIgnoresUnsupportedCharacters() {
        XCTAssertNil(SoftphoneKeypadKeyboardAction(characters: "a", keyCode: 0))
        XCTAssertNil(SoftphoneKeypadKeyboardAction(characters: "12", keyCode: 0))
        XCTAssertNil(SoftphoneKeypadKeyboardAction(characters: nil, keyCode: 0))
    }
}
