//
//  SingleAssignmentDisposable.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/15/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/**
 Represents a disposable resource which only allows a single assignment of its underlying disposable resource.

 If an underlying disposable resource has already been set, future attempts to set the underlying disposable resource will throw an exception.
 */

final class SimpleDisposableBox: @unchecked Sendable {
    var disposed: Bool = false
    var disposable: Disposable?
}

public final class UnsynchronizedSingleAssignmentDisposable {
    private struct DisposeState: OptionSet {
        let rawValue: Int32

        static let disposed = DisposeState(rawValue: 1 << 0)
        static let disposableSet = DisposeState(rawValue: 1 << 1)
    }

    // state
    private let state: NonAtomicInt
    var disposable = nil as AsynchronousDisposable?

    /// - returns: A value that indicates whether the object is disposed.
    public func isDisposed() -> Bool {
        isFlagSet(state, DisposeState.disposed.rawValue)
    }

    /// Initializes a new instance of the `SingleAssignmentDisposable`.
    public init() {
        state = NonAtomicInt(0)
        SynchronousDisposeBaseInit()
    }

    deinit {
        SynchronousDisposeBaseDeinit()
    }
    
    public func setDisposableUnchecked(_ disposable: AsynchronousDisposable) -> Bool {
        self.disposable = disposable
        
        let previousState = fetchOr(state, DisposeState.disposableSet.rawValue)

        if (previousState & DisposeState.disposableSet.rawValue) != 0 {
            rxFatalError("oldState.disposable != nil")
        }

        if (previousState & DisposeState.disposed.rawValue) != 0 {
            rxFatalError("actually, it's disposed")
        }
        
        return false
    }
}

public final actor SingleAssignmentDisposable: AsynchronousCancelable {
    private struct DisposeState: OptionSet {
        let rawValue: Int32

        static let disposed = DisposeState(rawValue: 1 << 0)
        static let disposableSet = DisposeState(rawValue: 1 << 1)
    }

    // state
    private let state: NonAtomicInt
    private var disposable = nil as AsynchronousDisposable?

    /// - returns: A value that indicates whether the object is disposed.
    public func isDisposed() -> Bool {
        isFlagSet(state, DisposeState.disposed.rawValue)
    }

    /// Initializes a new instance of the `SingleAssignmentDisposable`.
    public init() {
        state = NonAtomicInt(0)
        SynchronousDisposeBaseInit()
    }

    deinit {
        SynchronousDisposeBaseDeinit()
    }

    /// Gets or sets the underlying disposable. After disposal, the result of getting this property is undefined.
    ///
    /// **Throws exception if the `SingleAssignmentDisposable` has already been assigned to.**
    public func setDisposable(_ disposable: AsynchronousDisposable) async {
        self.disposable = disposable

        let previousState = fetchOr(state, DisposeState.disposableSet.rawValue)

        if (previousState & DisposeState.disposableSet.rawValue) != 0 {
            rxFatalError("oldState.disposable != nil")
        }

        if (previousState & DisposeState.disposed.rawValue) != 0 {
            await disposable.dispose()
            self.disposable = nil
        }
    }
    
    public func setDisposableUnchecked(_ disposable: AsynchronousDisposable) -> Bool {
        self.disposable = disposable
        
        let previousState = fetchOr(state, DisposeState.disposableSet.rawValue)

        if (previousState & DisposeState.disposableSet.rawValue) != 0 {
            rxFatalError("oldState.disposable != nil")
        }

        if (previousState & DisposeState.disposed.rawValue) != 0 {
            rxFatalError("actually, it's disposed")
        }
        
        return false
    }

    /// Disposes the underlying disposable.
    public func dispose() async {
        let previousState = fetchOr(state, DisposeState.disposed.rawValue)

        if (previousState & DisposeState.disposed.rawValue) != 0 {
            return
        }

        if (previousState & DisposeState.disposableSet.rawValue) != 0 {
            guard let disposable else {
                rxFatalError("Disposable not set")
            }
            await disposable.dispose()
            self.disposable = nil
        }
    }
}
