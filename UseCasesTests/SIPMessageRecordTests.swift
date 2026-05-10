//
//  SIPMessageRecordTests.swift
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

final class SIPMessageRecordTests: XCTestCase {
    func testStoresMessageValues() {
        let remote = URI(user: "alice", host: "example.com", displayName: "Alice")
        let content = SIPMessageContent(body: "Hello")
        let date = Date()

        let sut = SIPMessageRecord(
            identifier: "message-id",
            accountUUID: "account-uuid",
            remote: remote,
            content: content,
            date: date,
            direction: .outgoing,
            deliveryState: .sending,
            transportIdentifier: "call-id"
        )

        XCTAssertEqual(sut.identifier, "message-id")
        XCTAssertEqual(sut.accountUUID, "account-uuid")
        XCTAssertEqual(sut.remote, remote)
        XCTAssertEqual(sut.content, content)
        XCTAssertEqual(sut.date, date)
        XCTAssertEqual(sut.direction, .outgoing)
        XCTAssertEqual(sut.deliveryState, .sending)
        XCTAssertEqual(sut.transportIdentifier, "call-id")
    }

    func testIncomingMessageDefaultsToIncomingReceived() {
        let sut = SIPMessageRecord.incoming(
            identifier: "message-id",
            accountUUID: "account-uuid",
            remote: URI(user: "alice", host: "example.com", displayName: ""),
            content: SIPMessageContent(body: "Hello"),
            date: Date(),
            transportIdentifier: "call-id"
        )

        XCTAssertEqual(sut.direction, .incoming)
        XCTAssertEqual(sut.deliveryState, .received)
        XCTAssertEqual(sut.transportIdentifier, "call-id")
    }

    func testOutgoingMessageDefaultsToOutgoingPending() {
        let sut = SIPMessageRecord.outgoing(
            identifier: "message-id",
            accountUUID: "account-uuid",
            remote: URI(user: "alice", host: "example.com", displayName: ""),
            content: SIPMessageContent(body: "Hello"),
            date: Date()
        )

        XCTAssertEqual(sut.direction, .outgoing)
        XCTAssertEqual(sut.deliveryState, .pending)
    }

    func testConversationIsDerivedFromAccountAndRemote() {
        let sut = SIPMessageRecord.outgoing(
            identifier: "message-id",
            accountUUID: "account-uuid",
            remote: URI(user: "alice", host: "example.com", displayName: "Alice"),
            content: SIPMessageContent(body: "Hello"),
            date: Date()
        )

        XCTAssertEqual(sut.conversation.identifier, "account-uuid|alice@example.com|udp")
    }

    func testUpdatingDeliveryStatePreservesMessageIdentityAndContent() {
        let sut = SIPMessageRecord.outgoing(
            identifier: "message-id",
            accountUUID: "account-uuid",
            remote: URI(user: "alice", host: "example.com", displayName: ""),
            content: SIPMessageContent(body: "Hello"),
            date: Date(),
            transportIdentifier: "call-id"
        )

        let result = sut.updatingDeliveryState(.failed("Forbidden"))

        XCTAssertEqual(result.identifier, sut.identifier)
        XCTAssertEqual(result.accountUUID, sut.accountUUID)
        XCTAssertEqual(result.remote, sut.remote)
        XCTAssertEqual(result.content, sut.content)
        XCTAssertEqual(result.date, sut.date)
        XCTAssertEqual(result.direction, sut.direction)
        XCTAssertEqual(result.transportIdentifier, sut.transportIdentifier)
        XCTAssertEqual(result.deliveryState, .failed("Forbidden"))
    }
}
