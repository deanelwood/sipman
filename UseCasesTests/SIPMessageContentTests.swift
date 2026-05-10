//
//  SIPMessageContentTests.swift
//  UseCasesTests
//
//  Copyright © 2026 64 Characters
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

import UseCases
import XCTest

final class SIPMessageContentTests: XCTestCase {
    func testUsesPlainTextContentTypeByDefault() {
        let sut = SIPMessageContent(body: "Hello")

        XCTAssertEqual(sut.contentType, "text/plain")
    }

    func testUsesSpecifiedContentType() {
        let sut = SIPMessageContent(body: "<p>Hello</p>", contentType: "text/html")

        XCTAssertEqual(sut.contentType, "text/html")
    }

    func testIsEmptyWhenBodyIsEmpty() {
        XCTAssertTrue(SIPMessageContent(body: "").isEmpty)
    }

    func testIsNotEmptyWhenBodyIsNotEmpty() {
        XCTAssertFalse(SIPMessageContent(body: "Hello").isEmpty)
    }
}
