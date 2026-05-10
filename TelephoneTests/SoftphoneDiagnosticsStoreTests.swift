//
//  SoftphoneDiagnosticsStoreTests.swift
//  TelephoneTests
//
//  Copyright © 2008-2016 Alexey Kuznetsov
//  Copyright © 2016-2026 64 Characters
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

@MainActor
final class SoftphoneDiagnosticsStoreTests: XCTestCase {
    func testStartsWithAccountDiagnostics() {
        let sut = SoftphoneDiagnosticsStore(accountUUID: "account-1", domain: "example.com", sipAddress: "1001@example.com")

        XCTAssertEqual(sut.snapshot.accountUUID, "account-1")
        XCTAssertEqual(sut.snapshot.domain, "example.com")
        XCTAssertEqual(sut.snapshot.sipAddress, "1001@example.com")
        XCTAssertEqual(sut.snapshot.registrationState, .offline)
        XCTAssertEqual(sut.snapshot.transport, "Auto")
        XCTAssertEqual(sut.snapshot.port, "Default")
    }

    func testCanMarkRegisteredAndOffline() {
        let sut = SoftphoneDiagnosticsStore(accountUUID: "account-1", domain: "example.com", sipAddress: "1001@example.com")

        sut.markRegistered()
        XCTAssertEqual(sut.snapshot.registrationState, .registered)
        XCTAssertNotEqual(sut.snapshot.lastRegistration, "--")

        sut.markOffline()
        XCTAssertEqual(sut.snapshot.registrationState, .offline)
        XCTAssertNotEqual(sut.snapshot.lastRegistration, "--")
    }

    func testCanUpdateTransport() {
        let sut = SoftphoneDiagnosticsStore(accountUUID: "account-1", domain: "example.com", sipAddress: "1001@example.com")

        sut.updateTransport("UDP", port: "5060")

        XCTAssertEqual(sut.snapshot.transport, "UDP")
        XCTAssertEqual(sut.snapshot.port, "5060")
    }
}
