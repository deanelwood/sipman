//
//  SoftphoneCallHistoryStore.swift
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

struct SoftphoneCallHistoryRowModel: Equatable, Identifiable {
    let id: String
    let title: String
    let address: String
    let occurredAt: Date
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

struct SoftphoneCallHistorySectionModel: Equatable, Identifiable {
    let title: String
    let rows: [SoftphoneCallHistoryRowModel]

    var id: String { title }
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

    func sections(
        matching filter: SoftphoneCallHistoryFilter,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> [SoftphoneCallHistorySectionModel] {
        rows(matching: filter).reduce(into: []) { sections, row in
            let title = sectionTitle(for: row.occurredAt, calendar: calendar, now: now)
            if let lastSection = sections.indices.last, sections[lastSection].title == title {
                sections[lastSection] = SoftphoneCallHistorySectionModel(
                    title: title,
                    rows: sections[lastSection].rows + [row]
                )
            } else {
                sections.append(SoftphoneCallHistorySectionModel(title: title, rows: [row]))
            }
        }
    }

    private func sectionTitle(for date: Date, calendar: Calendar, now: Date) -> String {
        if calendar.isDate(date, inSameDayAs: now) {
            return "Today"
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return "Yesterday"
        }
        if let currentWeek = calendar.dateInterval(of: .weekOfYear, for: now),
           currentWeek.contains(date) {
            return "This week"
        }
        if let currentWeek = calendar.dateInterval(of: .weekOfYear, for: now),
           let previousWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: currentWeek.start),
           let previousWeek = calendar.dateInterval(of: .weekOfYear, for: previousWeekStart),
           previousWeek.contains(date) {
            return "Last week"
        }
        if let currentMonth = calendar.dateInterval(of: .month, for: now),
           currentMonth.contains(date) {
            return "This month"
        }
        if let currentMonth = calendar.dateInterval(of: .month, for: now),
           let previousMonthStart = calendar.date(byAdding: .month, value: -1, to: currentMonth.start),
           let previousMonth = calendar.dateInterval(of: .month, for: previousMonthStart),
           previousMonth.contains(date) {
            return "Last month"
        }
        return Self.monthYearFormatter(calendar: calendar).string(from: date)
    }

    private static func monthYearFormatter(calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? Locale.current
        formatter.dateFormat = "LLLL yyyy"
        return formatter
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
            occurredAt: record.occurredAt,
            date: record.date,
            duration: record.duration,
            isIncoming: record.isIncoming,
            isMissed: record.isMissed
        )
    }
}
