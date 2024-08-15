//
//  BinaryDisposable.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 6/12/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/// Represents two disposable resources that are disposed together.
final class BinaryDisposable {
    private let disposed: NonAtomicInt

    // state
    private let disposable1: SingleAssignmentDisposable
    private let disposable2: SingleAssignmentDisposable

    /// - returns: Was resource disposed.
    func isDisposed() -> Bool {
        isFlagSet(disposed, 1)
    }

    /// Constructs new binary disposable from two disposables.
    ///
    /// - parameter disposable1: First disposable
    /// - parameter disposable2: Second disposable
    init(_ disposable1: SingleAssignmentDisposable, _ disposable2: SingleAssignmentDisposable) {
        disposed = NonAtomicInt(0)
        self.disposable1 = disposable1
        self.disposable2 = disposable2
        SynchronousDisposeBaseInit()
    }

    /// Calls the disposal action if and only if the current instance hasn't been disposed yet.
    ///
    /// After invoking disposal action, disposal action will be dereferenced.
    func dispose() -> Dispose2Action? {
        if fetchOr(disposed, 1) == 0 {
            let disposable1 = self.disposable1.dispose()
            let disposable2 = self.disposable2.dispose()
            
            return Dispose2Action(disposable1: disposable1, disposable2: disposable2)
        }
        return nil
    }

    deinit {
        SynchronousDisposeBaseDeinit()
    }
}
//
//public extension Disposables {
//    /// Creates a disposable with the given disposables.
//    static func create(
//        _ disposable1: AsynchronousDisposable,
//        _ disposable2: AsynchronousDisposable
//    ) -> AsynchronousCancelable {
//        BinaryDisposable(disposable1, disposable2)
//    }
//}

struct Dispose2Action {
    let disposable1: Disposable?
    let disposable2: Disposable?
    
    init?(disposable1: Disposable?, disposable2: Disposable?) {
        if disposable1 == nil, disposable2 == nil {
            return nil
        }
        self.disposable1 = disposable1
        self.disposable2 = disposable2
    }
    
    func dispose() async {
        async let disposed1: ()? = disposable1?.dispose()
        async let disposed2: ()? = disposable2?.dispose()
        
        await disposed1
        await disposed2
    }
}
