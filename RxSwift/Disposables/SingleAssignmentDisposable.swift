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
public final actor SingleAssignmentDisposable: DisposeBase, Cancelable {
    private enum DisposeState {
        case uninit
        case disposed
        case disposableSet
    }

    // state
    private var state = DisposeState.uninit
    private var disposable = nil as Disposable?

    /// - returns: A value that indicates whether the object is disposed.
    public func isDisposed() async -> Bool {
        self.state == .disposed
    }

    /// Initializes a new instance of the `SingleAssignmentDisposable`.
    public init() {
        #if TRACE_RESOURCES
            _ = Resources.incrementTotal()
        #endif
    }

    deinit {
        #if TRACE_RESOURCES
            _ = Resources.decrementTotal()
        #endif
    }

    /// Gets or sets the underlying disposable. After disposal, the result of getting this property is undefined.
    ///
    /// **Throws exception if the `SingleAssignmentDisposable` has already been assigned to.**
    public func setDisposable(_ disposable: Disposable) async {
        self.disposable = disposable

        let previousState = self.state
        self.state = .disposableSet

        if previousState == .disposableSet {
            rxFatalError("oldState.disposable != nil")
        }

        if previousState == .disposed {
            await disposable.dispose()
            self.disposable = nil
        }
    }

    /// Disposes the underlying disposable.
    public func dispose() async {
        let previousState = self.state
        self.state = .disposed

        if previousState == .disposed {
            return
        }

        if previousState == .disposableSet {
            guard let disposable = self.disposable else {
                rxFatalError("Disposable not set")
            }
            await disposable.dispose()
            self.disposable = nil
        }
    }
}
