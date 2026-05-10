//
//  SIPMessageRecord.swift
//  Telephone
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

import Foundation

public enum SIPMessageDirection: String, Sendable {
    case incoming
    case outgoing
}

public enum SIPMessageDeliveryState: Equatable, Sendable {
    case received
    case pending
    case sending
    case sent
    case failed(String)
}

public struct SIPMessageRecord: Equatable, Sendable {
    public let identifier: String
    public let accountUUID: String
    public let sender: String
    public let recipients: [String]
    public let content: SIPMessageContent
    public let date: Date
    public let direction: SIPMessageDirection
    public let deliveryState: SIPMessageDeliveryState
    public let transportIdentifier: String?

    public var conversationId: String {
        return conversation.conversationId
    }

    public var conversation: SIPMessageConversation {
        return SIPMessageConversation(sender: sender, recipients: recipients)
    }

    public init(
        identifier: String = UUID().uuidString,
        accountUUID: String,
        sender: String,
        recipients: [String],
        content: SIPMessageContent,
        date: Date,
        direction: SIPMessageDirection,
        deliveryState: SIPMessageDeliveryState,
        transportIdentifier: String? = nil
    ) {
        self.identifier = identifier
        self.accountUUID = accountUUID
        self.sender = sender
        self.recipients = recipients
        self.content = content
        self.date = date
        self.direction = direction
        self.deliveryState = deliveryState
        self.transportIdentifier = transportIdentifier
    }

    public static func incoming(
        identifier: String = UUID().uuidString,
        accountUUID: String,
        sender: String,
        recipient: String,
        content: SIPMessageContent,
        date: Date,
        transportIdentifier: String? = nil
    ) -> SIPMessageRecord {
        return incoming(
            identifier: identifier,
            accountUUID: accountUUID,
            sender: sender,
            recipients: [recipient],
            content: content,
            date: date,
            transportIdentifier: transportIdentifier
        )
    }

    public static func incoming(
        identifier: String = UUID().uuidString,
        accountUUID: String,
        sender: String,
        recipients: [String],
        content: SIPMessageContent,
        date: Date,
        transportIdentifier: String? = nil
    ) -> SIPMessageRecord {
        return SIPMessageRecord(
            identifier: identifier,
            accountUUID: accountUUID,
            sender: sender,
            recipients: recipients,
            content: content,
            date: date,
            direction: .incoming,
            deliveryState: .received,
            transportIdentifier: transportIdentifier
        )
    }

    public static func outgoing(
        identifier: String = UUID().uuidString,
        accountUUID: String,
        sender: String,
        recipient: String,
        content: SIPMessageContent,
        date: Date,
        transportIdentifier: String? = nil
    ) -> SIPMessageRecord {
        return outgoing(
            identifier: identifier,
            accountUUID: accountUUID,
            sender: sender,
            recipients: [recipient],
            content: content,
            date: date,
            transportIdentifier: transportIdentifier
        )
    }

    public static func outgoing(
        identifier: String = UUID().uuidString,
        accountUUID: String,
        sender: String,
        recipients: [String],
        content: SIPMessageContent,
        date: Date,
        transportIdentifier: String? = nil
    ) -> SIPMessageRecord {
        return SIPMessageRecord(
            identifier: identifier,
            accountUUID: accountUUID,
            sender: sender,
            recipients: recipients,
            content: content,
            date: date,
            direction: .outgoing,
            deliveryState: .pending,
            transportIdentifier: transportIdentifier
        )
    }

    public func updatingDeliveryState(_ deliveryState: SIPMessageDeliveryState) -> SIPMessageRecord {
        return SIPMessageRecord(
            identifier: identifier,
            accountUUID: accountUUID,
            sender: sender,
            recipients: recipients,
            content: content,
            date: date,
            direction: direction,
            deliveryState: deliveryState,
            transportIdentifier: transportIdentifier
        )
    }
}
