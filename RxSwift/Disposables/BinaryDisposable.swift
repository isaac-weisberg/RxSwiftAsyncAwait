//
//  BinaryDisposable.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 6/12/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/// Represents two disposable resources that are disposed together.
private final class BinaryDisposable: UnsynchronizedDisposeBase, UnsynchronizedCancelable {
    private let disposed: NonAtomicInt

    // state
    private var disposable1: UnsynchronizedDisposable?
    private var disposable2: UnsynchronizedDisposable?

    /// - returns: Was resource disposed.
    func isDisposed() -> Bool {
        isFlagSet(disposed, 1)
    }

    /// Constructs new binary disposable from two disposables.
    ///
    /// - parameter disposable1: First disposable
    /// - parameter disposable2: Second disposable
    init(_ disposable1: UnsynchronizedDisposable, _ disposable2: UnsynchronizedDisposable) {
        disposed = NonAtomicInt(0)
        self.disposable1 = disposable1
        self.disposable2 = disposable2
        super.init()
    }

    /// Calls the disposal action if and only if the current instance hasn't been disposed yet.
    ///
    /// After invoking disposal action, disposal action will be dereferenced.
    func dispose() {
        if fetchOr(disposed, 1) == 0 {
            disposable1?.dispose()
            disposable2?.dispose()
            disposable1 = nil
            disposable2 = nil
        }
    }
}

public extension Disposables {
    /// Creates a disposable with the given disposables.
    static func create(_ disposable1: UnsynchronizedDisposable, _ disposable2: UnsynchronizedDisposable) -> UnsynchronizedCancelable {
        BinaryDisposable(disposable1, disposable2)
    }
}
