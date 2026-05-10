//
//  SIPMessageConversationTests.swift
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

final class SIPMessageConversationTests: XCTestCase {
    func testNormalizedParticipantRemovesWhitespaceAndNonDigits() {
        XCTAssertEqual(
            SIPMessageConversation.normalizedParticipant(" +44 (0) 7700-900123 ext. 45 "),
            "440770090012345"
        )
    }

    func testNormalizedParticipantsIncludesSenderAndRecipientsInNumericOrder() {
        let result = SIPMessageConversation.normalizedParticipants(
            sender: "+44 7700 900123",
            recipients: ["(020) 7946-0018", "555.0100"]
        )

        XCTAssertEqual(result, ["5550100", "02079460018", "447700900123"])
    }

    func testCanonicalParticipantsValueConcatenatesNormalizedParticipants() {
        let sut = SIPMessageConversation(
            sender: "+44 7700 900123",
            recipients: ["(020) 7946-0018", "555.0100"]
        )

        XCTAssertEqual(sut.canonicalParticipantsValue, "555010002079460018447700900123")
    }

    func testConversationIdIsStableSHA256HashOfCanonicalParticipantsValue() {
        let sut = SIPMessageConversation(
            sender: "+44 7700 900123",
            recipients: ["(020) 7946-0018", "555.0100"]
        )

        XCTAssertEqual(
            sut.conversationId,
            "6f4465cce07c4541b8f9e3005103982f9f280e82b5f78c03fbc33385969d2d0d"
        )
    }

    func testIdentifierIsConversationId() {
        let sut = SIPMessageConversation(sender: "123", recipient: "456")

        XCTAssertEqual(sut.identifier, sut.conversationId)
    }

    func testConversationIdIsIndependentOfSenderRecipientDirection() {
        let lhs = SIPMessageConversation(sender: "+44 7700 900123", recipient: "(020) 7946-0018")
        let rhs = SIPMessageConversation(sender: "(020) 7946-0018", recipient: "+44 7700 900123")

        XCTAssertEqual(lhs.conversationId, rhs.conversationId)
    }

    func testConversationIdIsIndependentOfRecipientOrder() {
        let lhs = SIPMessageConversation(sender: "+44 7700 900123", recipients: ["(020) 7946-0018", "555.0100"])
        let rhs = SIPMessageConversation(sender: "555.0100", recipients: ["+44 7700 900123", "(020) 7946-0018"])

        XCTAssertEqual(lhs.conversationId, rhs.conversationId)
    }

    func testEqualityUsesConversationId() {
        let lhs = SIPMessageConversation(sender: "+44 7700 900123", recipients: ["(020) 7946-0018", "555.0100"])
        let rhs = SIPMessageConversation(sender: "555.0100", recipients: ["+44 7700 900123", "(020) 7946-0018"])

        XCTAssertEqual(lhs, rhs)
    }
}
