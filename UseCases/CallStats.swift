//
//  CallStats.swift
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

@objc public enum CallStatsQuality: Int, Sendable {
    case waiting
    case good
    case fair
    case poor
}

@objc public protocol CallStatsProviding {
    func callStatsSnapshot() -> CallStatsSnapshot
}

@objcMembers public final class CallStatsRow: NSObject {
    public let metric: String
    public let live: String
    public let numericLiveValue: NSNumber?
    public let peak: String?

    public init(metric: String, live: String, numericLiveValue: NSNumber? = nil) {
        self.metric = metric
        self.live = live
        self.numericLiveValue = numericLiveValue
        self.peak = nil
    }

    public init(metric: String, live: String, numericLiveValue: NSNumber?, peak: String?) {
        self.metric = metric
        self.live = live
        self.numericLiveValue = numericLiveValue
        self.peak = peak
    }
}

@objcMembers public final class CallStatsSample: NSObject {
    public let rttMilliseconds: Double
    public let averageJitterBufferDelayMilliseconds: Double
    public let receiveJitterMilliseconds: Double
    public let jitterBufferLost: Int
    public let jitterBufferDiscard: Int
    public let jitterBufferEmpty: Int

    public init(
        rttMilliseconds: Double,
        averageJitterBufferDelayMilliseconds: Double,
        receiveJitterMilliseconds: Double,
        jitterBufferLost: Int,
        jitterBufferDiscard: Int,
        jitterBufferEmpty: Int
    ) {
        self.rttMilliseconds = rttMilliseconds
        self.averageJitterBufferDelayMilliseconds = averageJitterBufferDelayMilliseconds
        self.receiveJitterMilliseconds = receiveJitterMilliseconds
        self.jitterBufferLost = jitterBufferLost
        self.jitterBufferDiscard = jitterBufferDiscard
        self.jitterBufferEmpty = jitterBufferEmpty
    }
}

@objcMembers public final class CallStatsQualityEvaluator: NSObject {
    private var previousSample: CallStatsSample?
    private var recentEvents: [JitterBufferEvent] = []

    public static func immediateQuality(for sample: CallStatsSample?) -> CallStatsQuality {
        guard let sample else { return .waiting }

        if sample.rttMilliseconds >= 300 ||
            sample.averageJitterBufferDelayMilliseconds >= 250 ||
            sample.receiveJitterMilliseconds >= 60 {
            return .poor
        }
        if sample.rttMilliseconds >= 150 ||
            sample.averageJitterBufferDelayMilliseconds >= 120 ||
            sample.receiveJitterMilliseconds >= 25 {
            return .fair
        }
        return .good
    }

    public func quality(for sample: CallStatsSample?, sampledAt: Date) -> CallStatsQuality {
        let thresholdQuality = Self.immediateQuality(for: sample)
        guard let sample else {
            previousSample = nil
            recentEvents.removeAll()
            return thresholdQuality
        }

        defer { previousSample = sample }
        guard let previousSample else { return thresholdQuality }

        addEventIfNeeded(
            name: "lost",
            delta: sample.jitterBufferLost - previousSample.jitterBufferLost,
            sampledAt: sampledAt,
            poorDeltaThreshold: 3
        )
        addEventIfNeeded(
            name: "discard",
            delta: sample.jitterBufferDiscard - previousSample.jitterBufferDiscard,
            sampledAt: sampledAt,
            poorDeltaThreshold: 3
        )
        addEventIfNeeded(
            name: "empty",
            delta: sample.jitterBufferEmpty - previousSample.jitterBufferEmpty,
            sampledAt: sampledAt,
            poorDeltaThreshold: 2
        )

        recentEvents = recentEvents.filter { sampledAt.timeIntervalSince($0.sampledAt) <= 5 }
        let deltaQuality = recentEventsByName().values.reduce(CallStatsQuality.good) { quality, events in
            guard events.count >= 2 else { return quality }
            return max(quality, events.contains { $0.isPoor } ? .poor : .fair)
        }

        return max(thresholdQuality, deltaQuality)
    }

    private func addEventIfNeeded(
        name: String,
        delta: Int,
        sampledAt: Date,
        poorDeltaThreshold: Int
    ) {
        guard delta > 0 else { return }
        recentEvents.append(
            JitterBufferEvent(name: name, sampledAt: sampledAt, isPoor: delta >= poorDeltaThreshold)
        )
    }

    private func recentEventsByName() -> [String: [JitterBufferEvent]] {
        return Dictionary(grouping: recentEvents, by: \.name)
    }
}

@objcMembers public final class CallStatsSnapshot: NSObject {
    public let sampledAt: Date
    public let rows: [CallStatsRow]
    public let quality: CallStatsQuality
    public let sample: CallStatsSample?

    public init(sampledAt: Date = Date(), rows: [CallStatsRow], quality: CallStatsQuality) {
        self.sampledAt = sampledAt
        self.rows = rows
        self.quality = quality
        self.sample = nil
    }

    public init(sampledAt: Date, rows: [CallStatsRow], quality: CallStatsQuality, sample: CallStatsSample?) {
        self.sampledAt = sampledAt
        self.rows = rows
        self.quality = quality
        self.sample = sample
    }

    public func row(metric: String) -> CallStatsRow? {
        return rows.first { $0.metric == metric }
    }
}

@objcMembers public final class CallStatsStore: NSObject {
    private var snapshots: [String: CallStatsSnapshot] = [:]
    private var peaks: [String: [String: CallStatsPeak]] = [:]
    private var qualityEvaluators: [String: CallStatsQualityEvaluator] = [:]

    public func update(_ snapshot: CallStatsSnapshot, callIdentifier: String) {
        let rows = snapshot.rows.map { row in
            guard let numericLiveValue = row.numericLiveValue else { return row }

            var callPeaks = peaks[callIdentifier] ?? [:]
            let liveValue = numericLiveValue.doubleValue
            let currentPeak = callPeaks[row.metric]
            let peak: CallStatsPeak
            if let currentPeak, currentPeak.value >= liveValue {
                peak = currentPeak
            } else {
                peak = CallStatsPeak(value: liveValue, live: row.live)
                callPeaks[row.metric] = peak
                peaks[callIdentifier] = callPeaks
            }
            return CallStatsRow(metric: row.metric, live: row.live, numericLiveValue: numericLiveValue, peak: peak.live)
        }

        let evaluator = qualityEvaluators[callIdentifier] ?? CallStatsQualityEvaluator()
        qualityEvaluators[callIdentifier] = evaluator
        let quality = snapshot.sample.map {
            evaluator.quality(for: $0, sampledAt: snapshot.sampledAt)
        } ?? snapshot.quality

        snapshots[callIdentifier] = CallStatsSnapshot(
            sampledAt: snapshot.sampledAt,
            rows: rows,
            quality: quality,
            sample: snapshot.sample
        )
    }

    public func snapshot(callIdentifier: String) -> CallStatsSnapshot? {
        return snapshots[callIdentifier]
    }

    public func remove(callIdentifier: String) {
        snapshots[callIdentifier] = nil
        peaks[callIdentifier] = nil
        qualityEvaluators[callIdentifier] = nil
    }
}

private struct JitterBufferEvent {
    let name: String
    let sampledAt: Date
    let isPoor: Bool
}

private struct CallStatsPeak {
    let value: Double
    let live: String
}

private func max(_ lhs: CallStatsQuality, _ rhs: CallStatsQuality) -> CallStatsQuality {
    return lhs.rawValue >= rhs.rawValue ? lhs : rhs
}
