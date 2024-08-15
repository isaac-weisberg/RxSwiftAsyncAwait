//
//  SingleAssignmentDisposable.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/15/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

public struct DisposeAction: @unchecked Sendable {
    typealias DisposeAction = @Sendable () -> Void

    private var work: DisposeAction

    init(_ work: @escaping DisposeAction) {
        self.work = work
    }

    func dispose() {
        work()
    }
}

/**
 Represents a disposable resource which only allows a single assignment of its underlying disposable resource.

 If an underlying disposable resource has already been set, future attempts to set the underlying disposable resource will throw an exception.
 */

private struct DisposeState: OptionSet {
    let rawValue: Int32

    static let disposed = DisposeState(rawValue: 1 << 0)
    static let disposableSet = DisposeState(rawValue: 1 << 1)
}
public final class SingleAssignmentDisposableContainer<Disposable>: @unchecked Sendable {

    // state
    private let state = NonAtomicInt(0)
    private var disposable = nil as Disposable?

    /// - returns: A value that indicates whether the object is disposed.
    public var isDisposed: Bool {
        isFlagSet(state, DisposeState.disposed.rawValue)
    }

    /// Initializes a new instance of the `SingleAssignmentDisposable`.
    public init() {
        SynchronousDisposeBaseInit()
    }

    /// Gets or sets the underlying disposable. After disposal, the result of getting this property is undefined.
    ///
    /// **Throws exception if the `SingleAssignmentDisposable` has already been assigned to.**
    public func setDisposable(_ disposable: Disposable) -> Disposable? {
        self.disposable = disposable

        let previousState = fetchOr(state, DisposeState.disposableSet.rawValue)

        if (previousState & DisposeState.disposableSet.rawValue) != 0 {
            rxFatalError("oldState.disposable != nil")
        }

        if (previousState & DisposeState.disposed.rawValue) != 0 {

            self.disposable = nil
            return disposable
        }
        return nil
    }

    /// Disposes the underlying disposable.
    public func dispose() -> Disposable? {
        let previousState = fetchOr(state, DisposeState.disposed.rawValue)

        if (previousState & DisposeState.disposed.rawValue) != 0 {
            return nil
        }

        if (previousState & DisposeState.disposableSet.rawValue) != 0 {
            guard let disposable else {
                rxFatalError("Disposable not set")
            }
            self.disposable = nil
            return disposable
        }
        return nil
    }

    deinit {
        SynchronousDisposeBaseDeinit()
    }
}

public typealias SingleAssignmentDisposable = SingleAssignmentDisposableContainer<Disposable>
public typealias SingleAssignmentSyncDisposable = SingleAssignmentDisposableContainer<DisposeAction>
