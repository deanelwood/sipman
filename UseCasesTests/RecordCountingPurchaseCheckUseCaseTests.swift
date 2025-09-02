//
//  RecordCountingPurchaseCheckUseCaseTests.swift
//  Telephone
//
//  Copyright © 2008-2016 Alexey Kuznetsov
//  Copyright © 2016-2022 64 Characters
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
import UseCasesTestDoubles
import XCTest

final class RecordCountingPurchaseCheckUseCaseTests: XCTestCase {
    func testCallsDidCheckPurchaseWhenReceiptIsValidOnUpdate() {
        let didCallDidCheckPurchase = expectation(description: "Calls did check purchse on output")
        let output = RecordCountingPurchaseCheckUseCaseOutputSpy(
            didCheckPurchaseCallback: didCallDidCheckPurchase.fulfill, didFailCheckingPurchaseCallback: { _ in }
        )
        let sut = RecordCountingPurchaseCheckUseCase(
            factory: PurchaseCheckUseCaseFactory(receipt: ValidReceipt()), output: output
        )

        sut.update(records: [])

        wait(for: [didCallDidCheckPurchase], timeout: 1)
    }

    func testCallsDidFailCheckingPurchaseWithRecordCountWhenReceiptIsInvalidOnUpdate() {
        let records = makeRecords(count: 5)
        let didCallDidFailCheckingPurchase = expectation(description: "Calls did fail checking purchase on output")
        var invokedCount: Int?
        let output = RecordCountingPurchaseCheckUseCaseOutputSpy(
            didCheckPurchaseCallback: {},
            didFailCheckingPurchaseCallback: { count in
                invokedCount = count
                didCallDidFailCheckingPurchase.fulfill()
            }
        )
        let sut = RecordCountingPurchaseCheckUseCase(
            factory: PurchaseCheckUseCaseFactory(receipt: InvalidReceipt()), output: output
        )

        sut.update(records: records)

        wait(for: [didCallDidFailCheckingPurchase], timeout: 1)
        XCTAssertEqual(invokedCount, records.count)
    }

    func testCallsDidFailCheckingPurchaseWithRecordCountWhenReceiptDoesNotHaveActivePurchasesOnUpdate() {
        let records = makeRecords(count: 6)
        let didCallDidFailCheckingPurchase = expectation(description: "Calls did fail checking purchase on output")
        var invokedCount: Int?
        let output = RecordCountingPurchaseCheckUseCaseOutputSpy(
            didCheckPurchaseCallback: {}, didFailCheckingPurchaseCallback: { count in
                invokedCount = count
                didCallDidFailCheckingPurchase.fulfill()
            }
        )
        let sut = RecordCountingPurchaseCheckUseCase(
            factory: PurchaseCheckUseCaseFactory(receipt: NoActivePurchasesReceipt()), output: output
        )

        sut.update(records: records)

        wait(for: [didCallDidFailCheckingPurchase], timeout: 1)
        XCTAssertEqual(invokedCount, records.count)
    }
}

private func makeRecords(count: Int) -> [CallHistoryRecord] {
    var result: [CallHistoryRecord] = []
    let factory = CallHistoryRecordTestFactory()
    for n in 0..<count {
        result.append(factory.makeRecord(number: n))
    }
    return result
}
