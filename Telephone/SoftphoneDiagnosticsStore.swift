//
//  SoftphoneDiagnosticsStore.swift
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

struct SoftphoneLiveCallDiagnosticsModel: Equatable {
    let id: String
    let remoteParty: String
    let status: String
    let duration: String
    let quality: CallStatsQuality
    let sampledAt: String
    let statsRows: [SoftphoneCallStatsRowModel]
}

struct SoftphoneSIPLogEntryModel: Equatable, Identifiable {
    let id: UUID
    let recordedAt: Date
    let timestamp: String
    let level: Int
    let message: String
}

struct SoftphoneSIPPingResultModel: Equatable {
    let target: String
    let transport: String
    let status: String
    let summary: String
    let detail: String
    let rawResponse: String
    let elapsed: String

    init(dictionary: [String: Any]) {
        target = dictionary["target"] as? String ?? ""
        transport = dictionary["transport"] as? String ?? ""
        status = dictionary["status"] as? String ?? "Unknown"
        summary = dictionary["summary"] as? String ?? "No result"
        detail = dictionary["detail"] as? String ?? ""
        rawResponse = dictionary["rawResponse"] as? String ?? ""
        if let elapsedMilliseconds = dictionary["elapsedMilliseconds"] as? NSNumber {
            elapsed = String(format: "%.0f ms", elapsedMilliseconds.doubleValue)
        } else {
            elapsed = "--"
        }
    }
}

struct SoftphoneServerAddress: Equatable {
    let host: String
    let port: Int

    init(host: String, port: Int) {
        self.host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        self.port = (1...65535).contains(port) ? port : 0
    }

    init(_ stringValue: String) {
        let serviceAddress = ServiceAddress(stringValue.trimmingCharacters(in: .whitespacesAndNewlines))
        host = serviceAddress.host.trimmingCharacters(in: .whitespacesAndNewlines)
        port = Int(serviceAddress.port) ?? 0
    }

    var displayValue: String {
        guard !host.isEmpty else { return "" }
        guard port > 0 else { return ServiceAddress(host: host).stringValue }
        return ServiceAddress(host: host, port: "\(port)").stringValue
    }
}

struct SoftphoneDiagnosticsSnapshot: Equatable {
    let accountUUID: String
    let domain: String
    let sipAddress: String
    let username: String
    let passwordStatus: String
    let registrationState: SoftphoneRegistrationState
    let transport: String
    let port: String
    let stunServerAddress: String
    let turnServerAddress: String
    let usesICE: Bool
    let lastRegistration: String
    let activeCall: SoftphoneLiveCallDiagnosticsModel?
    let sipLogEntries: [SoftphoneSIPLogEntryModel]
}

@MainActor
@objc
final class SoftphoneDiagnosticsStore: NSObject, ObservableObject {
    @Published private(set) var snapshot: SoftphoneDiagnosticsSnapshot

    static let sipLogNotificationName = Notification.Name("SoftphoneSIPLogLineNotification")

    private enum SIPLogNotificationUserInfoKey {
        static let level = "level"
        static let message = "message"
    }

    private let callStatsStore = CallStatsStore()

    @objc init(
        accountUUID: String,
        domain: String,
        sipAddress: String,
        username: String,
        passwordStatus: String,
        stunServerAddress: String,
        turnServerAddress: String,
        usesICE: Bool
    ) {
        self.snapshot = SoftphoneDiagnosticsSnapshot(
            accountUUID: accountUUID,
            domain: domain,
            sipAddress: sipAddress,
            username: username,
            passwordStatus: passwordStatus,
            registrationState: .offline,
            transport: "Auto",
            port: "Default",
            stunServerAddress: stunServerAddress,
            turnServerAddress: turnServerAddress,
            usesICE: usesICE,
            lastRegistration: "--",
            activeCall: nil,
            sipLogEntries: []
        )
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSIPLogNotification(_:)),
            name: Self.sipLogNotificationName,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc func markRegistered() {
        update(registrationState: .registered, lastRegistration: DateFormatter.localizedString(
            from: Date(),
            dateStyle: .none,
            timeStyle: .medium
        ))
    }

    @objc func markRegistering() {
        update(registrationState: .registering, lastRegistration: snapshot.lastRegistration)
    }

    @objc func markOffline() {
        update(registrationState: .offline, lastRegistration: snapshot.lastRegistration)
    }

    @objc func markRegistrationFailed() {
        update(registrationState: .failed, lastRegistration: snapshot.lastRegistration)
    }

    @objc func updateTransport(_ transport: String, port: String) {
        snapshot = SoftphoneDiagnosticsSnapshot(
            accountUUID: snapshot.accountUUID,
            domain: snapshot.domain,
            sipAddress: snapshot.sipAddress,
            username: snapshot.username,
            passwordStatus: snapshot.passwordStatus,
            registrationState: snapshot.registrationState,
            transport: transport,
            port: port,
            stunServerAddress: snapshot.stunServerAddress,
            turnServerAddress: snapshot.turnServerAddress,
            usesICE: snapshot.usesICE,
            lastRegistration: snapshot.lastRegistration,
            activeCall: snapshot.activeCall,
            sipLogEntries: snapshot.sipLogEntries
        )
    }

    @objc func updateNetworkSettings(stunServerAddress: String, turnServerAddress: String, usesICE: Bool) {
        snapshot = SoftphoneDiagnosticsSnapshot(
            accountUUID: snapshot.accountUUID,
            domain: snapshot.domain,
            sipAddress: snapshot.sipAddress,
            username: snapshot.username,
            passwordStatus: snapshot.passwordStatus,
            registrationState: snapshot.registrationState,
            transport: snapshot.transport,
            port: snapshot.port,
            stunServerAddress: stunServerAddress,
            turnServerAddress: turnServerAddress,
            usesICE: usesICE,
            lastRegistration: snapshot.lastRegistration,
            activeCall: snapshot.activeCall,
            sipLogEntries: snapshot.sipLogEntries
        )
    }

    @objc func updateAccountSettings(domain: String, sipAddress: String, username: String, passwordStatus: String) {
        snapshot = SoftphoneDiagnosticsSnapshot(
            accountUUID: snapshot.accountUUID,
            domain: domain,
            sipAddress: sipAddress,
            username: username,
            passwordStatus: passwordStatus,
            registrationState: snapshot.registrationState,
            transport: snapshot.transport,
            port: snapshot.port,
            stunServerAddress: snapshot.stunServerAddress,
            turnServerAddress: snapshot.turnServerAddress,
            usesICE: snapshot.usesICE,
            lastRegistration: snapshot.lastRegistration,
            activeCall: snapshot.activeCall,
            sipLogEntries: snapshot.sipLogEntries
        )
    }

    @objc func updateActiveCall(
        identifier: String,
        remoteParty: String,
        status: String,
        duration: String,
        statsSnapshot: CallStatsSnapshot?
    ) {
        if let statsSnapshot {
            callStatsStore.update(statsSnapshot, callIdentifier: identifier)
        }
        let collatedSnapshot = callStatsStore.snapshot(callIdentifier: identifier) ?? statsSnapshot
        let activeCall = SoftphoneLiveCallDiagnosticsModel(
            id: identifier,
            remoteParty: remoteParty.isEmpty ? "Unknown caller" : remoteParty.ak_prettyFormattedPhoneNumber,
            status: status.isEmpty ? "Connecting" : status,
            duration: duration,
            quality: collatedSnapshot?.quality ?? .waiting,
            sampledAt: collatedSnapshot.map { Self.sampleTimeFormatter.string(from: $0.sampledAt) } ?? "--",
            statsRows: collatedSnapshot?.rows.map {
                SoftphoneCallStatsRowModel(metric: $0.metric, live: $0.live, peak: $0.peak ?? "")
            } ?? []
        )
        update(activeCall: activeCall)
    }

    @objc func removeActiveCall(identifier: String) {
        callStatsStore.remove(callIdentifier: identifier)
        guard snapshot.activeCall?.id == identifier else { return }
        update(activeCall: nil)
    }

    @objc func appendSIPLogLine(_ message: String, level: Int) {
        let trimmedMessage = message.trimmingCharacters(in: .newlines)
        guard !trimmedMessage.isEmpty else { return }

        let entry = SoftphoneSIPLogEntryModel(
            id: UUID(),
            recordedAt: Date(),
            timestamp: Self.logTimeFormatter.string(from: Date()),
            level: level,
            message: trimmedMessage
        )
        var entries = snapshot.sipLogEntries
        entries.append(entry)
        if entries.count > Self.maxSIPLogEntries {
            entries.removeFirst(entries.count - Self.maxSIPLogEntries)
        }
        update(sipLogEntries: entries)
    }

    @objc func clearSIPLog() {
        update(sipLogEntries: [])
    }

    @objc private func handleSIPLogNotification(_ notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let level = userInfo[Self.SIPLogNotificationUserInfoKey.level] as? Int,
            let message = userInfo[Self.SIPLogNotificationUserInfoKey.message] as? String
        else {
            return
        }
        appendSIPLogLine(message, level: level)
    }

    private func update(registrationState: SoftphoneRegistrationState, lastRegistration: String) {
        snapshot = SoftphoneDiagnosticsSnapshot(
            accountUUID: snapshot.accountUUID,
            domain: snapshot.domain,
            sipAddress: snapshot.sipAddress,
            username: snapshot.username,
            passwordStatus: snapshot.passwordStatus,
            registrationState: registrationState,
            transport: snapshot.transport,
            port: snapshot.port,
            stunServerAddress: snapshot.stunServerAddress,
            turnServerAddress: snapshot.turnServerAddress,
            usesICE: snapshot.usesICE,
            lastRegistration: lastRegistration,
            activeCall: snapshot.activeCall,
            sipLogEntries: snapshot.sipLogEntries
        )
    }

    private func update(activeCall: SoftphoneLiveCallDiagnosticsModel?) {
        snapshot = SoftphoneDiagnosticsSnapshot(
            accountUUID: snapshot.accountUUID,
            domain: snapshot.domain,
            sipAddress: snapshot.sipAddress,
            username: snapshot.username,
            passwordStatus: snapshot.passwordStatus,
            registrationState: snapshot.registrationState,
            transport: snapshot.transport,
            port: snapshot.port,
            stunServerAddress: snapshot.stunServerAddress,
            turnServerAddress: snapshot.turnServerAddress,
            usesICE: snapshot.usesICE,
            lastRegistration: snapshot.lastRegistration,
            activeCall: activeCall,
            sipLogEntries: snapshot.sipLogEntries
        )
    }

    private func update(sipLogEntries: [SoftphoneSIPLogEntryModel]) {
        snapshot = SoftphoneDiagnosticsSnapshot(
            accountUUID: snapshot.accountUUID,
            domain: snapshot.domain,
            sipAddress: snapshot.sipAddress,
            username: snapshot.username,
            passwordStatus: snapshot.passwordStatus,
            registrationState: snapshot.registrationState,
            transport: snapshot.transport,
            port: snapshot.port,
            stunServerAddress: snapshot.stunServerAddress,
            turnServerAddress: snapshot.turnServerAddress,
            usesICE: snapshot.usesICE,
            lastRegistration: snapshot.lastRegistration,
            activeCall: snapshot.activeCall,
            sipLogEntries: sipLogEntries
        )
    }

    private static let sampleTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter
    }()

    private static let logTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter
    }()

    private static let maxSIPLogEntries = 500
}

struct SoftphoneSIPFlowDiagramModel: Equatable {
    let title: String
    let subtitle: String
    let lanes: [String]
    let events: [SoftphoneSIPFlowEventModel]

    var textReport: String {
        var lines = [title, subtitle, ""].filter { !$0.isEmpty }
        if events.isEmpty {
            lines.append("No SIP messages found for this call.")
            return lines.joined(separator: "\n")
        }
        lines.append(lanes.joined(separator: " | "))
        lines.append(String(repeating: "-", count: max(24, lanes.joined(separator: " | ").count)))
        lines.append(contentsOf: events.map(\.textReportLine))
        return lines.joined(separator: "\n")
    }
}

struct SoftphoneSIPFlowEventModel: Equatable, Identifiable {
    let id = UUID()
    let timestamp: String
    let caption: String
    let detail: String
    let sourceLaneIndex: Int
    let destinationLaneIndex: Int
    let isRetransmit: Bool

    var textReportLine: String {
        let arrow = sourceLaneIndex < destinationLaneIndex ? "->" : "<-"
        let retransmit = isRetransmit ? " retransmit" : ""
        let detailSuffix = detail.isEmpty ? "" : " [\(detail)]"
        return "\(timestamp) \(arrow) \(caption)\(retransmit)\(detailSuffix)"
    }
}

enum SoftphoneSIPFlowDiagramFactory {
    static func make(
        row: SoftphoneCallHistoryRowModel,
        snapshot: SoftphoneDiagnosticsSnapshot
    ) -> SoftphoneSIPFlowDiagramModel {
        let localLane = localLaneTitle(snapshot: snapshot)
        let proxyLane = snapshot.domain.isEmpty ? "Proxy / registrar" : snapshot.domain
        let remoteLane = row.address.isEmpty ? row.title : row.address
        let lanes = [localLane, proxyLane, remoteLane]
        let parsedEvents = SoftphoneSIPFlowParser.parse(entries: snapshot.sipLogEntries)
        let scopedEvents = scope(parsedEvents, to: row)

        return SoftphoneSIPFlowDiagramModel(
            title: "SIP Flow",
            subtitle: "\(row.directionTitle) call with \(row.title) - \(row.date)",
            lanes: lanes,
            events: markRetransmits(scopedEvents.map { event in
                event.model(usesProxyLane: usesProxyLane(for: event, snapshot: snapshot))
            })
        )
    }

    private static func localLaneTitle(snapshot: SoftphoneDiagnosticsSnapshot) -> String {
        if !snapshot.sipAddress.isEmpty {
            return snapshot.sipAddress
        }
        if !snapshot.username.isEmpty && !snapshot.domain.isEmpty {
            return "\(snapshot.username)@\(snapshot.domain)"
        }
        return "Local"
    }

    private static func scope(_ events: [SoftphoneParsedSIPFlowEvent], to row: SoftphoneCallHistoryRowModel) -> [SoftphoneParsedSIPFlowEvent] {
        let timed = events.filter { event in
            event.recordedAt >= row.occurredAt.addingTimeInterval(-60) &&
                event.recordedAt <= row.occurredAt.addingTimeInterval(callWindowDuration(for: row) + 120)
        }
        let timedAndMatched = timed.filter { $0.matches(row: row) }
        if !timedAndMatched.isEmpty { return timedAndMatched }
        let matched = events.filter { $0.matches(row: row) }
        if !matched.isEmpty { return matched }
        return timed
    }

    private static func callWindowDuration(for row: SoftphoneCallHistoryRowModel) -> TimeInterval {
        let parts = row.duration.split(separator: ":").compactMap { TimeInterval($0) }
        switch parts.count {
        case 2:
            return parts[0] * 60 + parts[1]
        case 3:
            return parts[0] * 3600 + parts[1] * 60 + parts[2]
        default:
            return 600
        }
    }

    private static func usesProxyLane(for event: SoftphoneParsedSIPFlowEvent, snapshot: SoftphoneDiagnosticsSnapshot) -> Bool {
        event.method == "REGISTER" ||
            (!snapshot.domain.isEmpty && event.searchText.localizedCaseInsensitiveContains(snapshot.domain))
    }

    private static func markRetransmits(_ events: [SoftphoneSIPFlowEventModel]) -> [SoftphoneSIPFlowEventModel] {
        var seenKeys = Set<String>()
        return events.map { event in
            let key = "\(event.sourceLaneIndex)|\(event.destinationLaneIndex)|\(event.caption)|\(event.detail)"
            let isRetransmit = seenKeys.contains(key)
            seenKeys.insert(key)
            return SoftphoneSIPFlowEventModel(
                timestamp: event.timestamp,
                caption: event.caption,
                detail: event.detail,
                sourceLaneIndex: event.sourceLaneIndex,
                destinationLaneIndex: event.destinationLaneIndex,
                isRetransmit: isRetransmit
            )
        }
    }
}

private struct SoftphoneParsedSIPFlowEvent: Equatable {
    enum Direction {
        case outbound
        case inbound
    }

    let recordedAt: Date
    let timestamp: String
    let direction: Direction
    let method: String
    let caption: String
    let detail: String
    let searchText: String

    func matches(row: SoftphoneCallHistoryRowModel) -> Bool {
        let rowText = [row.title, row.address, row.label].joined(separator: " ").lowercased()
        let normalizedRowDigits = rowText.filter(\.isNumber)
        let normalizedSearchDigits = searchText.filter(\.isNumber)
        if !normalizedRowDigits.isEmpty && normalizedSearchDigits.contains(normalizedRowDigits) {
            return true
        }
        return rowText
            .split(separator: " ")
            .filter { $0.count >= 3 }
            .contains { searchText.localizedCaseInsensitiveContains($0) }
    }

    func model(usesProxyLane: Bool) -> SoftphoneSIPFlowEventModel {
        let peerLaneIndex = usesProxyLane ? 1 : 2
        switch direction {
        case .outbound:
            return SoftphoneSIPFlowEventModel(
                timestamp: timestamp,
                caption: caption,
                detail: detail,
                sourceLaneIndex: 0,
                destinationLaneIndex: peerLaneIndex,
                isRetransmit: false
            )
        case .inbound:
            return SoftphoneSIPFlowEventModel(
                timestamp: timestamp,
                caption: caption,
                detail: detail,
                sourceLaneIndex: peerLaneIndex,
                destinationLaneIndex: 0,
                isRetransmit: false
            )
        }
    }
}

private enum SoftphoneSIPFlowParser {
    static func parse(entries: [SoftphoneSIPLogEntryModel]) -> [SoftphoneParsedSIPFlowEvent] {
        entries.compactMap(parse)
    }

    private static func parse(entry: SoftphoneSIPLogEntryModel) -> SoftphoneParsedSIPFlowEvent? {
        let direction: SoftphoneParsedSIPFlowEvent.Direction
        let message: String
        if entry.message.hasPrefix(">>> ") {
            direction = .outbound
            message = String(entry.message.dropFirst(4))
        } else if entry.message.hasPrefix("<<< ") {
            direction = .inbound
            message = String(entry.message.dropFirst(4))
        } else {
            return nil
        }

        let lines = message
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard let firstLine = lines.first else { return nil }

        let headers = headers(from: lines.dropFirst())
        let cseq = headers["cseq"] ?? ""
        let cseqMethod = cseq.split(separator: " ").last.map(String.init)?.uppercased() ?? ""
        let callID = headers["call-id"] ?? headers["i"] ?? ""
        let branch = branchValue(from: headers["via"] ?? headers["v"] ?? "")
        let isResponse = firstLine.uppercased().hasPrefix("SIP/2.0")
        let method = isResponse ? cseqMethod : firstLine.split(separator: " ").first.map(String.init)?.uppercased() ?? ""
        guard !method.isEmpty else { return nil }

        let caption: String
        if isResponse {
            let parts = firstLine.split(separator: " ", maxSplits: 2).map(String.init)
            let code = parts.count > 1 ? parts[1] : "Response"
            let reason = parts.count > 2 ? " \(parts[2])" : ""
            caption = "\(code)\(reason) · \(method)"
        } else {
            caption = method
        }

        let detail = [
            cseq.isEmpty ? nil : "CSeq \(cseq)",
            callID.isEmpty ? nil : "Call-ID \(short(callID))",
            branch.isEmpty ? nil : "branch \(short(branch))"
        ].compactMap { $0 }.joined(separator: " · ")

        return SoftphoneParsedSIPFlowEvent(
            recordedAt: entry.recordedAt,
            timestamp: entry.timestamp,
            direction: direction,
            method: method,
            caption: caption,
            detail: detail,
            searchText: message.lowercased()
        )
    }

    private static func headers(from lines: ArraySlice<String>) -> [String: String] {
        lines.reduce(into: [:]) { result, line in
            guard let separator = line.firstIndex(of: ":") else { return }
            let name = String(line[..<separator]).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let value = String(line[line.index(after: separator)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, !value.isEmpty else { return }
            result[name] = value
        }
    }

    private static func branchValue(from via: String) -> String {
        guard let range = via.range(of: "branch=", options: .caseInsensitive) else { return "" }
        let suffix = via[range.upperBound...]
        return String(suffix.prefix { !$0.isWhitespace && $0 != ";" })
    }

    private static func short(_ value: String) -> String {
        guard value.count > 16 else { return value }
        return "\(value.prefix(8))...\(value.suffix(4))"
    }
}
