//
//  SIPMessageRecord.swift
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
    public let remote: URI
    public let content: SIPMessageContent
    public let date: Date
    public let direction: SIPMessageDirection
    public let deliveryState: SIPMessageDeliveryState
    public let transportIdentifier: String?

    public var conversation: SIPMessageConversation {
        return SIPMessageConversation(accountUUID: accountUUID, remote: remote)
    }

    public init(
        identifier: String = UUID().uuidString,
        accountUUID: String,
        remote: URI,
        content: SIPMessageContent,
        date: Date,
        direction: SIPMessageDirection,
        deliveryState: SIPMessageDeliveryState,
        transportIdentifier: String? = nil
    ) {
        self.identifier = identifier
        self.accountUUID = accountUUID
        self.remote = remote
        self.content = content
        self.date = date
        self.direction = direction
        self.deliveryState = deliveryState
        self.transportIdentifier = transportIdentifier
    }

    public static func incoming(
        identifier: String = UUID().uuidString,
        accountUUID: String,
        remote: URI,
        content: SIPMessageContent,
        date: Date,
        transportIdentifier: String? = nil
    ) -> SIPMessageRecord {
        return SIPMessageRecord(
            identifier: identifier,
            accountUUID: accountUUID,
            remote: remote,
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
        remote: URI,
        content: SIPMessageContent,
        date: Date,
        transportIdentifier: String? = nil
    ) -> SIPMessageRecord {
        return SIPMessageRecord(
            identifier: identifier,
            accountUUID: accountUUID,
            remote: remote,
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
            remote: remote,
            content: content,
            date: date,
            direction: direction,
            deliveryState: deliveryState,
            transportIdentifier: transportIdentifier
        )
    }
}
