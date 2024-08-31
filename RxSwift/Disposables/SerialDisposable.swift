//
//  SerialDisposable.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 3/12/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/// Represents a disposable resource whose underlying disposable resource can be replaced by another disposable
/// resource, causing automatic disposal of the previous underlying disposable resource.
public final class SerialDisposableGeneric<Disposable> {
    // state
    private var current = nil as Disposable?
    private var disposed = false

    /// Initializes a new instance of the `SerialDisposable`.
    public init() {
        SynchronousDisposeBaseInit()
    }

    deinit {
        SynchronousDisposeBaseDeinit()
    }

    /// - returns: Was resource disposed.
    public var isDisposed: Bool {
        disposed
    }

    public func replace(_ newDisposable: Disposable) -> Disposable? {
        if disposed {
            return newDisposable
        } else {
            let old = current
            current = newDisposable
            return old
        }
    }

    /// Disposes the underlying disposable as well as all future replacements.
    public func dispose() -> Disposable? {
        guard !isDisposed else { return nil }

        disposed = true
        let current = current
        self.current = nil
        return current
    }
}

public typealias SerialDisposable = SerialDisposableGeneric<Disposable>

public final class SerialPerpetualDisposable<Disposable>: @unchecked Sendable {
    // state
    private var current = nil as Disposable?

    /// Initializes a new instance of the `SerialDisposable`.
    public init() {
        SynchronousDisposeBaseInit()
    }

    deinit {
        SynchronousDisposeBaseDeinit()
    }

    public func replace(_ newDisposable: Disposable) -> Disposable? {
        let oldCurrent = current
        current = newDisposable
        return oldCurrent
    }

    /// Disposes the underlying disposable, but no the future replacements
    public func dispose() -> Disposable? {
        if let current {
            self.current = nil
            return current
        }
        return nil
    }
}
