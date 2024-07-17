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
    func subscribe(_ on: @escaping (Event<Element>) async -> Void) async -> Disposable {
        let observer = await AnonymousObserver { e in
            await on(e)
        }
        return await self.asObservable().subscribe(observer)
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
        with object: Object,
        onNext: ((Object, Element) -> Void)? = nil,
        onError: ((Object, Swift.Error) -> Void)? = nil,
        onCompleted: ((Object) -> Void)? = nil,
        onDisposed: ((Object) -> Void)? = nil
    ) async -> Disposable {
        await self.subscribe(
            onNext: { [weak object] in
                guard let object = object else { return }
                onNext?(object, $0)
            },
            onError: { [weak object] in
                guard let object = object else { return }
                onError?(object, $0)
            },
            onCompleted: { [weak object] in
                guard let object = object else { return }
                onCompleted?(object)
            },
            onDisposed: { [weak object] in
                guard let object = object else { return }
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
    func subscribe(
        onNext: ((Element) async -> Void)? = nil,
        onError: ((Swift.Error) async -> Void)? = nil,
        onCompleted: (() async -> Void)? = nil,
        onDisposed: (() async -> Void)? = nil
    ) async -> Disposable {
        let disposable: Disposable
            
        if let disposed = onDisposed {
            disposable = await Disposables.create(with: disposed)
        }
        else {
            disposable = Disposables.create()
        }
            
        #if DEBUG
            let synchronizationTracker = await SynchronizationTracker()
        #endif
            
        let callStack = Hooks.recordCallStackOnError ? await Hooks.getCustomCaptureSubscriptionCallstack()() : []
            
        let observer = await AnonymousObserver<Element> { event in
            #if DEBUG
                await synchronizationTracker.register(synchronizationErrorMessage: .default)
            #endif
            await scope {
                switch event {
                case .next(let value):
                    await onNext?(value)
                case .error(let error):
                    if let onError = onError {
                        await onError(error)
                    }
                    else {
                        await Hooks.getDefaultErrorHandler()(callStack, error)
                    }
                    await disposable.dispose()
                case .completed:
                    await onCompleted?()
                    await disposable.dispose()
                }
            }
            #if DEBUG
                await synchronizationTracker.unregister()
            #endif
        }
        return await Disposables.create(
            await self.asObservable().subscribe(observer),
            disposable
        )
    }
}

import Foundation

public extension Hooks {
    typealias DefaultErrorHandler = (_ subscriptionCallStack: [String], _ error: Error) -> Void
    typealias CustomCaptureSubscriptionCallstack = () -> [String]

    private static var lock: RecursiveLock!
    
    // call me manually plz
    static func initialize() async {
        await MainScheduler.initialize()
        BooleanDisposable.BooleanDisposableTrue = await BooleanDisposable(isDisposed: true)
        #if TRACE_RESOURCES
            await Resources.initialize()
        #endif
        self.lock = await RecursiveLock()
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
        await self.lock.performLocked {
            self._defaultErrorHandler
        }
    }

    static func setDefaultErrorHandler(_ newValue: @escaping DefaultErrorHandler) async {
        await self.lock.performLocked {
            self._defaultErrorHandler = newValue
        }
    }
    
    /// Subscription callstack block to fetch custom callstack information.
    static func getCustomCaptureSubscriptionCallstack() async -> CustomCaptureSubscriptionCallstack {
        await self.lock.performLocked { self._customCaptureSubscriptionCallstack }
    }
    
    static func setCustomCaptureSubscriptionCallstack(_ newValue: @escaping CustomCaptureSubscriptionCallstack) async {
        await self.lock.performLocked { self._customCaptureSubscriptionCallstack = newValue }
    }
}
