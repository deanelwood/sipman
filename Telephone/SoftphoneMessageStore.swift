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
}

struct SoftphoneMessageBubbleModel: Equatable, Identifiable {
    let id: String
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
    private var records: [SIPMessageRecord] = []

    @objc init(accountUUID: String, accountAddress: String) {
        self.accountUUID = accountUUID
        self.accountAddress = accountAddress
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateStyle = .short
        self.dateFormatter.timeStyle = .short
        super.init()
    }

    func show(records: [SIPMessageRecord]) {
        self.records = records.filter { $0.accountUUID == accountUUID }
        rebuild()
    }

    func append(_ record: SIPMessageRecord) {
        guard record.accountUUID == accountUUID else { return }
        records.append(record)
        selectedConversationId = record.conversationId
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

    private func rebuild() {
        conversations = records
            .latestRecordsByConversation()
            .sorted { $0.date > $1.date }
            .map { record in
                SoftphoneMessageConversationRowModel(
                    id: record.conversationId,
                    title: title(for: record),
                    preview: record.content.body,
                    date: dateFormatter.string(from: record.date)
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
