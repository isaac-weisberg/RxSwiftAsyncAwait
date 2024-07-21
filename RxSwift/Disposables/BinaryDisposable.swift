//
//  BinaryDisposable.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 6/12/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/// Represents two disposable resources that are disposed together.
private final class BinaryDisposable: DisposeBase, Cancelable {
    private let disposed: ActualAtomicInt

    // state
    private var disposable1: Disposable?
    private var disposable2: Disposable?

    /// - returns: Was resource disposed.
    func isDisposed() async -> Bool {
        await isFlagSet(self.disposed, 1)
    }

    /// Constructs new binary disposable from two disposables.
    ///
    /// - parameter disposable1: First disposable
    /// - parameter disposable2: Second disposable
    init(_ disposable1: Disposable, _ disposable2: Disposable) async {
        self.disposed = await ActualAtomicInt(0)
        self.disposable1 = disposable1
        self.disposable2 = disposable2
        await super.init()
    }

    /// Calls the disposal action if and only if the current instance hasn't been disposed yet.
    ///
    /// After invoking disposal action, disposal action will be dereferenced.
    func dispose() async {
        if await fetchOr(self.disposed, 1) == 0 {
            await self.disposable1?.dispose()
            await self.disposable2?.dispose()
            self.disposable1 = nil
            self.disposable2 = nil
        }
    }
}

public extension Disposables {
    /// Creates a disposable with the given disposables.
    static func create(_ disposable1: Disposable, _ disposable2: Disposable) async -> Cancelable {
        await BinaryDisposable(disposable1, disposable2)
    }
}
