//
//  TakeWithPredicate.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 6/7/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

public extension ObservableType {
    /**
     Returns the elements from the source observable sequence until the other observable sequence produces an element.

     - seealso: [takeUntil operator on reactivex.io](http://reactivex.io/documentation/operators/takeuntil.html)

     - parameter other: Observable sequence that terminates propagation of elements of the source sequence.
     - returns: An observable sequence containing the elements of the source sequence up to the point the other sequence interrupted further propagation.
     */
    func take(until other: some ObservableType)
        -> Observable<Element> {
        TakeUntil(source: asObservable(), other: other.asObservable())
    }

    /**
     Returns elements from an observable sequence until the specified condition is true.

     - seealso: [takeUntil operator on reactivex.io](http://reactivex.io/documentation/operators/takeuntil.html)

     - parameter predicate: A function to test each element for a condition.
     - parameter behavior: Whether or not to include the last element matching the predicate. Defaults to `exclusive`.

     - returns: An observable sequence that contains the elements from the input sequence that occur before the element at which the test passes.
     */
    func take(
        until predicate: @escaping (Element) throws -> Bool,
        behavior: TakeBehavior = .exclusive
    ) -> Observable<Element> {
        TakeUntilPredicate(
            source: asObservable(),
            behavior: behavior,
            predicate: predicate
        )
    }

    /**
     Returns elements from an observable sequence as long as a specified condition is true.

     - seealso: [takeWhile operator on reactivex.io](http://reactivex.io/documentation/operators/takewhile.html)

     - parameter predicate: A function to test each element for a condition.
     - returns: An observable sequence that contains the elements from the input sequence that occur before the element at which the test no longer passes.
     */
    func take(
        while predicate: @escaping (Element) throws -> Bool,
        behavior: TakeBehavior = .exclusive
    )
        -> Observable<Element> {
        take(until: { try !predicate($0) }, behavior: behavior)
    }

    /**
     Returns the elements from the source observable sequence until the other observable sequence produces an element.

     - seealso: [takeUntil operator on reactivex.io](http://reactivex.io/documentation/operators/takeuntil.html)

     - parameter other: Observable sequence that terminates propagation of elements of the source sequence.
     - returns: An observable sequence containing the elements of the source sequence up to the point the other sequence interrupted further propagation.
     */
    @available(*, deprecated, renamed: "take(until:)")
    func takeUntil(_ other: some ObservableType)
        -> Observable<Element> {
        take(until: other)
    }

    /**
     Returns elements from an observable sequence until the specified condition is true.

     - seealso: [takeUntil operator on reactivex.io](http://reactivex.io/documentation/operators/takeuntil.html)

     - parameter behavior: Whether or not to include the last element matching the predicate.
     - parameter predicate: A function to test each element for a condition.
     - returns: An observable sequence that contains the elements from the input sequence that occur before the element at which the test passes.
     */
    @available(*, deprecated, renamed: "take(until:behavior:)")
    func takeUntil(
        _ behavior: TakeBehavior,
        predicate: @escaping (Element) throws -> Bool
    ) -> Observable<Element> {
        take(until: predicate, behavior: behavior)
    }

    /**
     Returns elements from an observable sequence as long as a specified condition is true.

     - seealso: [takeWhile operator on reactivex.io](http://reactivex.io/documentation/operators/takewhile.html)

     - parameter predicate: A function to test each element for a condition.
     - returns: An observable sequence that contains the elements from the input sequence that occur before the element at which the test no longer passes.
     */
    @available(*, deprecated, renamed: "take(while:)")
    func takeWhile(_ predicate: @escaping (Element) throws -> Bool)
        -> Observable<Element> {
        take(until: { try !predicate($0) }, behavior: .exclusive)
    }
}

/// Behaviors for the take operator family.
public enum TakeBehavior {
    /// Include the last element matching the predicate.
    case inclusive

    /// Exclude the last element matching the predicate.
    case exclusive
}

// MARK: - TakeUntil Observable

protocol TakeUntilSinkOtherDelegate: Sendable {
    associatedtype Other: Sendable

    func handleOtherEvent(_ event: Event<Other>, _ c: C) async
}

private final class TakeUntilSinkOther<Delegate: TakeUntilSinkOtherDelegate>: ObserverType {
    typealias Other = Delegate.Other
    typealias Element = Other

    private let delegate: Delegate

    init(delegate: Delegate) {
        self.delegate = delegate
    }

    func on(_ event: Event<Other>, _ c: C) async {
        await delegate.handleOtherEvent(event, c.call())
    }

    #if TRACE_RESOURCES
        deinit {
            Task {
                _ = await Resources.decrementTotal()
            }
        }
    #endif
}

private final actor TakeUntilSink<Other: Sendable, Observer: ObserverType>: Sink, ObserverType,
    TakeUntilSinkOtherDelegate {
    typealias Element = Observer.Element
    typealias Parent = TakeUntil<Element, Other>

    private let parent: Parent
    let baseSink: BaseSink<Observer>
    let sourceSubscription = SingleAssignmentDisposable()
    let otherSubscription = SingleAssignmentDisposable()

    init(parent: Parent, observer: Observer) async {
        self.parent = parent

        baseSink = BaseSink(observer: observer)
    }

    func on(_ event: Event<Element>, _ c: C) async {
        switch event {
        case .next:
            await forwardOn(event, c.call())
        case .error:
            await forwardOn(event, c.call())
            await dispose()
        case .completed:
            await forwardOn(event, c.call())
            await dispose()
        }
    }

    func handleOtherEvent(_ event: Event<Other>, _ c: C) async {
        if baseSink.disposed {
            return
        }
        switch event {
        case .next:
            await forwardOn(.completed, c.call())
            await dispose()
        case .error(let e):
            await forwardOn(.error(e), c.call())
            await dispose()
        case .completed:
            await otherSubscription.dispose()?.dispose()
        }
    }

    func run(_ c: C, source: Observable<Element>, other: Observable<Other>) async {
        let otherObserver = TakeUntilSinkOther(delegate: self)

        await otherSubscription.setDisposable(parent.other.subscribe(c.call(), otherObserver))?.dispose()

        await sourceSubscription.setDisposable(parent.source.subscribe(c.call(), self))?.dispose()
    }

    func dispose() async {
        baseSink.setDisposed()

        async let sourceDisposed: ()? = sourceSubscription.dispose()?.dispose()
        async let otherDisposed: ()? = otherSubscription.dispose()?.dispose()

        await sourceDisposed
        await otherDisposed
    }
}

private final class TakeUntil<Element: Sendable, Other: Sendable>: Producer<Element> {
    fileprivate let source: Observable<Element>
    fileprivate let other: Observable<Other>

    init(source: Observable<Element>, other: Observable<Other>) {
        self.source = source
        self.other = other
        super.init()
    }

    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> AsynchronousDisposable
        where Observer.Element == Element {
        let sink = await TakeUntilSink(parent: self, observer: observer)
        await sink.run(c.call(), source: source, other: other)
        return sink
    }
}

// MARK: - TakeUntil Predicate

private final actor TakeUntilPredicateSink<Observer: ObserverType>:
    SinkOverSingleSubscription, ObserverType {
    typealias Element = Observer.Element
    typealias Parent = TakeUntilPredicate<Element>

    private let parent: Parent
    private var running = true
    let baseSink: BaseSinkOverSingleSubscription<Observer>

    init(parent: Parent, observer: Observer) async {
        self.parent = parent
        baseSink = BaseSinkOverSingleSubscription(observer: observer)
    }

    func on(_ event: Event<Element>, _ c: C) async {
        if baseSink.disposed {
            return
        }

        switch event {
        case .next(let value):
            if !running {
                return
            }

            do {
                running = try !parent.predicate(value)
            } catch let e {
                await self.forwardOn(.error(e), c.call())
                await self.dispose()
                return
            }

            if running {
                await forwardOn(.next(value), c.call())
            } else {
                if parent.behavior == .inclusive {
                    await forwardOn(.next(value), c.call())
                }

                await forwardOn(.completed, c.call())
                await dispose()
            }
        case .error, .completed:
            await forwardOn(event, c.call())
            await dispose()
        }
    }

    func dispose() async {
        await baseSink.setDisposed()?.dispose()
    }
}

private final class TakeUntilPredicate<Element: Sendable>: Producer<Element> {
    typealias Predicate = (Element) throws -> Bool

    private let source: Observable<Element>
    fileprivate let predicate: Predicate
    fileprivate let behavior: TakeBehavior

    init(
        source: Observable<Element>,
        behavior: TakeBehavior,
        predicate: @escaping Predicate
    ) {
        self.source = source
        self.behavior = behavior
        self.predicate = predicate
        super.init()
    }

    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> AsynchronousDisposable
        where Observer.Element == Element {
        let sink = await TakeUntilPredicateSink(parent: self, observer: observer)
        await sink.run(c.call(), source)
        return sink
    }
}
