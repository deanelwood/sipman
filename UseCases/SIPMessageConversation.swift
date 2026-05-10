//
//  SIPMessageConversation.swift
//  Telephone
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

import CryptoKit
import Foundation

public struct SIPMessageConversation: Sendable {
    public let conversationId: String
    public let sender: String
    public let recipients: [String]
    public let normalizedParticipants: [String]
    public let canonicalParticipantsValue: String

    public var identifier: String {
        return conversationId
    }

    public init(sender: String, recipient: String) {
        self.init(sender: sender, recipients: [recipient])
    }

    public init(sender: String, recipients: [String]) {
        self.sender = sender
        self.recipients = recipients
        self.normalizedParticipants = SIPMessageConversation.normalizedParticipants(
            sender: sender,
            recipients: recipients
        )
        self.canonicalParticipantsValue = normalizedParticipants.joined()
        self.conversationId = stableHash(canonicalParticipantsValue)
    }

    public static func conversationId(sender: String, recipient: String) -> String {
        return conversationId(sender: sender, recipients: [recipient])
    }

    public static func conversationId(sender: String, recipients: [String]) -> String {
        return SIPMessageConversation(sender: sender, recipients: recipients).conversationId
    }

    public static func normalizedParticipant(_ value: String) -> String {
        return String(value.filter(isASCIIDigit))
    }

    public static func normalizedParticipants(sender: String, recipients: [String]) -> [String] {
        return ([sender] + recipients)
            .map(normalizedParticipant)
            .filter { !$0.isEmpty }
            .sorted(by: numericallyPrecedes)
    }
}

extension SIPMessageConversation: Equatable {
    public static func ==(lhs: SIPMessageConversation, rhs: SIPMessageConversation) -> Bool {
        return lhs.conversationId == rhs.conversationId
    }
}

private func isASCIIDigit(_ character: Character) -> Bool {
    return character >= "0" && character <= "9"
}

private func numericallyPrecedes(_ lhs: String, _ rhs: String) -> Bool {
    let normalizedLHS = trimmingLeadingZeroes(lhs)
    let normalizedRHS = trimmingLeadingZeroes(rhs)

    if normalizedLHS.count != normalizedRHS.count {
        return normalizedLHS.count < normalizedRHS.count
    }
    if normalizedLHS != normalizedRHS {
        return normalizedLHS < normalizedRHS
    }
    return lhs < rhs
}

private func trimmingLeadingZeroes(_ value: String) -> String {
    let result = value.drop { $0 == "0" }
    return result.isEmpty ? "0" : String(result)
}

private func stableHash(_ value: String) -> String {
    return SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
}
