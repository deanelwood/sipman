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
        let sut = makeStore()

        XCTAssertEqual(sut.snapshot.accountUUID, "account-1")
        XCTAssertEqual(sut.snapshot.domain, "example.com")
        XCTAssertEqual(sut.snapshot.sipAddress, "1001@example.com")
        XCTAssertEqual(sut.snapshot.username, "1001")
        XCTAssertEqual(sut.snapshot.passwordStatus, "Stored in Keychain")
        XCTAssertEqual(sut.snapshot.registrationState, .offline)
        XCTAssertEqual(sut.snapshot.transport, "Auto")
        XCTAssertEqual(sut.snapshot.port, "Default")
        XCTAssertEqual(sut.snapshot.stunServerAddress, "stun.example.com:3478")
        XCTAssertEqual(sut.snapshot.turnServerAddress, "")
        XCTAssertTrue(sut.snapshot.usesICE)
        XCTAssertEqual(sut.snapshot.sipLogEntries, [])
    }

    func testCanMarkRegisteredAndOffline() {
        let sut = makeStore()

        sut.markRegistered()
        XCTAssertEqual(sut.snapshot.registrationState, .registered)
        XCTAssertNotEqual(sut.snapshot.lastRegistration, "--")

        sut.markOffline()
        XCTAssertEqual(sut.snapshot.registrationState, .offline)
        XCTAssertNotEqual(sut.snapshot.lastRegistration, "--")
    }

    func testCanUpdateTransport() {
        let sut = makeStore()

        sut.updateTransport("UDP", port: "5060")

        XCTAssertEqual(sut.snapshot.transport, "UDP")
        XCTAssertEqual(sut.snapshot.port, "5060")
    }

    func testCanUpdateLiveCallDiagnostics() {
        let sut = makeStore()

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
        let sut = makeStore()

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
        let sut = makeStore()
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

    func testCanAppendAndClearSIPLogEntries() {
        let sut = makeStore()

        sut.appendSIPLogLine("REGISTER sip:example.com SIP/2.0\n", level: 4)

        XCTAssertEqual(sut.snapshot.sipLogEntries.count, 1)
        XCTAssertEqual(sut.snapshot.sipLogEntries[0].level, 4)
        XCTAssertEqual(sut.snapshot.sipLogEntries[0].message, "REGISTER sip:example.com SIP/2.0")
        XCTAssertFalse(sut.snapshot.sipLogEntries[0].timestamp.isEmpty)

        sut.clearSIPLog()

        XCTAssertEqual(sut.snapshot.sipLogEntries, [])
    }

    func testSIPLogEntriesAreRolling() {
        let sut = makeStore()

        for index in 0..<505 {
            sut.appendSIPLogLine("line \(index)", level: 3)
        }

        XCTAssertEqual(sut.snapshot.sipLogEntries.count, 500)
        XCTAssertEqual(sut.snapshot.sipLogEntries.first?.message, "line 5")
        XCTAssertEqual(sut.snapshot.sipLogEntries.last?.message, "line 504")
    }

    func testAppendsSIPLogEntriesFromPJSIPNotifications() {
        let sut = makeStore()

        NotificationCenter.default.post(
            name: SoftphoneDiagnosticsStore.sipLogNotificationName,
            object: nil,
            userInfo: ["level": 3, "message": "SIP/2.0 200 OK"]
        )

        XCTAssertEqual(sut.snapshot.sipLogEntries.map(\.message), ["SIP/2.0 200 OK"])
    }

    func testSIPPingResultModelMapsPJSIPBridgeDictionary() {
        let sut = SoftphoneSIPPingResultModel(dictionary: [
            "target": "sip:9000@example.com;transport=tcp",
            "transport": "tcp",
            "status": "Response",
            "summary": "200 OK",
            "detail": "PJSIP event: RX_MSG",
            "rawResponse": "SIP/2.0 200 OK",
            "elapsedMilliseconds": NSNumber(value: 123.4)
        ])

        XCTAssertEqual(sut.target, "sip:9000@example.com;transport=tcp")
        XCTAssertEqual(sut.transport, "tcp")
        XCTAssertEqual(sut.status, "Response")
        XCTAssertEqual(sut.summary, "200 OK")
        XCTAssertEqual(sut.detail, "PJSIP event: RX_MSG")
        XCTAssertEqual(sut.rawResponse, "SIP/2.0 200 OK")
        XCTAssertEqual(sut.elapsed, "123 ms")
    }

    func testCanUpdateNetworkSettings() {
        let sut = makeStore()

        sut.updateNetworkSettings(
            stunServerAddress: "stun2.example.com",
            turnServerAddress: "turn.example.com:3478",
            usesICE: true
        )

        XCTAssertEqual(sut.snapshot.stunServerAddress, "stun2.example.com")
        XCTAssertEqual(sut.snapshot.turnServerAddress, "turn.example.com:3478")
        XCTAssertTrue(sut.snapshot.usesICE)
    }

    func testCanUpdateAccountSettings() {
        let sut = makeStore()

        sut.updateAccountSettings(
            domain: "sip.example.net",
            sipAddress: "2002@sip.example.net",
            username: "2002",
            passwordStatus: "Updated"
        )

        XCTAssertEqual(sut.snapshot.domain, "sip.example.net")
        XCTAssertEqual(sut.snapshot.sipAddress, "2002@sip.example.net")
        XCTAssertEqual(sut.snapshot.username, "2002")
        XCTAssertEqual(sut.snapshot.passwordStatus, "Updated")
    }

    func testServerAddressNormalizesHostAndPort() {
        XCTAssertEqual(SoftphoneServerAddress(" stun.example.com:3478 ").host, "stun.example.com")
        XCTAssertEqual(SoftphoneServerAddress(" stun.example.com:3478 ").port, 3478)
        XCTAssertEqual(SoftphoneServerAddress("[2001:db8::1]:3478").displayValue, "[2001:db8::1]:3478")
        XCTAssertEqual(SoftphoneServerAddress(host: "turn.example.com", port: 70000).displayValue, "turn.example.com")
    }

    private func makeStore() -> SoftphoneDiagnosticsStore {
        SoftphoneDiagnosticsStore(
            accountUUID: "account-1",
            domain: "example.com",
            sipAddress: "1001@example.com",
            username: "1001",
            passwordStatus: "Stored in Keychain",
            stunServerAddress: "stun.example.com:3478",
            turnServerAddress: "",
            usesICE: true
        )
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
