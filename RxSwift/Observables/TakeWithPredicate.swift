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
    func take<Source: ObservableType>(until other: Source) async
        -> Observable<Element>
    {
        await TakeUntil(source: self.asObservable(), other: other.asObservable())
    }

    /**
     Returns elements from an observable sequence until the specified condition is true.

     - seealso: [takeUntil operator on reactivex.io](http://reactivex.io/documentation/operators/takeuntil.html)

     - parameter predicate: A function to test each element for a condition.
     - parameter behavior: Whether or not to include the last element matching the predicate. Defaults to `exclusive`.

     - returns: An observable sequence that contains the elements from the input sequence that occur before the element at which the test passes.
     */
    func take(until predicate: @escaping (Element) throws -> Bool,
              behavior: TakeBehavior = .exclusive) async
        -> Observable<Element>
    {
        await TakeUntilPredicate(source: self.asObservable(),
                           behavior: behavior,
                           predicate: predicate)
    }

    /**
     Returns elements from an observable sequence as long as a specified condition is true.

     - seealso: [takeWhile operator on reactivex.io](http://reactivex.io/documentation/operators/takewhile.html)

     - parameter predicate: A function to test each element for a condition.
     - returns: An observable sequence that contains the elements from the input sequence that occur before the element at which the test no longer passes.
     */
    func take(while predicate: @escaping (Element) throws -> Bool,
              behavior: TakeBehavior = .exclusive) async
        -> Observable<Element>
    {
        await self.take(until: { try !predicate($0) }, behavior: behavior)
    }

    /**
     Returns the elements from the source observable sequence until the other observable sequence produces an element.

     - seealso: [takeUntil operator on reactivex.io](http://reactivex.io/documentation/operators/takeuntil.html)

     - parameter other: Observable sequence that terminates propagation of elements of the source sequence.
     - returns: An observable sequence containing the elements of the source sequence up to the point the other sequence interrupted further propagation.
     */
    @available(*, deprecated, renamed: "take(until:)")
    func takeUntil<Source: ObservableType>(_ other: Source) async
        -> Observable<Element>
    {
        await self.take(until: other)
    }

    /**
     Returns elements from an observable sequence until the specified condition is true.

     - seealso: [takeUntil operator on reactivex.io](http://reactivex.io/documentation/operators/takeuntil.html)

     - parameter behavior: Whether or not to include the last element matching the predicate.
     - parameter predicate: A function to test each element for a condition.
     - returns: An observable sequence that contains the elements from the input sequence that occur before the element at which the test passes.
     */
    @available(*, deprecated, renamed: "take(until:behavior:)")
    func takeUntil(_ behavior: TakeBehavior,
                   predicate: @escaping (Element) throws -> Bool) async
        -> Observable<Element>
    {
        await self.take(until: predicate, behavior: behavior)
    }

    /**
     Returns elements from an observable sequence as long as a specified condition is true.

     - seealso: [takeWhile operator on reactivex.io](http://reactivex.io/documentation/operators/takewhile.html)

     - parameter predicate: A function to test each element for a condition.
     - returns: An observable sequence that contains the elements from the input sequence that occur before the element at which the test no longer passes.
     */
    @available(*, deprecated, renamed: "take(while:)")
    func takeWhile(_ predicate: @escaping (Element) throws -> Bool) async
        -> Observable<Element>
    {
        await self.take(until: { try !predicate($0) }, behavior: .exclusive)
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

private final actor TakeUntilSinkOther<Other, Observer: ObserverType>:
    ObserverType,
    SynchronizedOnType
{
    typealias Parent = TakeUntilSink<Other, Observer>
    typealias Element = Other

    private let parent: Parent

    fileprivate let subscription: SingleAssignmentDisposable

    init(parent: Parent) async {
        self.subscription = await SingleAssignmentDisposable()
        self.parent = parent
#if TRACE_RESOURCES
        _ = await Resources.incrementTotal()
#endif
    }

    func on(_ event: Event<Element>, _ c: C) async {
        await self.synchronizedOn(event, c.call())
    }

    func synchronized_on(_ event: Event<Element>, _ c: C) async {
        switch event {
        case .next:
            await self.parent.forwardOn(.completed, c.call())
            await self.parent.dispose()
        case .error(let e):
            await self.parent.forwardOn(.error(e), c.call())
            await self.parent.dispose()
        case .completed:
            await self.subscription.dispose()
        }
    }

#if TRACE_RESOURCES
    deinit {
        Task {
            _ = await Resources.decrementTotal()
        }
    }
#endif
}

private final actor TakeUntilSink<Other, Observer: ObserverType>:
    Sink,
    ObserverType,
    SynchronizedOnType
{
    typealias Element = Observer.Element
    typealias Parent = TakeUntil<Element, Other>

    private let parent: Parent
    let baseSink: BaseSink<Observer>

    init(parent: Parent, observer: Observer, cancel: SynchronizedCancelable) async {
        self.parent = parent
        
        self.baseSink = await BaseSink(observer: observer, cancel: cancel)
    }

    func on(_ event: Event<Element>, _ c: C) async {
        await self.synchronizedOn(event, c.call())
    }

    func synchronized_on(_ event: Event<Element>, _ c: C) async {
        switch event {
        case .next:
            await self.forwardOn(event, c.call())
        case .error:
            await self.forwardOn(event, c.call())
            await self.dispose()
        case .completed:
            await self.forwardOn(event, c.call())
            await self.dispose()
        }
    }

    func run(_ c: C) async -> Disposable {
        let otherObserver = await TakeUntilSinkOther(parent: self)
        let otherSubscription = await self.parent.other.subscribe(c.call(), otherObserver)
        await otherObserver.subscription.setDisposable(otherSubscription)
        let sourceSubscription = await self.parent.source.subscribe(c.call(), self)

        return await Disposables.create(sourceSubscription, otherObserver.subscription)
    }
}

private final class TakeUntil<Element, Other>: Producer<Element> {
    fileprivate let source: Observable<Element>
    fileprivate let other: Observable<Other>

    init(source: Observable<Element>, other: Observable<Other>) async {
        self.source = source
        self.other = other
        await super.init()
    }

    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer, cancel: SynchronizedCancelable) async -> (sink: SynchronizedDisposable, subscription: SynchronizedDisposable) where Observer.Element == Element {
        let sink = await TakeUntilSink(parent: self, observer: observer, cancel: cancel)
        let subscription = await sink.run(c.call())
        return (sink: sink, subscription: subscription)
    }
}

// MARK: - TakeUntil Predicate

private final actor TakeUntilPredicateSink<Observer: ObserverType>:
    Sink, ObserverType
{
    typealias Element = Observer.Element
    typealias Parent = TakeUntilPredicate<Element>

    private let parent: Parent
    private var running = true
    let baseSink: BaseSink<Observer>

    init(parent: Parent, observer: Observer, cancel: SynchronizedCancelable) async {
        self.parent = parent
        self.baseSink = await BaseSink(observer: observer, cancel: cancel)
    }

    func on(_ event: Event<Element>, _ c: C) async {
        switch event {
        case .next(let value):
            if !self.running {
                return
            }

            do {
                self.running = try !self.parent.predicate(value)
            } catch let e {
                await self.forwardOn(.error(e), c.call())
                await self.dispose()
                return
            }

            if self.running {
                await self.forwardOn(.next(value), c.call())
            } else {
                if self.parent.behavior == .inclusive {
                    await self.forwardOn(.next(value), c.call())
                }

                await self.forwardOn(.completed, c.call())
                await self.dispose()
            }
        case .error, .completed:
            await self.forwardOn(event, c.call())
            await self.dispose()
        }
    }
}

private final class TakeUntilPredicate<Element>: Producer<Element> {
    typealias Predicate = (Element) throws -> Bool

    private let source: Observable<Element>
    fileprivate let predicate: Predicate
    fileprivate let behavior: TakeBehavior

    init(source: Observable<Element>,
         behavior: TakeBehavior,
         predicate: @escaping Predicate) async
    {
        self.source = source
        self.behavior = behavior
        self.predicate = predicate
        await super.init()
    }

    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer, cancel: SynchronizedCancelable) async -> (sink: SynchronizedDisposable, subscription: SynchronizedDisposable) where Observer.Element == Element {
        let sink = await TakeUntilPredicateSink(parent: self, observer: observer, cancel: cancel)
        let subscription = await self.source.subscribe(c.call(), sink)
        return (sink: sink, subscription: subscription)
    }
}
