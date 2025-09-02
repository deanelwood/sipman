//
//  ReceiptValidatingStoreEventTargetTests.swift
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

import XCTest
import UseCases
import UseCasesTestDoubles

@MainActor
final class ReceiptValidatingStoreEventTargetTests: XCTestCase {

    // MARK: - Purchase start

    func testCallsDidStartPurchasingOnDidStartPurchasing() {
        let origin = StoreEventTargetSpy()
        let sut = ReceiptValidatingStoreEventTarget(origin: origin, receipt: InvalidReceipt())
        let identifier = "any"

        sut.didStartPurchasingProduct(withIdentifier: identifier)

        XCTAssertTrue(origin.didCallDidStartPurchasing)
        XCTAssertEqual(origin.invokedIdentifier, identifier)
    }

    // MARK: - Purchase finish

    func testCallsDidPurchaseWhenReceiptIsValidOnDidPurchase() {
        let didCallDidPurchase = expectation(description: "Calls did purchase on origin")
        let origin = StoreEventTargetSpy()
        origin.didPurchaseCallback = didCallDidPurchase.fulfill
        let sut = ReceiptValidatingStoreEventTarget(origin: origin, receipt: ValidReceipt())

        sut.didPurchase()

        wait(for: [didCallDidPurchase], timeout: 1)
    }

    func testCallsDidFailPurchasingWhenReceiptIsNotValidOnDidPurchase() {
        let didCallDidFailPurchasing = expectation(description: "Calls did fail purchasing on origin")
        let origin = StoreEventTargetSpy()
        origin.didFailPurchasingCallback = didCallDidFailPurchasing.fulfill
        let sut = ReceiptValidatingStoreEventTarget(origin: origin, receipt: InvalidReceipt())

        sut.didPurchase()

        wait(for: [didCallDidFailPurchasing], timeout: 1)
        XCTAssertEqual(origin.invokedError, ReceiptValidationResult.receiptIsInvalid.localizedDescription)
    }

    func testCallsDidFailPurchasingWhenThereAreNoActivePurchasesOnDidPurchase() {
        let didCallDidFailPurchasing = expectation(description: "Calls did fail purchasing on origin")
        let origin = StoreEventTargetSpy()
        origin.didFailPurchasingCallback = didCallDidFailPurchasing.fulfill
        let sut = ReceiptValidatingStoreEventTarget(origin: origin, receipt: NoActivePurchasesReceipt())

        sut.didPurchase()

        wait(for: [didCallDidFailPurchasing], timeout: 1)
        XCTAssertEqual(origin.invokedError, ReceiptValidationResult.noActivePurchases.localizedDescription)
    }

    func testCallsDidFailPurchasingOnDidFailPurchasing() {
        let origin = StoreEventTargetSpy()
        let sut = ReceiptValidatingStoreEventTarget(origin: origin, receipt: InvalidReceipt())
        let error = "any"

        sut.didFailPurchasing(error: error)

        XCTAssertTrue(origin.didCallDidFailPurchasing)
        XCTAssertEqual(origin.invokedError, error)
    }

    func testCallsDidCancelPurchasingOnDidCancelPurchasing() {
        let origin = StoreEventTargetSpy()
        let sut = ReceiptValidatingStoreEventTarget(origin: origin, receipt: InvalidReceipt())

        sut.didCancelPurchasing()

        XCTAssertTrue(origin.didCallDidCancelPurchasing)
    }

    // MARK: - Restoration finish

    func testCallsDidRestoreWhenReceiptIsValidOnDidRestore() {
        let didCallDidRestorePurchase = expectation(description: "Calls did restore purchase on origin")
        let origin = StoreEventTargetSpy()
        origin.didRestorePurchasesCallback = didCallDidRestorePurchase.fulfill
        let sut = ReceiptValidatingStoreEventTarget(origin: origin, receipt: ValidReceipt())

        sut.didRestorePurchases()

        wait(for: [didCallDidRestorePurchase], timeout: 1)
    }

    func testCallsDidFailRestoringWhenReceiptIsNotValidOnDidRestore() {
        let didCallDidFailRestoringPurchase = expectation(description: "Calls did fail restoring purchase on origin")
        let origin = StoreEventTargetSpy()
        origin.didFailRestoringPurchasesCallback = didCallDidFailRestoringPurchase.fulfill
        let sut = ReceiptValidatingStoreEventTarget(origin: origin, receipt: InvalidReceipt())

        sut.didRestorePurchases()

        wait(for: [didCallDidFailRestoringPurchase], timeout: 1)
        XCTAssertEqual(origin.invokedError, ReceiptValidationResult.receiptIsInvalid.localizedDescription)
    }

    func testCallsDidFailRestoringWhenThereAreNoActivePurchasesOnDidPurchase() {
        let didCallDidFailRestoringPurchase = expectation(description: "Calls did fail restoring purchase on origin")
        let origin = StoreEventTargetSpy()
        origin.didFailRestoringPurchasesCallback = didCallDidFailRestoringPurchase.fulfill
        let sut = ReceiptValidatingStoreEventTarget(origin: origin, receipt: NoActivePurchasesReceipt())

        sut.didRestorePurchases()

        wait(for: [didCallDidFailRestoringPurchase], timeout: 1)
        XCTAssertEqual(origin.invokedError, ReceiptValidationResult.noActivePurchases.localizedDescription)
    }

    func testCallsDidFailRestoringOnDidFailRestoring() {
        let origin = StoreEventTargetSpy()
        let sut = ReceiptValidatingStoreEventTarget(origin: origin, receipt: InvalidReceipt())
        let error = "any"

        sut.didFailRestoringPurchases(error: error)

        XCTAssertTrue(origin.didCallDidFailRestoring)
        XCTAssertEqual(origin.invokedError, error)
    }

    func testCallsDidCancelRestoringOnDidCancelRestoring() {
        let origin = StoreEventTargetSpy()
        let sut = ReceiptValidatingStoreEventTarget(origin: origin, receipt: InvalidReceipt())

        sut.didCancelRestoringPurchases()

        XCTAssertTrue(origin.didCallDidCancelRestoring)
    }
}
