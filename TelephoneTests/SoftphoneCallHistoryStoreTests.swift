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
        let occurredAt = Date(timeIntervalSince1970: 1_777_771_200)
        let record = PresentationCallHistoryRecord(
            identifier: "record-1",
            contact: PresentationContact(
                title: "Alice",
                tooltip: "+447700900123",
                label: "mobile",
                color: .controlTextColor,
                address: "+447700900123"
            ),
            occurredAt: occurredAt,
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
                    label: "mobile",
                    occurredAt: occurredAt,
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
            label: "mobile",
            occurredAt: Date(timeIntervalSince1970: 1_777_771_200),
            date: "Today",
            duration: "",
            isIncoming: true,
            isMissed: true
        )

        XCTAssertEqual(sut.directionTitle, "Missed")
        XCTAssertEqual(sut.symbolName, "phone.down.fill")
        XCTAssertEqual(sut.detail, "+447700900123 - Today")
    }

    func testRowBuildsFavouriteContactIDFromDisplayContact() {
        let sut = SoftphoneCallHistoryRowModel(
            id: "any",
            title: "Alice",
            address: "+44 7700 900123",
            label: "mobile",
            occurredAt: Date(timeIntervalSince1970: 1_777_771_200),
            date: "Today",
            duration: "",
            isIncoming: true,
            isMissed: false
        )

        XCTAssertEqual(sut.favouriteContactID, "Alice|mobile|+44 7700 900123")
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

    func testGroupsRowsIntoHumanDateSections() {
        let sut = SoftphoneCallHistoryStore()
        let now = makeDate(year: 2026, month: 5, day: 12, hour: 12)
        sut.show([
            makeRecord(identifier: "today", occurredAt: now),
            makeRecord(identifier: "yesterday", occurredAt: makeDate(year: 2026, month: 5, day: 11, hour: 18)),
            makeRecord(identifier: "last-week", occurredAt: makeDate(year: 2026, month: 5, day: 5, hour: 18)),
            makeRecord(identifier: "older", occurredAt: makeDate(year: 2026, month: 3, day: 20, hour: 18))
        ])

        let sections = sut.sections(matching: .all, calendar: testCalendar, now: now)

        XCTAssertEqual(sections.map(\.title), ["Today", "Yesterday", "Last week", "March 2026"])
        XCTAssertEqual(sections.map { $0.rows.map(\.id) }, [["today"], ["yesterday"], ["last-week"], ["older"]])
    }

    private var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.locale = Locale(identifier: "en_GB")
        calendar.firstWeekday = 2
        return calendar
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int) -> Date {
        DateComponents(calendar: testCalendar, timeZone: testCalendar.timeZone, year: year, month: month, day: day, hour: hour).date!
    }

    private func makeRecord(
        identifier: String,
        occurredAt: Date = Date(timeIntervalSince1970: 1_777_771_200),
        isIncoming: Bool = true,
        isMissed: Bool = false
    ) -> PresentationCallHistoryRecord {
        PresentationCallHistoryRecord(
            identifier: identifier,
            contact: PresentationContact(
                title: identifier,
                tooltip: identifier,
                label: "",
                color: .controlTextColor,
                address: identifier
            ),
            occurredAt: occurredAt,
            date: "Today",
            duration: isMissed ? "" : "00:10",
            isIncoming: isIncoming,
            isMissed: isMissed
        )
    }
}
