//
//  SoftphoneCallHistoryStore.swift
//  Telephone
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

import Foundation

struct SoftphoneCallHistoryRowModel: Equatable, Identifiable {
    let id: String
    let title: String
    let address: String
    let date: String
    let duration: String
    let isIncoming: Bool
    let isMissed: Bool

    var detail: String {
        let parts = [address, date, duration].filter { !$0.isEmpty }
        return parts.joined(separator: " - ")
    }

    var directionTitle: String {
        if isMissed {
            return "Missed"
        }
        return isIncoming ? "Inbound" : "Outbound"
    }

    var symbolName: String {
        if isMissed {
            return "phone.down.fill"
        }
        return isIncoming ? "phone.arrow.down.left.fill" : "phone.arrow.up.right.fill"
    }
}

enum SoftphoneCallHistoryFilter: String, CaseIterable, Identifiable {
    case all
    case inbound
    case outbound

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "All"
        case .inbound:
            return "Inbound"
        case .outbound:
            return "Outbound"
        }
    }
}

@MainActor
@objc
final class SoftphoneCallHistoryStore: NSObject, ObservableObject {
    @Published private(set) var rows: [SoftphoneCallHistoryRowModel] = []

    @objc override init() {
        super.init()
    }

    func rows(matching filter: SoftphoneCallHistoryFilter) -> [SoftphoneCallHistoryRowModel] {
        switch filter {
        case .all:
            return rows
        case .inbound:
            return rows.filter(\.isIncoming)
        case .outbound:
            return rows.filter { !$0.isIncoming }
        }
    }
}

extension SoftphoneCallHistoryStore: CallHistoryView {
    func show(_ records: [PresentationCallHistoryRecord]) {
        rows = records.map(SoftphoneCallHistoryRowModel.init)
    }
}

private extension SoftphoneCallHistoryRowModel {
    init(record: PresentationCallHistoryRecord) {
        self.init(
            id: record.identifier,
            title: record.contact.title,
            address: record.contact.address,
            date: record.date,
            duration: record.duration,
            isIncoming: record.isIncoming,
            isMissed: record.isMissed
        )
    }
}
