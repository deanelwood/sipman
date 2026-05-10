//
//  SoftphoneCallHistoryStoreTests.swift
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

@MainActor
final class SoftphoneCallHistoryStoreTests: XCTestCase {
    func testShowsPresentationRecordsAsSwiftUIRows() {
        let sut = SoftphoneCallHistoryStore()
        let record = PresentationCallHistoryRecord(
            identifier: "record-1",
            contact: PresentationContact(
                title: "Alice",
                tooltip: "+447700900123",
                label: "mobile",
                color: .controlTextColor,
                address: "+447700900123"
            ),
            date: "Today, 12:00",
            duration: "01:23",
            isIncoming: true,
            isMissed: false
        )

        sut.show([record])

        XCTAssertEqual(
            sut.rows,
            [
                SoftphoneCallHistoryRowModel(
                    id: "record-1",
                    title: "Alice",
                    address: "+447700900123",
                    date: "Today, 12:00",
                    duration: "01:23",
                    isIncoming: true,
                    isMissed: false
                )
            ]
        )
    }

    func testRowPresentsMissedCallState() {
        let sut = SoftphoneCallHistoryRowModel(
            id: "any",
            title: "Alice",
            address: "+447700900123",
            date: "Today",
            duration: "",
            isIncoming: true,
            isMissed: true
        )

        XCTAssertEqual(sut.directionTitle, "Missed")
        XCTAssertEqual(sut.symbolName, "phone.down.fill")
        XCTAssertEqual(sut.detail, "+447700900123 - Today")
    }

    func testFiltersRowsByDirection() {
        let sut = SoftphoneCallHistoryStore()
        let inbound = makeRecord(identifier: "inbound", isIncoming: true, isMissed: false)
        let missed = makeRecord(identifier: "missed", isIncoming: true, isMissed: true)
        let outbound = makeRecord(identifier: "outbound", isIncoming: false, isMissed: false)

        sut.show([inbound, missed, outbound])

        XCTAssertEqual(sut.rows(matching: .all).map(\.id), ["inbound", "missed", "outbound"])
        XCTAssertEqual(sut.rows(matching: .inbound).map(\.id), ["inbound", "missed"])
        XCTAssertEqual(sut.rows(matching: .outbound).map(\.id), ["outbound"])
    }

    private func makeRecord(identifier: String, isIncoming: Bool, isMissed: Bool) -> PresentationCallHistoryRecord {
        PresentationCallHistoryRecord(
            identifier: identifier,
            contact: PresentationContact(
                title: identifier,
                tooltip: identifier,
                label: "",
                color: .controlTextColor,
                address: identifier
            ),
            date: "Today",
            duration: isMissed ? "" : "00:10",
            isIncoming: isIncoming,
            isMissed: isMissed
        )
    }
}
