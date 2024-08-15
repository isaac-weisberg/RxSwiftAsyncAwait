//
//  ObservableType+Extensions.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/21/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

#if DEBUG
    import Foundation
#endif

public extension ObservableType {
    /**
     Subscribes an event handler to an observable sequence.

     - parameter on: Action to invoke for each event in the observable sequence.
     - returns: Subscription object used to unsubscribe from the observable sequence.
     */
    func subscribe(_ c: C, _ on: @escaping (Event<Element>, C) async -> Void) async -> AsynchronousDisposable {
        let observer = AnyObserver<Element>(eventHandler: { e, c in
            await on(e, c.call())
        })
        return await asObservable().subscribe(c.call(), observer)
    }

    /**
     Subscribes an element handler, an error handler, a completion handler and disposed handler to an observable sequence.

     Also, take in an object and provide an unretained, safe to use (i.e. not implicitly unwrapped), reference to it along with the events emitted by the sequence.

     - Note: If `object` can't be retained, none of the other closures will be invoked.

     - parameter object: The object to provide an unretained reference on.
     - parameter onNext: Action to invoke for each element in the observable sequence.
     - parameter onError: Action to invoke upon errored termination of the observable sequence.
     - parameter onCompleted: Action to invoke upon graceful termination of the observable sequence.
     - parameter onDisposed: Action to invoke upon any type of termination of sequence (if the sequence has
     gracefully completed, errored, or if the generation is canceled by disposing subscription).
     - returns: Subscription object used to unsubscribe from the observable sequence.
     */
    func subscribe<Object: AnyObject>(
        _ c: C,
        with object: Object,
        onNext: ((Object, Element) -> Void)? = nil,
        onError: ((Object, Swift.Error) -> Void)? = nil,
        onCompleted: ((Object) -> Void)? = nil,
        onDisposed: ((Object) -> Void)? = nil
    )
        async -> AsynchronousDisposable {
        await subscribe(
            c.call(),
            onNext: { [weak object] in
                guard let object else { return }
                onNext?(object, $0)
            },
            onError: { [weak object] in
                guard let object else { return }
                onError?(object, $0)
            },
            onCompleted: { [weak object] in
                guard let object else { return }
                onCompleted?(object)
            },
            onDisposed: { [weak object] in
                guard let object else { return }
                onDisposed?(object)
            }
        )
    }

    /**
     Subscribes an element handler, an error handler, a completion handler and disposed handler to an observable sequence.
     
     - parameter onNext: Action to invoke for each element in the observable sequence.
     - parameter onError: Action to invoke upon errored termination of the observable sequence.
     - parameter onCompleted: Action to invoke upon graceful termination of the observable sequence.
     - parameter onDisposed: Action to invoke upon any type of termination of sequence (if the sequence has
     gracefully completed, errored, or if the generation is canceled by disposing subscription).
     - returns: Subscription object used to unsubscribe from the observable sequence.
     */
    #if VICIOUS_TRACING
        func subscribe(
            _ file: StaticString = #file,
            _ function: StaticString = #function,
            _ line: UInt = #line,
            onNext: (@Sendable (Element) async -> Void)? = nil,
            onError: (@Sendable (Swift.Error) async -> Void)? = nil,
            onCompleted: (@Sendable () async -> Void)? = nil,
            onDisposed: (@Sendable () async -> Void)? = nil
        )
            async -> AsynchronousDisposable {
            let c = C(file, function, line)
            return await subscribe(
                c,
                onNext: onNext,
                onError: onError,
                onCompleted: onCompleted,
                onDisposed: onDisposed
            )
        }
    #else
        func subscribe(
            onNext: (@Sendable (Element) async -> Void)? = nil,
            onError: (@Sendable (Swift.Error) async -> Void)? = nil,
            onCompleted: (@Sendable () async -> Void)? = nil,
            onDisposed: (@Sendable () async -> Void)? = nil
        )
            async -> AsynchronousDisposable {
            await subscribe(C(), onNext: onNext, onError: onError, onCompleted: onCompleted, onDisposed: onDisposed)
        }
    #endif

    func subscribe(
        _ c: C,
        onNext: (@Sendable (Element) async -> Void)? = nil,
        onError: (@Sendable (Swift.Error) async -> Void)? = nil,
        onCompleted: (@Sendable () async -> Void)? = nil,
        onDisposed: (@Sendable () async -> Void)? = nil
    )
        async -> AsynchronousDisposable {
        let disposable: AsynchronousDisposable

        if let disposed = onDisposed {
            disposable = Disposables.create(with: disposed)
        } else {
            disposable = Disposables.create()
        }

        let callStack = Hooks.recordCallStackOnError ? await Hooks.getCustomCaptureSubscriptionCallstack()() : []

        let observer = AnyAsyncObserver<Element>(eventHandler: { event, _ in
            switch event {
            case .next(let value):
                await onNext?(value)
            case .error(let error):
                if let onError {
                    await onError(error)
                } else {
                    await Hooks.getDefaultErrorHandler()(callStack, error)
                }
                await disposable.dispose()
            case .completed:
                await onCompleted?()
                await disposable.dispose()
            }
        })

        let disposableFromSub = await asObservable().subscribe(c.call(), observer)
        return Disposables.create {
            await disposableFromSub.dispose()
            await disposable.dispose()
        }
    }
}

import Foundation

public extension Hooks {
    typealias DefaultErrorHandler = (_ subscriptionCallStack: [String], _ error: Error) -> Void
    typealias CustomCaptureSubscriptionCallstack = () -> [String]

    private static let lock = ActualNonRecursiveLock()

    // call me manually plz
    static func initialize() async {
        #if TRACE_RESOURCES
            await Resources.initialize()
        #endif
    }

    private static var _defaultErrorHandler: DefaultErrorHandler = { subscriptionCallStack, error in
        #if DEBUG
            let serializedCallStack = subscriptionCallStack.joined(separator: "\n")
            print("Unhandled error happened: \(error)")
            if !serializedCallStack.isEmpty {
                print("subscription called from:\n\(serializedCallStack)")
            }
        #endif
    }

    private static var _customCaptureSubscriptionCallstack: CustomCaptureSubscriptionCallstack = {
        #if DEBUG
            return Thread.callStackSymbols
        #else
            return []
        #endif
    }

    /// Error handler called in case onError handler wasn't provided.
    static func getDefaultErrorHandler() async -> DefaultErrorHandler {
        await lock.performLocked {
            self._defaultErrorHandler
        }
    }

    static func setDefaultErrorHandler(_ newValue: @escaping DefaultErrorHandler) async {
        await lock.performLocked {
            self._defaultErrorHandler = newValue
        }
    }

    /// Subscription callstack block to fetch custom callstack information.
    static func getCustomCaptureSubscriptionCallstack() async -> CustomCaptureSubscriptionCallstack {
        await lock.performLocked { self._customCaptureSubscriptionCallstack }
    }

    static func setCustomCaptureSubscriptionCallstack(_ newValue: @escaping CustomCaptureSubscriptionCallstack) async {
        await lock.performLocked { self._customCaptureSubscriptionCallstack = newValue }
    }
}
