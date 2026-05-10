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

struct SoftphoneDiagnosticsSnapshot: Equatable {
    let accountUUID: String
    let domain: String
    let sipAddress: String
    let registrationState: SoftphoneRegistrationState
    let transport: String
    let port: String
    let lastRegistration: String
}

@MainActor
@objc
final class SoftphoneDiagnosticsStore: NSObject, ObservableObject {
    @Published private(set) var snapshot: SoftphoneDiagnosticsSnapshot

    @objc init(accountUUID: String, domain: String, sipAddress: String) {
        self.snapshot = SoftphoneDiagnosticsSnapshot(
            accountUUID: accountUUID,
            domain: domain,
            sipAddress: sipAddress,
            registrationState: .offline,
            transport: "Auto",
            port: "Default",
            lastRegistration: "--"
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
            lastRegistration: snapshot.lastRegistration
        )
    }

    private func update(registrationState: SoftphoneRegistrationState, lastRegistration: String) {
        snapshot = SoftphoneDiagnosticsSnapshot(
            accountUUID: snapshot.accountUUID,
            domain: snapshot.domain,
            sipAddress: snapshot.sipAddress,
            registrationState: registrationState,
            transport: snapshot.transport,
            port: snapshot.port,
            lastRegistration: lastRegistration
        )
    }
}
