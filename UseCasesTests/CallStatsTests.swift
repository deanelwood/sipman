//
//  CallStatsTests.swift
//  UseCasesTests
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

import UseCases
import XCTest

final class CallStatsTests: XCTestCase {
    func testSnapshotCanFindRowsByMetric() {
        let row = CallStatsRow(metric: "RTT", live: "149.0 ms", numericLiveValue: 149)
        let sut = CallStatsSnapshot(rows: [row], quality: .good)

        XCTAssertEqual(sut.row(metric: "RTT"), row)
    }

    func testImmediateQualityIsWaitingWhenNoSampleIsAvailable() {
        XCTAssertEqual(CallStatsQualityEvaluator.immediateQuality(for: nil), .waiting)
    }

    func testImmediateQualityIsGoodBelowFairThresholds() {
        XCTAssertEqual(
            CallStatsQualityEvaluator.immediateQuality(for: sample(rtt: 149, jbuf: 119, jitter: 24)),
            .good
        )
    }

    func testImmediateQualityIsFairAtFairThresholds() {
        XCTAssertEqual(
            CallStatsQualityEvaluator.immediateQuality(for: sample(rtt: 150, jbuf: 119, jitter: 24)),
            .fair
        )
        XCTAssertEqual(
            CallStatsQualityEvaluator.immediateQuality(for: sample(rtt: 149, jbuf: 120, jitter: 24)),
            .fair
        )
        XCTAssertEqual(
            CallStatsQualityEvaluator.immediateQuality(for: sample(rtt: 149, jbuf: 119, jitter: 25)),
            .fair
        )
    }

    func testImmediateQualityIsPoorAtPoorThresholds() {
        XCTAssertEqual(
            CallStatsQualityEvaluator.immediateQuality(for: sample(rtt: 300, jbuf: 119, jitter: 24)),
            .poor
        )
        XCTAssertEqual(
            CallStatsQualityEvaluator.immediateQuality(for: sample(rtt: 149, jbuf: 250, jitter: 24)),
            .poor
        )
        XCTAssertEqual(
            CallStatsQualityEvaluator.immediateQuality(for: sample(rtt: 149, jbuf: 119, jitter: 60)),
            .poor
        )
    }

    func testStoreUpdatesAndRemovesSnapshotsByCallIdentifier() {
        let sut = CallStatsStore()
        let snapshot = CallStatsSnapshot(rows: [CallStatsRow(metric: "Codec", live: "opus / 48000 Hz")], quality: .good)

        sut.update(snapshot, callIdentifier: "call-1")

        XCTAssertEqual(sut.snapshot(callIdentifier: "call-1")?.row(metric: "Codec")?.live, "opus / 48000 Hz")

        sut.remove(callIdentifier: "call-1")

        XCTAssertNil(sut.snapshot(callIdentifier: "call-1"))
    }

    func testStoreMaintainsPeakValuesForNumericRows() {
        let sut = CallStatsStore()

        sut.update(
            CallStatsSnapshot(rows: [CallStatsRow(metric: "RTT", live: "316.0 ms", numericLiveValue: 316)], quality: .poor),
            callIdentifier: "call-1"
        )
        sut.update(
            CallStatsSnapshot(rows: [CallStatsRow(metric: "RTT", live: "100.0 ms", numericLiveValue: 100)], quality: .good),
            callIdentifier: "call-1"
        )

        XCTAssertEqual(sut.snapshot(callIdentifier: "call-1")?.row(metric: "RTT")?.peak, "316.0 ms")
    }

    func testQualityEvaluatorPromotesRepeatedJitterBufferDeltasWithinFiveSeconds() {
        let sut = CallStatsQualityEvaluator()
        let date = Date(timeIntervalSince1970: 0)

        XCTAssertEqual(sut.quality(for: sample(lost: 0, discard: 0, empty: 0), sampledAt: date), .good)
        XCTAssertEqual(sut.quality(for: sample(lost: 1, discard: 0, empty: 0), sampledAt: date.addingTimeInterval(1)), .good)
        XCTAssertEqual(sut.quality(for: sample(lost: 2, discard: 0, empty: 0), sampledAt: date.addingTimeInterval(2)), .fair)
    }

    func testQualityEvaluatorPromotesRepeatedLargeJitterBufferDeltasToPoor() {
        let sut = CallStatsQualityEvaluator()
        let date = Date(timeIntervalSince1970: 0)

        _ = sut.quality(for: sample(lost: 0, discard: 0, empty: 0), sampledAt: date)
        _ = sut.quality(for: sample(lost: 3, discard: 0, empty: 0), sampledAt: date.addingTimeInterval(1))

        XCTAssertEqual(sut.quality(for: sample(lost: 6, discard: 0, empty: 0), sampledAt: date.addingTimeInterval(2)), .poor)
    }
}

private func sample(rtt: Double, jbuf: Double, jitter: Double) -> CallStatsSample {
    return CallStatsSample(
        rttMilliseconds: rtt,
        averageJitterBufferDelayMilliseconds: jbuf,
        receiveJitterMilliseconds: jitter,
        jitterBufferLost: 0,
        jitterBufferDiscard: 0,
        jitterBufferEmpty: 0
    )
}

private func sample(lost: Int, discard: Int, empty: Int) -> CallStatsSample {
    return CallStatsSample(
        rttMilliseconds: 0,
        averageJitterBufferDelayMilliseconds: 0,
        receiveJitterMilliseconds: 0,
        jitterBufferLost: lost,
        jitterBufferDiscard: discard,
        jitterBufferEmpty: empty
    )
}
