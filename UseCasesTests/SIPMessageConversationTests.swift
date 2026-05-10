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
    func testIdentifierContainsAccountRemoteAddressAndTransport() {
        let sut = SIPMessageConversation(
            accountUUID: "account-uuid",
            remote: URI(
                user: "alice",
                address: ServiceAddress(host: "example.com", port: "5061"),
                displayName: "Alice",
                transport: .tls
            )
        )

        XCTAssertEqual(sut.identifier, "account-uuid|alice@example.com:5061|tls")
    }

    func testIdentifierOmitsAtSignWhenRemoteUserIsEmpty() {
        let sut = SIPMessageConversation(
            accountUUID: "account-uuid",
            remote: URI(address: ServiceAddress(host: "example.com"), transport: .udp)
        )

        XCTAssertEqual(sut.identifier, "account-uuid|example.com|udp")
    }

    func testEqualityUsesIdentifier() {
        let lhs = SIPMessageConversation(
            accountUUID: "account-uuid",
            remote: URI(user: "alice", host: "example.com", displayName: "Alice")
        )
        let rhs = SIPMessageConversation(
            accountUUID: "account-uuid",
            remote: URI(user: "alice", host: "example.com", displayName: "Alice Smith")
        )

        XCTAssertEqual(lhs, rhs)
    }
}
