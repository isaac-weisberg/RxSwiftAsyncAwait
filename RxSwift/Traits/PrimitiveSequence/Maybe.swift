//
//  Maybe.swift
//  RxSwift
//
//  Created by sergdort on 19/08/2017.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

#if DEBUG
    import Foundation
#endif

/// Sequence containing 0 or 1 elements
public enum MaybeTrait {}
/// Represents a push style sequence containing 0 or 1 element.
public typealias Maybe<Element> = PrimitiveSequence<MaybeTrait, Element>

@frozen public enum MaybeEvent<Element> {
    /// One and only sequence element is produced. (underlying observable sequence emits: `.next(Element)`,
    /// `.completed`)
    case success(Element)

    /// Sequence terminated with an error. (underlying observable sequence emits: `.error(Error)`)
    case error(Swift.Error)

    /// Sequence completed successfully.
    case completed
}

public extension PrimitiveSequenceType where Trait == MaybeTrait {
    typealias MaybeObserver = @Sendable (MaybeEvent<Element>) async -> Void
    typealias FullMaybeObserver = @Sendable (MaybeEvent<Element>, C) async -> Void

    /**
     Creates an observable sequence from a specified subscribe method implementation.

     - seealso: [create operator on reactivex.io](http://reactivex.io/documentation/operators/create.html)

     - parameter subscribe: Implementation of the resulting observable sequence's `subscribe` method.
     - returns: The observable sequence with the specified implementation for the `subscribe` method.
     */
    static func create(subscribe: @Sendable @escaping (@escaping MaybeObserver) async -> Disposable)
        -> PrimitiveSequence<Trait, Element> {
        ccreate { c, observer in
            await subscribe { event in
                await observer(event, c.call())
            }
        }
    }

    static func ccreate(subscribe: @Sendable @escaping (C, @escaping FullMaybeObserver) async -> Disposable)
        -> PrimitiveSequence<Trait, Element> {
        let source = Observable<Element>.ccreate { c, observer in
            await subscribe(c.call()) { event, c in
                switch event {
                case .success(let element):
                    await observer.on(.next(element), c.call())
                    await observer.on(.completed, c.call())
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
    #if VICIOUS_TRACING
        func subscribe(
            file: StaticString = #file,
            function: StaticString = #function,
            line: UInt = #line,
            _ observer: @escaping FullMaybeObserver
        )
            async -> Disposable {
            await subscribe(C(file, function, line), observer)
        }
    #else
        func subscribe(
            _ observer: @escaping FullMaybeObserver
        )
            async -> Disposable {
            await subscribe(C(), observer)
        }
    #endif

    func subscribe(_ c: C, _ observer: @escaping FullMaybeObserver) async -> Disposable {
        await primitiveSequence.asObservable().subscribe(c.call()) { event, c in
            switch event {
            case .next(let element):
                await observer(.success(element), c.call())
            case .error(let error):
                await observer(.error(error), c.call())
            case .completed:
                await observer(.completed, c.call())
            }
        }
    }

    /**
     Subscribes a success handler, an error handler, and a completion handler for this sequence.

     Also, take in an object and provide an unretained, safe to use (i.e. not implicitly unwrapped), reference to it along with the events emitted by the sequence.

     - Note: If `object` can't be retained, none of the other closures will be invoked.

     - parameter object: The object to provide an unretained reference on.
     - parameter onSuccess: Action to invoke for each element in the observable sequence.
     - parameter onError: Action to invoke upon errored termination of the observable sequence.
     - parameter onCompleted: Action to invoke upon graceful termination of the observable sequence.
     - parameter onDisposed: Action to invoke upon any type of termination of sequence (if the sequence has
     gracefully completed, errored, or if the generation is canceled by disposing subscription).
     - returns: Subscription object used to unsubscribe from the observable sequence.
     */
    func subscribe<Object: AnyObject & Sendable>(
        _ c: C,
        with object: Object,
        onSuccess: (@Sendable (Object, Element) async -> Void)? = nil,
        onError: (@Sendable (Object, Swift.Error) async -> Void)? = nil,
        onCompleted: (@Sendable (Object) async -> Void)? = nil,
        onDisposed: (@Sendable (Object) async -> Void)? = nil
    )
        async -> Disposable {
        await subscribe(
            c.call(),
            onSuccess: { [weak object] in
                guard let object else { return }
                await onSuccess?(object, $0)
            },
            onError: { [weak object] in
                guard let object else { return }
                await onError?(object, $0)
            },
            onCompleted: { [weak object] in
                guard let object else { return }
                await onCompleted?(object)
            },
            onDisposed: { [weak object] in
                guard let object else { return }
                await onDisposed?(object)
            }
        )
    }

    /**
     Subscribes a success handler, an error handler, and a completion handler for this sequence.

     - parameter onSuccess: Action to invoke for each element in the observable sequence.
     - parameter onError: Action to invoke upon errored termination of the observable sequence.
     - parameter onCompleted: Action to invoke upon graceful termination of the observable sequence.
     - parameter onDisposed: Action to invoke upon any type of termination of sequence (if the sequence has
     gracefully completed, errored, or if the generation is canceled by disposing subscription).
     - returns: Subscription object used to unsubscribe from the observable sequence.
     */

    #if VICIOUS_TRACING
        func subscribe(
            file: StaticString = #file,
            function: StaticString = #function,
            line: UInt = #line,
            onSuccess: (@Sendable (Element) async -> Void)? = nil,
            onError: (@Sendable (Swift.Error) async -> Void)? = nil,
            onCompleted: (@Sendable () async -> Void)? = nil,
            onDisposed: (@Sendable () async -> Void)? = nil
        )
            async -> Disposable {
            await subscribe(
                C(file, function, line),
                onSuccess: onSuccess,
                onError: onError,
                onCompleted: onCompleted,
                onDisposed: onDisposed
            )
        }
    #else
        func subscribe(
            onSuccess: (@Sendable (Element) async -> Void)? = nil,
            onError: (@Sendable (Swift.Error) async -> Void)? = nil,
            onCompleted: (@Sendable () async -> Void)? = nil,
            onDisposed: (@Sendable () async -> Void)? = nil
        )
            async -> Disposable {
            await subscribe(
                C(),
                onSuccess: onSuccess,
                onError: onError,
                onCompleted: onCompleted,
                onDisposed: onDisposed
            )
        }
    #endif

    func subscribe(
        _ c: C,
        onSuccess: (@Sendable (Element) async -> Void)? = nil,
        onError: (@Sendable (Swift.Error) async -> Void)? = nil,
        onCompleted: (@Sendable () async -> Void)? = nil,
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

        let observer: FullMaybeObserver = { event, c in
            _ = c
            switch event {
            case .success(let element):
                await onSuccess?(element)
                await disposable.dispose()
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

public extension PrimitiveSequenceType where Trait == MaybeTrait {
    /**
     Returns an observable sequence that contains a single element.

     - seealso: [just operator on reactivex.io](http://reactivex.io/documentation/operators/just.html)

     - parameter element: Single element in the resulting observable sequence.
     - returns: An observable sequence containing the single specified element.
     */
    static func just(_ element: Element) -> Maybe<Element> {
        Maybe(raw: Observable.just(element))
    }

    /**
     Returns an observable sequence that contains a single element.

     - seealso: [just operator on reactivex.io](http://reactivex.io/documentation/operators/just.html)

     - parameter element: Single element in the resulting observable sequence.
     - parameter scheduler: Scheduler to send the single element on.
     - returns: An observable sequence containing the single specified element.
     */
    static func just(_ element: Element, scheduler: AsyncScheduler) -> Maybe<Element> {
        Maybe(raw: Observable.just(element, scheduler: scheduler))
    }

    /**
     Returns an observable sequence that terminates with an `error`.

     - seealso: [throw operator on reactivex.io](http://reactivex.io/documentation/operators/empty-never-throw.html)

     - returns: The observable sequence that terminates with specified error.
     */
    static func error(_ error: Swift.Error) -> Maybe<Element> {
        PrimitiveSequence(raw: Observable.error(error))
    }

    /**
     Returns a non-terminating observable sequence, which can be used to denote an infinite duration.

     - seealso: [never operator on reactivex.io](http://reactivex.io/documentation/operators/empty-never-throw.html)

     - returns: An observable sequence whose observers will never get called.
     */
    static func never() -> Maybe<Element> {
        PrimitiveSequence(raw: Observable.never())
    }

    /**
     Returns an empty observable sequence, using the specified scheduler to send out the single `Completed` message.

     - seealso: [empty operator on reactivex.io](http://reactivex.io/documentation/operators/empty-never-throw.html)

     - returns: An observable sequence with no elements.
     */
    static func empty() -> Maybe<Element> {
        Maybe(raw: Observable.empty())
    }
}

public extension PrimitiveSequenceType where Trait == MaybeTrait {
    /**
     Invokes an action for each event in the observable sequence, and propagates all observer messages through the result sequence.

     - seealso: [do operator on reactivex.io](http://reactivex.io/documentation/operators/do.html)

     - parameter onNext: Action to invoke for each element in the observable sequence.
     - parameter afterNext: Action to invoke for each element after the observable has passed an onNext event along to its downstream.
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
        onNext: (@Sendable (Element) throws -> Void)? = nil,
        afterNext: (@Sendable (Element) throws -> Void)? = nil,
        onError: (@Sendable (Swift.Error) throws -> Void)? = nil,
        afterError: (@Sendable (Swift.Error) throws -> Void)? = nil,
        onCompleted: (@Sendable () throws -> Void)? = nil,
        afterCompleted: (@Sendable () throws -> Void)? = nil,
        onSubscribe: (@Sendable () -> Void)? = nil,
        onSubscribed: (@Sendable () -> Void)? = nil,
        onDispose: (@Sendable () -> Void)? = nil
    )
        -> Maybe<Element> {
        Maybe(
            raw: primitiveSequence.source.do(
                onNext: onNext,
                afterNext: afterNext,
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
     Filters the elements of an observable sequence based on a predicate.

     - seealso: [filter operator on reactivex.io](http://reactivex.io/documentation/operators/filter.html)

     - parameter predicate: A function to test each source element for a condition.
     - returns: An observable sequence that contains elements from the input sequence that satisfy the condition.
     */
    func filter(_ predicate: @Sendable @escaping (Element) throws -> Bool)
        -> Maybe<Element> {
        Maybe(raw: primitiveSequence.source.filter(predicate))
    }

    /**
     Projects each element of an observable sequence into a new form.

     - seealso: [map operator on reactivex.io](http://reactivex.io/documentation/operators/map.html)

     - parameter transform: A transform function to apply to each source element.
     - returns: An observable sequence whose elements are the result of invoking the transform function on each element of source.

     */
    func map<Result: Sendable>(_ transform: @Sendable @escaping (Element) throws -> Result)
        -> Maybe<Result> {
        Maybe(raw: primitiveSequence.source.map(transform))
    }

    /**
     Projects each element of an observable sequence into an optional form and filters all optional results.

     - parameter transform: A transform function to apply to each source element.
     - returns: An observable sequence whose elements are the result of filtering the transform function for each element of the source.

     */
    func compactMap<Result: Sendable>(_ transform: @Sendable @escaping (Element) throws -> Result?)
        -> Maybe<Result> {
        Maybe(raw: primitiveSequence.source.compactMap(transform))
    }

    /**
     Projects each element of an observable sequence to an observable sequence and merges the resulting observable sequences into one observable sequence.

     - seealso: [flatMap operator on reactivex.io](http://reactivex.io/documentation/operators/flatmap.html)

     - parameter selector: A transform function to apply to each element.
     - returns: An observable sequence whose elements are the result of invoking the one-to-many transform function on each element of the input sequence.
     */
    func flatMap<Result: Sendable>(_ selector: @Sendable @escaping (Element) throws -> Maybe<Result>)
        -> Maybe<Result> {
        Maybe<Result>(raw: primitiveSequence.source.flatMap(selector))
    }

    /**
     Emits elements from the source observable sequence, or a default element if the source observable sequence is empty.

     - seealso: [DefaultIfEmpty operator on reactivex.io](http://reactivex.io/documentation/operators/defaultifempty.html)

     - parameter default: Default element to be sent if the source does not emit any elements
     - returns: An observable sequence which emits default element end completes in case the original sequence is empty
     */
    func ifEmpty(default: Element) -> Single<Element> {
        Single(raw: primitiveSequence.source.ifEmpty(default: `default`))
    }

    /**
     Returns the elements of the specified sequence or `other` sequence if the sequence is empty.

     - seealso: [DefaultIfEmpty operator on reactivex.io](http://reactivex.io/documentation/operators/defaultifempty.html)

     - parameter other: Observable sequence being returned when source sequence is empty.
     - returns: Observable sequence that contains elements from switchTo sequence if source is empty, otherwise returns source sequence elements.
     */
    func ifEmpty(switchTo other: Maybe<Element>) -> Maybe<Element> {
        Maybe(raw: primitiveSequence.source.ifEmpty(switchTo: other.primitiveSequence.source))
    }

    /**
     Returns the elements of the specified sequence or `other` sequence if the sequence is empty.

     - seealso: [DefaultIfEmpty operator on reactivex.io](http://reactivex.io/documentation/operators/defaultifempty.html)

     - parameter other: Observable sequence being returned when source sequence is empty.
     - returns: Observable sequence that contains elements from switchTo sequence if source is empty, otherwise returns source sequence elements.
     */
    func ifEmpty(switchTo other: Single<Element>) -> Single<Element> {
        Single(raw: primitiveSequence.source.ifEmpty(switchTo: other.primitiveSequence.source))
    }

    /**
     Continues an observable sequence that is terminated by an error with a single element.

     - seealso: [catch operator on reactivex.io](http://reactivex.io/documentation/operators/catch.html)

     - parameter element: Last element in an observable sequence in case error occurs.
     - returns: An observable sequence containing the source sequence's elements, followed by the `element` in case an error occurred.
     */
    func catchAndReturn(_ element: Element)
        -> PrimitiveSequence<Trait, Element> {
        PrimitiveSequence(raw: primitiveSequence.source.catchAndReturn(element))
    }
}
