//
//  StoreEventTargetSpy.swift
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

@MainActor
public final class StoreEventTargetSpy {
    public var didPurchaseCallback: () -> Void = {}
    public var didFailPurchasingCallback: () -> Void = {}
    public var didRestorePurchasesCallback: () -> Void = {}
    public var didFailRestoringPurchasesCallback: () -> Void = {}

    public private(set) var didCallDidStartPurchasing = false
    public private(set) var invokedIdentifier = ""

    public private(set) var didCallDidPurchase = false
    public private(set) var didCallDidFailPurchasing = false
    public private(set) var didCallDidCancelPurchasing = false

    public private(set) var didCallDidRestore = false
    public private(set) var didCallDidFailRestoring = false
    public private(set) var didCallDidCancelRestoring = false

    public private(set) var invokedError = ""

    public init() {}
}

extension StoreEventTargetSpy: StoreEventTarget {
    public func didStartPurchasingProduct(withIdentifier identifier: String) {
        didCallDidStartPurchasing = true
        invokedIdentifier = identifier
    }

    public func didPurchase() {
        didCallDidPurchase = true
        didPurchaseCallback()
    }

    public func didFailPurchasing(error: String) {
        didCallDidFailPurchasing = true
        invokedError = error
        didFailPurchasingCallback()
    }

    public func didCancelPurchasing() {
        didCallDidCancelPurchasing = true
    }

    public func didRestorePurchases() {
        didCallDidRestore = true
        didRestorePurchasesCallback()
    }

    public func didFailRestoringPurchases(error: String) {
        didCallDidFailRestoring = true
        invokedError = error
        didFailRestoringPurchasesCallback()
    }

    public func didCancelRestoringPurchases() {
        didCallDidCancelRestoring = true
    }
}
