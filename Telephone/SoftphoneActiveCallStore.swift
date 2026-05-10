//
//  SoftphoneActiveCallStore.swift
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
import UseCases

struct SoftphoneActiveCallModel: Equatable, Identifiable {
    let id: String
    let remoteParty: String
    let status: String
    let duration: String
    let isMuted: Bool
    let isOnHold: Bool
    let quality: CallStatsQuality
    let statsRows: [SoftphoneCallStatsRowModel]
}

struct SoftphoneCallStatsRowModel: Equatable, Identifiable {
    let metric: String
    let live: String
    let peak: String

    var id: String { metric }
}

@MainActor
@objc
final class SoftphoneActiveCallStore: NSObject, ObservableObject {
    @Published private(set) var calls: [SoftphoneActiveCallModel] = []

    private let callStatsStore = CallStatsStore()

    var primaryCall: SoftphoneActiveCallModel? {
        calls.first
    }

    @objc func upsertCall(
        identifier: String,
        remoteParty: String,
        status: String,
        duration: String,
        isMuted: Bool,
        isOnHold: Bool,
        statsSnapshot: CallStatsSnapshot?
    ) {
        let statsSnapshot = collatedStatsSnapshot(from: statsSnapshot, identifier: identifier)
        let model = SoftphoneActiveCallModel(
            id: identifier,
            remoteParty: remoteParty.isEmpty ? "Unknown caller" : remoteParty.ak_prettyFormattedPhoneNumber,
            status: status.isEmpty ? "Connecting" : status,
            duration: duration,
            isMuted: isMuted,
            isOnHold: isOnHold,
            quality: statsSnapshot?.quality ?? .waiting,
            statsRows: statsSnapshot?.rows.map(SoftphoneCallStatsRowModel.init) ?? []
        )

        if let existingIndex = calls.firstIndex(where: { $0.id == identifier }) {
            calls[existingIndex] = model
        } else {
            calls.insert(model, at: 0)
        }
    }

    @objc func removeCall(identifier: String) {
        calls.removeAll { $0.id == identifier }
        callStatsStore.remove(callIdentifier: identifier)
    }

    private func collatedStatsSnapshot(from snapshot: CallStatsSnapshot?, identifier: String) -> CallStatsSnapshot? {
        guard let snapshot else { return nil }

        callStatsStore.update(snapshot, callIdentifier: identifier)
        return callStatsStore.snapshot(callIdentifier: identifier)
    }
}

private extension SoftphoneCallStatsRowModel {
    init(row: CallStatsRow) {
        self.init(metric: row.metric, live: row.live, peak: row.peak ?? "")
    }
}
