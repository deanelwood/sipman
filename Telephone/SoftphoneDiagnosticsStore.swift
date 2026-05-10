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

struct SoftphoneDiagnosticsSnapshot: Equatable {
    let accountUUID: String
    let domain: String
    let sipAddress: String
    let registrationState: SoftphoneRegistrationState
    let transport: String
    let port: String
    let lastRegistration: String
    let activeCall: SoftphoneLiveCallDiagnosticsModel?
}

@MainActor
@objc
final class SoftphoneDiagnosticsStore: NSObject, ObservableObject {
    @Published private(set) var snapshot: SoftphoneDiagnosticsSnapshot

    private let callStatsStore = CallStatsStore()

    @objc init(accountUUID: String, domain: String, sipAddress: String) {
        self.snapshot = SoftphoneDiagnosticsSnapshot(
            accountUUID: accountUUID,
            domain: domain,
            sipAddress: sipAddress,
            registrationState: .offline,
            transport: "Auto",
            port: "Default",
            lastRegistration: "--",
            activeCall: nil
        )
        super.init()
    }

    @objc func markRegistered() {
        update(registrationState: .registered, lastRegistration: DateFormatter.localizedString(
            from: Date(),
            dateStyle: .none,
            timeStyle: .medium
        ))
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
            registrationState: snapshot.registrationState,
            transport: transport,
            port: port,
            lastRegistration: snapshot.lastRegistration,
            activeCall: snapshot.activeCall
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

    private func update(registrationState: SoftphoneRegistrationState, lastRegistration: String) {
        snapshot = SoftphoneDiagnosticsSnapshot(
            accountUUID: snapshot.accountUUID,
            domain: snapshot.domain,
            sipAddress: snapshot.sipAddress,
            registrationState: registrationState,
            transport: snapshot.transport,
            port: snapshot.port,
            lastRegistration: lastRegistration,
            activeCall: snapshot.activeCall
        )
    }

    private func update(activeCall: SoftphoneLiveCallDiagnosticsModel?) {
        snapshot = SoftphoneDiagnosticsSnapshot(
            accountUUID: snapshot.accountUUID,
            domain: snapshot.domain,
            sipAddress: snapshot.sipAddress,
            registrationState: snapshot.registrationState,
            transport: snapshot.transport,
            port: snapshot.port,
            lastRegistration: snapshot.lastRegistration,
            activeCall: activeCall
        )
    }

    private static let sampleTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter
    }()
}
