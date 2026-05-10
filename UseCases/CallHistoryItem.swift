//
//  CallHistoryItem.swift
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

public enum CallHistoryItemDirection: String, Sendable {
    case inbound
    case outbound
    case missed
}

public struct CallHistoryItem: Equatable, Sendable {
    public let identifier: String
    public let uri: URI
    public let displayName: String
    public let address: String
    public let addressLabel: String
    public let date: Date
    public let duration: Int
    public let direction: CallHistoryItemDirection

    public var title: String {
        return displayName.isEmpty ? address : displayName
    }

    public init(
        identifier: String,
        uri: URI,
        displayName: String,
        address: String,
        addressLabel: String,
        date: Date,
        duration: Int,
        direction: CallHistoryItemDirection
    ) {
        self.identifier = identifier
        self.uri = uri
        self.displayName = displayName
        self.address = address
        self.addressLabel = addressLabel
        self.date = date
        self.duration = duration
        self.direction = direction
    }

    public init(record: ContactCallHistoryRecord) {
        let contactAddress = CallHistoryItemAddress(address: record.contact.address)
        self.init(
            identifier: record.origin.identifier,
            uri: URI(record: record),
            displayName: record.contact.name.isEmpty ? record.origin.uri.displayName : record.contact.name,
            address: contactAddress.value,
            addressLabel: contactAddress.label,
            date: record.origin.date,
            duration: record.origin.duration,
            direction: Self.direction(for: record.origin)
        )
    }

    private static func direction(for record: CallHistoryRecord) -> CallHistoryItemDirection {
        if record.isMissed {
            return .missed
        }
        return record.isIncoming ? .inbound : .outbound
    }
}

public protocol CallHistoryItemGetAllUseCaseOutput: Sendable {
    func update(items: [CallHistoryItem])
}

public final class CallHistoryItemGetAllUseCase: Sendable {
    private let output: CallHistoryItemGetAllUseCaseOutput

    public init(output: CallHistoryItemGetAllUseCaseOutput) {
        self.output = output
    }
}

extension CallHistoryItemGetAllUseCase: ContactCallHistoryRecordGetAllUseCaseOutput {
    public func update(records: [ContactCallHistoryRecord]) {
        output.update(items: records.map(CallHistoryItem.init))
    }
}

private struct CallHistoryItemAddress {
    let value: String
    let label: String

    init(address: MatchedContact.Address) {
        switch address {
        case let .phone(number, label):
            value = number
            self.label = label
        case let .email(address, label):
            value = address
            self.label = label
        }
    }
}
