//
//  Completable.swift
//  RxSwift
//
//  Created by sergdort on 19/08/2017.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

#if DEBUG
    import Foundation
#endif

/// Sequence containing 0 elements
public enum CompletableTrait {}
/// Represents a push style sequence containing 0 elements.
public typealias Completable = PrimitiveSequence<CompletableTrait, Swift.Never>

@frozen public enum CompletableEvent {
    /// Sequence terminated with an error. (underlying observable sequence emits: `.error(Error)`)
    case error(Swift.Error)

    /// Sequence completed successfully.
    case completed
}

public extension PrimitiveSequenceType where Trait == CompletableTrait, Element == Swift.Never {
    typealias CompletableObserver = @Sendable (CompletableEvent, C) async -> Void

    /**
     Creates an observable sequence from a specified subscribe method implementation.

     - seealso: [create operator on reactivex.io](http://reactivex.io/documentation/operators/create.html)

     - parameter subscribe: Implementation of the resulting observable sequence's `subscribe` method.
     - returns: The observable sequence with the specified implementation for the `subscribe` method.
     */
    static func create(subscribe: @Sendable @escaping (C, @escaping CompletableObserver) async -> Disposable)
        -> PrimitiveSequence<Trait, Element> {
        let source = Observable<Element>.create { c, observer in
            await subscribe(c.call()) { event, c in
                switch event {
                case .error(let error):
                    await observer.on(.error(error), c.call())
                case .completed:
                    await observer.on(.completed, c.call())
                }
            }
        }

        return PrimitiveSequence(raw: source)
    }

    /**
     Subscribes `observer` to receive events for this sequence.

     - returns: Subscription for `observer` that can be used to cancel production of sequence elements and free resources.
     */
    func subscribe(_ c: C, _ observer: @Sendable @escaping (CompletableEvent, C) async -> Void) async -> Disposable {
        await primitiveSequence.asObservable().subscribe(c.call()) { event, c in
            switch event {
            case .next:
                rxFatalError("Completables can't emit values")
            case .error(let error):
                await observer(.error(error), c.call())
            case .completed:
                await observer(.completed, c.call())
            }
        }
    }

    /**
     Subscribes a completion handler and an error handler for this sequence.

     Also, take in an object and provide an unretained, safe to use (i.e. not implicitly unwrapped), reference to it along with the events emitted by the sequence.

     - Note: If `object` can't be retained, none of the other closures will be invoked.

     - parameter object: The object to provide an unretained reference on.
     - parameter onCompleted: Action to invoke upon graceful termination of the observable sequence.
     - parameter onError: Action to invoke upon errored termination of the observable sequence.
     - parameter onDisposed: Action to invoke upon any type of termination of sequence (if the sequence has
     gracefully completed, errored, or if the generation is canceled by disposing subscription).
     - returns: Subscription object used to unsubscribe from the observable sequence.
     */
    func subscribe<Object: AnyObject & Sendable>(
        _ c: C,
        with object: Object,
        onCompleted: (@Sendable (Object) async -> Void)? = nil,
        onError: (@Sendable (Object, Swift.Error) async -> Void)? = nil,
        onDisposed: (@Sendable (Object) async -> Void)? = nil
    )
        async -> Disposable {
        await subscribe(
            c.call(),
            onCompleted: { [weak object] in
                guard let object else { return }
                await onCompleted?(object)
            }, onError: { [weak object] in
                guard let object else { return }
                await onError?(object, $0)
            }, onDisposed: { [weak object] in
                guard let object else { return }
                await onDisposed?(object)
            }
        )
    }

    #if VICIOUS_TRACING
        func subscribe(
            onCompleted: (@Sendable () async -> Void)? = nil,
            onError: (@Sendable (Swift.Error) async -> Void)? = nil,
            onDisposed: (@Sendable () async -> Void)? = nil,
            _ file: StaticString = #file,
            _ function: StaticString = #function,
            _ line: UInt = #line
        )
            async -> Disposable {
            let c = C(file, function, line)
            return await subscribe(c, onCompleted: onCompleted, onError: onError, onDisposed: onDisposed)
        }
    #else
        func subscribe(
            onCompleted: (@Sendable () async -> Void)? = nil,
            onError: (@Sendable (Swift.Error) async -> Void)? = nil,
            onDisposed: (@Sendable () async -> Void)? = nil
        )
            async -> Disposable {
            let c = C()
            return await subscribe(c, onCompleted: onCompleted, onError: onError, onDisposed: onDisposed)
        }
    #endif

    /**
     Subscribes a completion handler and an error handler for this sequence.

     - parameter onCompleted: Action to invoke upon graceful termination of the observable sequence.
     - parameter onError: Action to invoke upon errored termination of the observable sequence.
     - parameter onDisposed: Action to invoke upon any type of termination of sequence (if the sequence has
     gracefully completed, errored, or if the generation is canceled by disposing subscription).
     - returns: Subscription object used to unsubscribe from the observable sequence.
     */
    func subscribe(
        _ c: C,
        onCompleted: (@Sendable () async -> Void)? = nil,
        onError: (@Sendable (Swift.Error) async -> Void)? = nil,
        onDisposed: (@Sendable () async -> Void)? = nil
    )
        async -> Disposable {
        #if DEBUG
            let callStack = Hooks.recordCallStackOnError ? Thread.callStackSymbols : []
        #else
            let callStack = [String]()
        #endif

        let disposable: Disposable
        if let onDisposed {
            disposable = Disposables.create(with: onDisposed)
        } else {
            disposable = Disposables.create()
        }

        let observer: CompletableObserver = { event, c in
            _ = c
            switch event {
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
        }

        return await Disposables.create(
            primitiveSequence.subscribe(c.call(), observer),
            disposable
        )
    }
}

public extension PrimitiveSequenceType where Trait == CompletableTrait, Element == Swift.Never {
    /**
     Returns an observable sequence that terminates with an `error`.

     - seealso: [throw operator on reactivex.io](http://reactivex.io/documentation/operators/empty-never-throw.html)

     - returns: The observable sequence that terminates with specified error.
     */
    static func error(_ error: Swift.Error) -> Completable {
        PrimitiveSequence(raw: Observable.error(error))
    }

    /**
     Returns a non-terminating observable sequence, which can be used to denote an infinite duration.

     - seealso: [never operator on reactivex.io](http://reactivex.io/documentation/operators/empty-never-throw.html)

     - returns: An observable sequence whose observers will never get called.
     */
    static func never() -> Completable {
        PrimitiveSequence(raw: Observable.never())
    }

    /**
     Returns an empty observable sequence, using the specified scheduler to send out the single `Completed` message.

     - seealso: [empty operator on reactivex.io](http://reactivex.io/documentation/operators/empty-never-throw.html)

     - returns: An observable sequence with no elements.
     */
    static func empty() -> Completable {
        Completable(raw: Observable.empty())
    }
}

public extension PrimitiveSequenceType where Trait == CompletableTrait, Element == Swift.Never {
    /**
     Invokes an action for each event in the observable sequence, and propagates all observer messages through the result sequence.

     - seealso: [do operator on reactivex.io](http://reactivex.io/documentation/operators/do.html)

     - parameter onNext: Action to invoke for each element in the observable sequence.
     - parameter onError: Action to invoke upon errored termination of the observable sequence.
     - parameter afterError: Action to invoke after errored termination of the observable sequence.
     - parameter onCompleted: Action to invoke upon graceful termination of the observable sequence.
     - parameter afterCompleted: Action to invoke after graceful termination of the observable sequence.
     - parameter onSubscribe: Action to invoke before subscribing to source observable sequence.
     - parameter onSubscribed: Action to invoke after subscribing to source observable sequence.
     - parameter onDispose: Action to invoke after subscription to source observable has been disposed for any reason. It can be either because sequence terminates for some reason or observer subscription being disposed.
     - returns: The source sequence with the side-effecting behavior applied.
     */
    func `do`(
        onError: (@Sendable (Swift.Error) async throws -> Void)? = nil,
        afterError: (@Sendable (Swift.Error) async throws -> Void)? = nil,
        onCompleted: (@Sendable () async throws -> Void)? = nil,
        afterCompleted: (@Sendable () async throws -> Void)? = nil,
        onSubscribe: (@Sendable () async -> Void)? = nil,
        onSubscribed: (@Sendable () async -> Void)? = nil,
        onDispose: (@Sendable () async -> Void)? = nil
    ) -> Completable {
        Completable(
            raw: primitiveSequence.source.do(
                onError: onError,
                afterError: afterError,
                onCompleted: onCompleted,
                afterCompleted: afterCompleted,
                onSubscribe: onSubscribe,
                onSubscribed: onSubscribed,
                onDispose: onDispose
            )
        )
    }

    /**
     Concatenates the second observable sequence to `self` upon successful termination of `self`.

     - seealso: [concat operator on reactivex.io](http://reactivex.io/documentation/operators/concat.html)

     - parameter second: Second observable sequence.
     - returns: An observable sequence that contains the elements of `self`, followed by those of the second sequence.
     */
//    func concat(_ second: Completable) async -> Completable {
//        await Completable.concat(self.primitiveSequence, second)
//    }

    /**
     Concatenates all observable sequences in the given sequence, as long as the previous observable sequence terminated successfully.

     - seealso: [concat operator on reactivex.io](http://reactivex.io/documentation/operators/concat.html)

     - returns: An observable sequence that contains the elements of each given sequence, in sequential order.
     */
//    static func concat<Sequence: Swift.Sequence>(_ sequence: Sequence) async -> Completable
//        where Sequence.Element == Completable
//    {
//        let source = await Observable.concat(sequence.lazy.map { $0.asObservable() })
//        return Completable(raw: source)
//    }

    /**
     Concatenates all observable sequences in the given sequence, as long as the previous observable sequence terminated successfully.

     - seealso: [concat operator on reactivex.io](http://reactivex.io/documentation/operators/concat.html)

     - returns: An observable sequence that contains the elements of each given sequence, in sequential order.
     */
//    static func concat<Collection: Swift.Collection>(_ collection: Collection) async -> Completable
//        where Collection.Element == Completable
//    {
//        let source = await Observable.concat(collection.map { $0.asObservable() })
//        return Completable(raw: source)
//    }

    /**
     Concatenates all observable sequences in the given sequence, as long as the previous observable sequence terminated successfully.

     - seealso: [concat operator on reactivex.io](http://reactivex.io/documentation/operators/concat.html)

     - returns: An observable sequence that contains the elements of each given sequence, in sequential order.
     */
//    static func concat(_ sources: Completable ...) async -> Completable {
//        let source = await Observable.concat(sources.map { $0.asObservable() })
//        return Completable(raw: source)
//    }

    /**
     Merges the completion of all Completables from a collection into a single Completable.

     - seealso: [merge operator on reactivex.io](http://reactivex.io/documentation/operators/merge.html)
     - note: For `Completable`, `zip` is an alias for `merge`.

     - parameter sources: Collection of Completables to merge.
     - returns: A Completable that merges the completion of all Completables.
     */
//    static func zip<Collection: Swift.Collection>(_ sources: Collection) async -> Completable
//        where Collection.Element == Completable
//    {
//        let source = await Observable.merge(sources.map { $0.asObservable() })
//        return Completable(raw: source)
//    }

    /**
     Merges the completion of all Completables from an array into a single Completable.

     - seealso: [merge operator on reactivex.io](http://reactivex.io/documentation/operators/merge.html)
     - note: For `Completable`, `zip` is an alias for `merge`.

     - parameter sources: Array of observable sequences to merge.
     - returns: A Completable that merges the completion of all Completables.
     */
//    static func zip(_ sources: [Completable]) async -> Completable {
//        let source = await Observable.merge(sources.map { $0.asObservable() })
//        return Completable(raw: source)
//    }

    /**
     Merges the completion of all Completables into a single Completable.

     - seealso: [merge operator on reactivex.io](http://reactivex.io/documentation/operators/merge.html)
     - note: For `Completable`, `zip` is an alias for `merge`.

     - parameter sources: Collection of observable sequences to merge.
     - returns: The observable sequence that merges the elements of the observable sequences.
     */
//    static func zip(_ sources: Completable...) async -> Completable {
//        let source = await Observable.merge(sources.map { $0.asObservable() })
//        return Completable(raw: source)
//    }
}
