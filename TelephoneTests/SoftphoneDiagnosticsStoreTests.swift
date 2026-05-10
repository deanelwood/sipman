//
//  SoftphoneDiagnosticsStoreTests.swift
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
import UseCases

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

    func testCanUpdateLiveCallDiagnostics() {
        let sut = SoftphoneDiagnosticsStore(accountUUID: "account-1", domain: "example.com", sipAddress: "1001@example.com")

        sut.updateActiveCall(
            identifier: "call-1",
            remoteParty: "+14155552671",
            status: "connected",
            duration: "00:08",
            statsSnapshot: snapshot(metric: "RX jitter", live: "12.0 ms", numericValue: 12)
        )

        XCTAssertEqual(sut.snapshot.activeCall?.id, "call-1")
        XCTAssertEqual(sut.snapshot.activeCall?.remoteParty, "+1 415-555-2671")
        XCTAssertEqual(sut.snapshot.activeCall?.status, "connected")
        XCTAssertEqual(sut.snapshot.activeCall?.duration, "00:08")
        XCTAssertEqual(sut.snapshot.activeCall?.quality, .good)
        XCTAssertEqual(sut.snapshot.activeCall?.statsRows, [
            SoftphoneCallStatsRowModel(metric: "RX jitter", live: "12.0 ms", peak: "12.0 ms")
        ])
    }

    func testCollatesLiveCallPeaks() {
        let sut = SoftphoneDiagnosticsStore(accountUUID: "account-1", domain: "example.com", sipAddress: "1001@example.com")

        sut.updateActiveCall(
            identifier: "call-1",
            remoteParty: "9000",
            status: "connected",
            duration: "00:08",
            statsSnapshot: snapshot(metric: "RTT", live: "20.0 ms", numericValue: 20)
        )
        sut.updateActiveCall(
            identifier: "call-1",
            remoteParty: "9000",
            status: "connected",
            duration: "00:09",
            statsSnapshot: snapshot(metric: "RTT", live: "12.0 ms", numericValue: 12)
        )

        XCTAssertEqual(sut.snapshot.activeCall?.statsRows, [
            SoftphoneCallStatsRowModel(metric: "RTT", live: "12.0 ms", peak: "20.0 ms")
        ])
    }

    func testCanRemoveLiveCallDiagnostics() {
        let sut = SoftphoneDiagnosticsStore(accountUUID: "account-1", domain: "example.com", sipAddress: "1001@example.com")
        sut.updateActiveCall(
            identifier: "call-1",
            remoteParty: "9000",
            status: "connected",
            duration: "00:08",
            statsSnapshot: snapshot(metric: "RTT", live: "20.0 ms", numericValue: 20)
        )

        sut.removeActiveCall(identifier: "call-1")

        XCTAssertNil(sut.snapshot.activeCall)
    }

    private func snapshot(metric: String, live: String, numericValue: Double) -> CallStatsSnapshot {
        return CallStatsSnapshot(
            sampledAt: Date(),
            rows: [CallStatsRow(metric: metric, live: live, numericLiveValue: NSNumber(value: numericValue))],
            quality: .good,
            sample: nil
        )
    }
}
