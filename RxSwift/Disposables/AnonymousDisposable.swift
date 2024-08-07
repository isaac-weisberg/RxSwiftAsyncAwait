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
//private final class AnonymousDisposable: SynchronousDisposeBase, SynchronousCancelable {
//    public typealias DisposeAction = () -> Void
//
//    private let disposed: NonAtomicInt
//    private var disposeAction: DisposeAction?
//
//    /// - returns: Was resource disposed.
//    func isDisposed() -> Bool {
//        isFlagSet(disposed, 1)
//    }
//
//    /// Constructs a new disposable with the given action used for disposal.
//    ///
//    /// - parameter disposeAction: Disposal action which will be run upon calling `dispose`.
//    private init(_ disposeAction: @escaping DisposeAction) {
//        disposed = NonAtomicInt()
//        self.disposeAction = disposeAction
//        super.init()
//    }
//
//    // Non-deprecated version of the constructor, used by `Disposables.create(with:)`
//    fileprivate init(disposeAction: @escaping DisposeAction) {
//        self.disposeAction = disposeAction
//        disposed = NonAtomicInt()
//        super.init()
//    }
//
//    /// Calls the disposal action if and only if the current instance hasn't been disposed yet.
//    ///
//    /// After invoking disposal action, disposal action will be dereferenced.
//    fileprivate func dispose() {
//        if fetchOr(disposed, 1) == 0 {
//            if let action = disposeAction {
//                disposeAction = nil
//                action()
//            }
//        }
//    }
//}
//
//public extension Disposables {
//    /// Constructs a new disposable with the given action used for disposal.
//    ///
//    /// - parameter dispose: Disposal action which will be run upon calling `dispose`.
//    static func create(with dispose: @escaping () -> Void) -> SynchronousCancelable {
//        AnonymousDisposable(disposeAction: dispose)
//    }
//}

extension Disposables {
    static func createSync(with dispose: @Sendable @escaping () async -> Void) -> AsynchronousCancelable {
        AnonymousAsynchronousDisposable(disposeAction: dispose)
    }
}

private final actor AnonymousAsynchronousDisposable: AsynchronousCancelable, AsynchronousDisposable {
    public typealias DisposeAction = () async -> Void

    private let disposed: NonAtomicInt
    private var disposeAction: DisposeAction?

    /// - returns: Was resource disposed.
    func isDisposed() -> Bool {
        isFlagSet(disposed, 1)
    }

    // Non-deprecated version of the constructor, used by `Disposables.create(with:)`
    fileprivate init(disposeAction: @escaping DisposeAction) {
        self.disposeAction = disposeAction
        disposed = NonAtomicInt()
    }

    /// Calls the disposal action if and only if the current instance hasn't been disposed yet.
    ///
    /// After invoking disposal action, disposal action will be dereferenced.
    fileprivate func dispose() async {
        if fetchOr(disposed, 1) == 0 {
            if let action = disposeAction {
                disposeAction = nil
                await action()
            }
        }
    }
}
