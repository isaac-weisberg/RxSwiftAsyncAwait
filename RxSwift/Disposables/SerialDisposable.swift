//
//  SerialDisposable.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 3/12/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/// Represents a disposable resource whose underlying disposable resource can be replaced by another disposable
/// resource, causing automatic disposal of the previous underlying disposable resource.
public final actor SerialDisposable: AsynchronousCancelable {
    // state
    private var current = nil as AsynchronousDisposable?
    private var disposed = false

    /// - returns: Was resource disposed.
    public func isDisposed() -> Bool {
        disposed
    }

    /// Initializes a new instance of the `SerialDisposable`.
    public init() {
        SynchronousDisposeBaseInit()
    }

    deinit {
        SynchronousDisposeBaseDeinit()
    }

    /**
     Gets or sets the underlying disposable.

     Assigning this property disposes the previous disposable object.

     If the `SerialDisposable` has already been disposed, assignment to this property causes immediate disposal of the given disposable object.
     */

    public func getDisposable() -> AsynchronousDisposable {
        current ?? Disposables.create()
    }

    public func setDisposable(_ newDisposable: AsynchronousDisposable) async {
        let disposable: AsynchronousDisposable? = {
            if self.isDisposed() {
                return newDisposable
            } else {
                let toDispose = self.current
                self.current = newDisposable
                return toDispose
            }
        }()

        if let disposable {
            await disposable.dispose()
        }
    }

    /// Disposes the underlying disposable as well as all future replacements.
    public func dispose() async {
        await _dispose()?.dispose()
    }

    private func _dispose() -> AsynchronousDisposable? {
        guard !isDisposed() else { return nil }

        disposed = true
        let current = current
        self.current = nil
        return current
    }
}
