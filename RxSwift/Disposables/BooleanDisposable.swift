//
//  BooleanDisposable.swift
//  RxSwift
//
//  Created by Junior B. on 10/29/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/// Represents a disposable resource that can be checked for disposal status.
public final class BooleanDisposable: Cancelable {
    static var BooleanDisposableTrue: BooleanDisposable!
    private let disposed: AtomicInt
    
    /// Initializes a new instance of the `BooleanDisposable` class
    public init() async {
        self.disposed = await AtomicInt(0)
    }
    
    /// Initializes a new instance of the `BooleanDisposable` class with given value
    public init(isDisposed: Bool) async {
        self.disposed = await AtomicInt(isDisposed ? 1 : 0)
    }
    
    /// - returns: Was resource disposed.
    public func isDisposed() async -> Bool {
        await isFlagSet(self.disposed, 1)
    }
    
    /// Sets the status to disposed, which can be observer through the `isDisposed` property.
    public func dispose() async {
        await fetchOr(self.disposed, 1)
    }
}
