//
//  SoftphoneMessageStoreTests.swift
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

import AppKit
import UseCases
import XCTest

@MainActor
final class SoftphoneMessageStoreTests: XCTestCase {
    func testShowsLatestConversationRowsForAccountMessages() {
        let sut = SoftphoneMessageStore(accountUUID: "account-1", accountAddress: "1001")
        let older = incoming(identifier: "older", accountUUID: "account-1", sender: "2002", body: "Older", seconds: 1)
        let newer = incoming(identifier: "newer", accountUUID: "account-1", sender: "2002", body: "Newer", seconds: 2)
        let otherAccount = incoming(identifier: "other", accountUUID: "account-2", sender: "3003", body: "Ignored", seconds: 3)

        sut.show(records: [older, newer, otherAccount])

        XCTAssertEqual(sut.conversations.count, 1)
        XCTAssertEqual(sut.conversations.first?.id, newer.conversationId)
        XCTAssertEqual(sut.conversations.first?.title, "2002")
        XCTAssertEqual(sut.conversations.first?.preview, "Newer")
    }

    func testPrettyFormatsRegularPhoneNumbersInConversationRows() {
        let sut = SoftphoneMessageStore(accountUUID: "account-1", accountAddress: "1001")
        let record = incoming(
            identifier: "message-1",
            accountUUID: "account-1",
            sender: "+14155552671",
            body: "Hello",
            seconds: 1
        )

        sut.show(records: [record])

        XCTAssertEqual(sut.conversations.first?.title, "+1 415-555-2671")
    }

    func testSelectingConversationShowsMessagesInDateOrder() {
        let sut = SoftphoneMessageStore(accountUUID: "account-1", accountAddress: "1001")
        let first = incoming(identifier: "first", accountUUID: "account-1", sender: "2002", body: "First", seconds: 1)
        let second = SIPMessageRecord.outgoing(
            identifier: "second",
            accountUUID: "account-1",
            sender: "1001",
            recipient: "2002",
            content: SIPMessageContent(body: "Second"),
            date: Date(timeIntervalSinceReferenceDate: 2)
        ).updatingDeliveryState(.sent)

        sut.show(records: [second, first])
        sut.selectConversation(id: first.conversationId)

        XCTAssertEqual(sut.messages.map(\.id), ["first", "second"])
        XCTAssertEqual(sut.messages.map(\.body), ["First", "Second"])
        XCTAssertEqual(sut.messages.last?.deliveryState, "Sent")
        XCTAssertTrue(sut.messages.last?.isOutgoing == true)
    }

    func testMakeOutgoingRecordReturnsPendingRecordForNonEmptyBodyAndRecipients() {
        let sut = SoftphoneMessageStore(accountUUID: "account-1", accountAddress: "1001")

        let result = sut.makeOutgoingRecord(to: ["2002"], body: "Hello", date: Date(timeIntervalSinceReferenceDate: 1))

        XCTAssertEqual(result?.accountUUID, "account-1")
        XCTAssertEqual(result?.sender, "1001")
        XCTAssertEqual(result?.recipients, ["2002"])
        XCTAssertEqual(result?.content.body, "Hello")
        XCTAssertEqual(result?.deliveryState, .pending)
    }

    func testMakeOutgoingRecordRejectsEmptyInputs() {
        let sut = SoftphoneMessageStore(accountUUID: "account-1", accountAddress: "1001")

        XCTAssertNil(sut.makeOutgoingRecord(to: [], body: "Hello"))
        XCTAssertNil(sut.makeOutgoingRecord(to: ["2002"], body: ""))
    }
}

private func incoming(
    identifier: String,
    accountUUID: String,
    sender: String,
    body: String,
    seconds: TimeInterval
) -> SIPMessageRecord {
    return SIPMessageRecord.incoming(
        identifier: identifier,
        accountUUID: accountUUID,
        sender: sender,
        recipient: "1001",
        content: SIPMessageContent(body: body),
        date: Date(timeIntervalSinceReferenceDate: seconds)
    )
}
