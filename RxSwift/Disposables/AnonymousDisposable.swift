//
//  AnonymousDisposable.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/15/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/// Represents an Action-based disposable.
///
/// When dispose method is called, disposal action will be dereferenced.
private final class AnonymousDisposable: DisposeBase, Cancelable {
    public typealias DisposeAction = () async -> Void

    private let disposed: AtomicInt
    private var disposeAction: DisposeAction?

    /// - returns: Was resource disposed.
    func isDisposed() async -> Bool {
        await isFlagSet(self.disposed, 1)
    }

    /// Constructs a new disposable with the given action used for disposal.
    ///
    /// - parameter disposeAction: Disposal action which will be run upon calling `dispose`.
    private init(_ disposeAction: @escaping DisposeAction) async {
        disposed = await AtomicInt(0)
        self.disposeAction = disposeAction
        await super.init()
    }

    // Non-deprecated version of the constructor, used by `Disposables.create(with:)`
    fileprivate init(disposeAction: @escaping DisposeAction) async {
        self.disposeAction = disposeAction
        await super.init()
    }

    /// Calls the disposal action if and only if the current instance hasn't been disposed yet.
    ///
    /// After invoking disposal action, disposal action will be dereferenced.
    fileprivate func dispose() async {
        if await fetchOr(self.disposed, 1) == 0 {
            if let action = self.disposeAction {
                self.disposeAction = nil
                await action()
            }
        }
    }
}

public extension Disposables {
    /// Constructs a new disposable with the given action used for disposal.
    ///
    /// - parameter dispose: Disposal action which will be run upon calling `dispose`.
    static func create(with dispose: @escaping () async -> Void) async -> Cancelable {
        await AnonymousDisposable(disposeAction: dispose)
    }
}
