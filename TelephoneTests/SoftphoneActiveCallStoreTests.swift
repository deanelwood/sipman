//
//  SoftphoneActiveCallStoreTests.swift
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

import UseCases
import XCTest

@MainActor
final class SoftphoneActiveCallStoreTests: XCTestCase {
    func testUpsertsActiveCallPresentation() {
        let sut = SoftphoneActiveCallStore()

        sut.upsertCall(
            identifier: "call-1",
            remoteParty: "1001",
            status: "Connected",
            duration: "00:08",
            isMuted: true,
            isOnHold: false,
            statsSnapshot: nil
        )

        XCTAssertEqual(sut.calls.count, 1)
        XCTAssertEqual(sut.primaryCall?.remoteParty, "1001")
        XCTAssertEqual(sut.primaryCall?.status, "Connected")
        XCTAssertEqual(sut.primaryCall?.duration, "00:08")
        XCTAssertEqual(sut.primaryCall?.isMuted, true)
        XCTAssertEqual(sut.primaryCall?.isOnHold, false)
        XCTAssertEqual(sut.primaryCall?.quality, .waiting)
    }

    func testPrettyFormatsRegularPhoneNumbersForActiveCallPresentation() {
        let sut = SoftphoneActiveCallStore()

        sut.upsertCall(
            identifier: "call-1",
            remoteParty: "+14155552671",
            status: "Connected",
            duration: "00:08",
            isMuted: false,
            isOnHold: false,
            statsSnapshot: nil
        )

        XCTAssertEqual(sut.primaryCall?.remoteParty, "+1 415-555-2671")
    }

    func testUpdatesActiveCallHoldPresentation() {
        let sut = SoftphoneActiveCallStore()

        sut.upsertCall(
            identifier: "call-1",
            remoteParty: "1001",
            status: "Connected",
            duration: "00:08",
            isMuted: false,
            isOnHold: false,
            statsSnapshot: nil
        )
        sut.upsertCall(
            identifier: "call-1",
            remoteParty: "1001",
            status: "On hold",
            duration: "00:09",
            isMuted: false,
            isOnHold: true,
            statsSnapshot: nil
        )

        XCTAssertEqual(sut.primaryCall?.status, "On hold")
        XCTAssertEqual(sut.primaryCall?.isOnHold, true)
    }

    func testCollatesStatsPeaksForCall() {
        let sut = SoftphoneActiveCallStore()

        sut.upsertCall(
            identifier: "call-1",
            remoteParty: "1001",
            status: "Connected",
            duration: "00:08",
            isMuted: false,
            isOnHold: false,
            statsSnapshot: snapshot(metric: "RTT", live: "12.0 ms", numericValue: 12)
        )
        sut.upsertCall(
            identifier: "call-1",
            remoteParty: "1001",
            status: "Connected",
            duration: "00:09",
            isMuted: false,
            isOnHold: false,
            statsSnapshot: snapshot(metric: "RTT", live: "20.0 ms", numericValue: 20)
        )
        sut.upsertCall(
            identifier: "call-1",
            remoteParty: "1001",
            status: "Connected",
            duration: "00:10",
            isMuted: false,
            isOnHold: false,
            statsSnapshot: snapshot(metric: "RTT", live: "14.0 ms", numericValue: 14)
        )

        XCTAssertEqual(sut.primaryCall?.statsRows, [
            SoftphoneCallStatsRowModel(metric: "RTT", live: "14.0 ms", peak: "20.0 ms")
        ])
    }

    func testRemoveCallClearsPresentation() {
        let sut = SoftphoneActiveCallStore()

        sut.upsertCall(
            identifier: "call-1",
            remoteParty: "1001",
            status: "Connected",
            duration: "00:08",
            isMuted: false,
            isOnHold: false,
            statsSnapshot: nil
        )
        sut.removeCall(identifier: "call-1")

        XCTAssertTrue(sut.calls.isEmpty)
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
