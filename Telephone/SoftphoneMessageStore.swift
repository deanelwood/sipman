//
//  SoftphoneMessageStore.swift
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
import UseCases

struct SoftphoneMessageConversationRowModel: Equatable, Identifiable {
    let id: String
    let title: String
    let preview: String
    let date: String
    let address: String
}

struct SoftphoneMessageBubbleModel: Equatable, Identifiable {
    let id: String
    let senderTitle: String
    let body: String
    let date: String
    let isOutgoing: Bool
    let deliveryState: String
}

@MainActor
@objc
final class SoftphoneMessageStore: NSObject, ObservableObject {
    @Published private(set) var conversations: [SoftphoneMessageConversationRowModel] = []
    @Published private(set) var messages: [SoftphoneMessageBubbleModel] = []
    @Published private(set) var selectedConversationId: String?

    private let accountUUID: String
    private let accountAddress: String
    private let dateFormatter: DateFormatter
    private let userDefaults: UserDefaults
    private var records: [SIPMessageRecord] = []

    @objc init(accountUUID: String, accountAddress: String) {
        self.accountUUID = accountUUID
        self.accountAddress = accountAddress
        self.dateFormatter = DateFormatter()
        self.userDefaults = .standard
        self.dateFormatter.dateStyle = .short
        self.dateFormatter.timeStyle = .short
        super.init()
        records = loadPersistedRecords()
        rebuild()
    }

    init(accountUUID: String, accountAddress: String, userDefaults: UserDefaults) {
        self.accountUUID = accountUUID
        self.accountAddress = accountAddress
        self.dateFormatter = DateFormatter()
        self.userDefaults = userDefaults
        self.dateFormatter.dateStyle = .short
        self.dateFormatter.timeStyle = .short
        super.init()
        records = loadPersistedRecords()
        rebuild()
    }

    func show(records: [SIPMessageRecord]) {
        self.records = mergedRecords(records.filter { $0.accountUUID == accountUUID } + loadPersistedRecords())
        persistRecords()
        rebuild()
    }

    func append(_ record: SIPMessageRecord) {
        guard record.accountUUID == accountUUID else { return }
        records = mergedRecords(records + [record])
        selectedConversationId = record.conversationId
        persistRecords()
        rebuild()
    }

    func selectConversation(id: String) {
        selectedConversationId = id
        rebuildMessages()
    }

    func makeOutgoingRecord(to recipients: [String], body: String, date: Date = Date()) -> SIPMessageRecord? {
        let content = SIPMessageContent(body: body)
        guard !recipients.isEmpty, !content.isEmpty else { return nil }
        return SIPMessageRecord.outgoing(
            accountUUID: accountUUID,
            sender: accountAddress,
            recipients: recipients,
            content: content,
            date: date
        )
    }

    @objc(beginOutgoingMessageTo:body:)
    func beginOutgoingMessage(to destination: String, body: String) -> String {
        let trimmedDestination = destination.trimmed
        guard let record = makeOutgoingRecord(
            to: [trimmedDestination],
            body: body.trimmed,
            date: Date()
        )?.updatingDeliveryState(.sending) else {
            return ""
        }
        append(record)
        return record.identifier
    }

    @objc(receiveIncomingMessageFrom:to:body:date:)
    func receiveIncomingMessage(from sender: String, to recipient: String, body: String, date: Date) {
        let content = SIPMessageContent(body: body.trimmed)
        guard !content.isEmpty else { return }
        append(
            SIPMessageRecord.incoming(
                accountUUID: accountUUID,
                sender: sender.trimmed,
                recipient: recipient.trimmed,
                content: content,
                date: date
            )
        )
    }

    @objc(markMessageWithIdentifierSent:)
    func markMessageWithIdentifierSent(_ identifier: String) {
        updateMessage(identifier: identifier, deliveryState: .sent)
    }

    @objc(markMessageWithIdentifier:failedWithReason:)
    func markMessage(withIdentifier identifier: String, failedWithReason reason: String) {
        updateMessage(identifier: identifier, deliveryState: .failed(reason.trimmed))
    }

    private func rebuild() {
        conversations = records
            .latestRecordsByConversation()
            .sorted { $0.date > $1.date }
            .map { record in
                SoftphoneMessageConversationRowModel(
                    id: record.conversationId,
                    title: title(for: record),
                    preview: record.content.body,
                    date: dateFormatter.string(from: record.date),
                    address: address(for: record)
                )
            }

        if selectedConversationId == nil {
            selectedConversationId = conversations.first?.id
        }
        rebuildMessages()
    }

    private func rebuildMessages() {
        guard let selectedConversationId else {
            messages = []
            return
        }
        messages = records
            .filter { $0.conversationId == selectedConversationId }
            .sorted { $0.date < $1.date }
            .map { record in
                SoftphoneMessageBubbleModel(
                    id: record.identifier,
                    senderTitle: senderTitle(for: record),
                    body: record.content.body,
                    date: dateFormatter.string(from: record.date),
                    isOutgoing: record.direction == .outgoing,
                    deliveryState: record.deliveryState.title
                )
            }
    }

    private func title(for record: SIPMessageRecord) -> String {
        switch record.direction {
        case .incoming:
            return record.sender.ak_prettyFormattedPhoneNumber
        case .outgoing:
            return record.recipients.map(\.ak_prettyFormattedPhoneNumber).joined(separator: ", ")
        }
    }

    private func senderTitle(for record: SIPMessageRecord) -> String {
        switch record.direction {
        case .incoming:
            return record.sender.ak_prettyFormattedPhoneNumber
        case .outgoing:
            return "You"
        }
    }

    private func address(for record: SIPMessageRecord) -> String {
        switch record.direction {
        case .incoming:
            return record.sender
        case .outgoing:
            return record.recipients.first ?? ""
        }
    }

    private func updateMessage(identifier: String, deliveryState: SIPMessageDeliveryState) {
        guard let index = records.firstIndex(where: { $0.identifier == identifier }) else { return }
        records[index] = records[index].updatingDeliveryState(deliveryState)
        persistRecords()
        rebuild()
    }

    private func mergedRecords(_ candidates: [SIPMessageRecord]) -> [SIPMessageRecord] {
        let byIdentifier = Dictionary(candidates.map { ($0.identifier, $0) }, uniquingKeysWith: { _, newest in newest })
        return byIdentifier.values.sorted { lhs, rhs in
            if lhs.date == rhs.date {
                return lhs.identifier < rhs.identifier
            }
            return lhs.date < rhs.date
        }
    }

    private func loadPersistedRecords() -> [SIPMessageRecord] {
        guard let data = userDefaults.data(forKey: storageKey) else {
            return []
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let persisted = (try? decoder.decode([PersistedRecord].self, from: data)) ?? []
        return persisted.compactMap(\.record)
    }

    private func persistRecords() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let persisted = records.map(PersistedRecord.init)
        guard let data = try? encoder.encode(persisted) else { return }
        userDefaults.set(data, forKey: storageKey)
    }

    private var storageKey: String {
        "SoftphoneMessages.\(accountUUID)"
    }
}

private extension Array where Element == SIPMessageRecord {
    func latestRecordsByConversation() -> [SIPMessageRecord] {
        return Dictionary(grouping: self, by: \.conversationId)
            .compactMap { $0.value.max { $0.date < $1.date } }
    }
}

private extension SIPMessageDeliveryState {
    var title: String {
        switch self {
        case .received:
            return "Received"
        case .pending:
            return "Pending"
        case .sending:
            return "Sending"
        case .sent:
            return "Sent"
        case let .failed(reason):
            return reason.isEmpty ? "Failed" : "Failed: \(reason)"
        }
    }
}

private extension SoftphoneMessageStore {
    struct PersistedRecord: Codable {
        let identifier: String
        let accountUUID: String
        let sender: String
        let recipients: [String]
        let body: String
        let contentType: String
        let date: Date
        let direction: String
        let deliveryState: String
        let failureReason: String
        let transportIdentifier: String?

        init(_ record: SIPMessageRecord) {
            identifier = record.identifier
            accountUUID = record.accountUUID
            sender = record.sender
            recipients = record.recipients
            body = record.content.body
            contentType = record.content.contentType
            date = record.date
            direction = record.direction.rawValue
            transportIdentifier = record.transportIdentifier
            switch record.deliveryState {
            case .received:
                deliveryState = "received"
                failureReason = ""
            case .pending:
                deliveryState = "pending"
                failureReason = ""
            case .sending:
                deliveryState = "sending"
                failureReason = ""
            case .sent:
                deliveryState = "sent"
                failureReason = ""
            case .failed(let reason):
                deliveryState = "failed"
                failureReason = reason
            }
        }

        var record: SIPMessageRecord? {
            guard let direction = SIPMessageDirection(rawValue: direction) else {
                return nil
            }
            return SIPMessageRecord(
                identifier: identifier,
                accountUUID: accountUUID,
                sender: sender,
                recipients: recipients,
                content: SIPMessageContent(body: body, contentType: contentType),
                date: date,
                direction: direction,
                deliveryState: decodedDeliveryState,
                transportIdentifier: transportIdentifier
            )
        }

        private var decodedDeliveryState: SIPMessageDeliveryState {
            switch deliveryState {
            case "received":
                return .received
            case "sending":
                return .sending
            case "sent":
                return .sent
            case "failed":
                return .failed(failureReason)
            default:
                return .pending
            }
        }
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
