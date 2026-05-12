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
