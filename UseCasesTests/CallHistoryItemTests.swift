//
//  CallHistoryItemTests.swift
//  UseCasesTests
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

final class CallHistoryItemTests: XCTestCase {
    func testCreatesInboundItemFromIncomingRecord() {
        let record = makeRecord(isIncoming: true, isMissed: false)

        let sut = CallHistoryItem(record: record)

        XCTAssertEqual(sut.direction, .inbound)
    }

    func testCreatesOutboundItemFromOutgoingRecord() {
        let record = makeRecord(isIncoming: false, isMissed: false)

        let sut = CallHistoryItem(record: record)

        XCTAssertEqual(sut.direction, .outbound)
    }

    func testCreatesMissedItemFromMissedRecord() {
        let record = makeRecord(isIncoming: true, isMissed: true)

        let sut = CallHistoryItem(record: record)

        XCTAssertEqual(sut.direction, .missed)
    }

    func testUsesContactDetailsForDisplay() {
        let record = makeRecord(
            contact: MatchedContact(name: "Jane Field", address: .phone(number: "02070000000", label: "work"))
        )

        let sut = CallHistoryItem(record: record)

        XCTAssertEqual(sut.displayName, "Jane Field")
        XCTAssertEqual(sut.address, "02070000000")
        XCTAssertEqual(sut.addressLabel, "work")
        XCTAssertEqual(sut.title, "Jane Field")
    }

    func testFallsBackToUriDisplayNameWhenContactNameIsEmpty() {
        let record = makeRecord(
            uri: URI(user: "alice", host: "example.com", displayName: "Alice Example"),
            contact: MatchedContact(name: "", address: .email(address: "alice@example.com", label: "SIP"))
        )

        let sut = CallHistoryItem(record: record)

        XCTAssertEqual(sut.displayName, "Alice Example")
        XCTAssertEqual(sut.address, "alice@example.com")
        XCTAssertEqual(sut.title, "Alice Example")
    }

    func testGetAllUseCaseMapsContactRecordsToItems() {
        let output = CallHistoryItemGetAllUseCaseOutputSpy()
        let sut = CallHistoryItemGetAllUseCase(output: output)
        let record1 = makeRecord(uri: URI(user: "1001", host: "", displayName: ""))
        let record2 = makeRecord(uri: URI(user: "1002", host: "", displayName: ""))

        sut.update(records: [record1, record2])

        XCTAssertEqual(output.invokedItems, [CallHistoryItem(record: record1), CallHistoryItem(record: record2)])
    }
}

private final class CallHistoryItemGetAllUseCaseOutputSpy: CallHistoryItemGetAllUseCaseOutput {
    private(set) var invokedItems: [CallHistoryItem] = []

    func update(items: [CallHistoryItem]) {
        invokedItems = items
    }
}

private func makeRecord(
    uri: URI = URI(user: "1001", host: "", displayName: ""),
    isIncoming: Bool = true,
    isMissed: Bool = false,
    contact: MatchedContact = MatchedContact(name: "", address: .phone(number: "1001", label: ""))
) -> ContactCallHistoryRecord {
    return ContactCallHistoryRecord(
        origin: CallHistoryRecord(
            uri: uri,
            date: Date(timeIntervalSinceReferenceDate: 1),
            duration: 42,
            isIncoming: isIncoming,
            isMissed: isMissed
        ),
        contact: contact
    )
}
