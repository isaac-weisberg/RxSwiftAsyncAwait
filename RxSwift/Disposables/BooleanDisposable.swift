//
//  BooleanDisposable.swift
//  RxSwift
//
//  Created by Junior B. on 10/29/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/// Represents a disposable resource that can be checked for disposal status.
public final class BooleanDisposable: UnsynchronizedCancelable {
    static let BooleanDisposableTrue = BooleanDisposable(isDisposed: true)
    
    private let disposed: NonAtomicInt
    
    /// Initializes a new instance of the `BooleanDisposable` class
    public init() {
        self.disposed = NonAtomicInt(0)
    }
    
    /// Initializes a new instance of the `BooleanDisposable` class with given value
    public init(isDisposed: Bool) {
        self.disposed = NonAtomicInt(isDisposed ? 1 : 0)
    }
    
    /// - returns: Was resource disposed.
    public func isDisposed() -> Bool {
        isFlagSet(self.disposed, 1)
    }
    
    /// Sets the status to disposed, which can be observer through the `isDisposed` property.
    public func dispose() {
        fetchOr(self.disposed, 1)
    }
}
