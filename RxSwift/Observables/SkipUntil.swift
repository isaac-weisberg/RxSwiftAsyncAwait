//
//  SkipUntil.swift
//  RxSwift
//
//  Created by Yury Korolev on 10/3/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

public extension ObservableType {
    /**
     Returns the elements from the source observable sequence that are emitted after the other observable sequence produces an element.

     - seealso: [skipUntil operator on reactivex.io](http://reactivex.io/documentation/operators/skipuntil.html)

     - parameter other: Observable sequence that starts propagation of elements of the source sequence.
     - returns: An observable sequence containing the elements of the source sequence that are emitted after the other sequence emits an item.
     */
    func skip<Source: ObservableType>(until other: Source) async
        -> Observable<Element>
    {
        await SkipUntil(source: self.asObservable(), other: other.asObservable())
    }

    /**
     Returns the elements from the source observable sequence that are emitted after the other observable sequence produces an element.

     - seealso: [skipUntil operator on reactivex.io](http://reactivex.io/documentation/operators/skipuntil.html)

     - parameter other: Observable sequence that starts propagation of elements of the source sequence.
     - returns: An observable sequence containing the elements of the source sequence that are emitted after the other sequence emits an item.
     */
    @available(*, deprecated, renamed: "skip(until:)")
    func skipUntil<Source: ObservableType>(_ other: Source) async
        -> Observable<Element>
    {
        await self.skip(until: other)
    }
}

private final actor SkipUntilSinkOther<Other, Observer: ObserverType>:
    ObserverType,
    SynchronizedOnType
{
    typealias Parent = SkipUntilSink<Other, Observer>
    typealias Element = Other

    private let parent: Parent

    let subscription: SingleAssignmentDisposable

    init(parent: Parent) async {
        self.parent = parent
        self.subscription = await SingleAssignmentDisposable()
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
            await self.parent.setForwardElements(true)
            await self.subscription.dispose()
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

private final actor SkipUntilSink<Other, Observer: ObserverType>:
    Sink,
    ObserverType,
    SynchronizedOnType
{
    typealias Element = Observer.Element
    typealias Parent = SkipUntil<Element, Other>

    private let parent: Parent
    fileprivate var forwardElements = false
    func setForwardElements(_ newValue: Bool) {
        forwardElements = newValue
    }
    let baseSink: BaseSink<Observer>

    private let sourceSubscription: SingleAssignmentDisposable

    init(parent: Parent, observer: Observer) async {
        self.sourceSubscription = await SingleAssignmentDisposable()
        self.parent = parent
        self.baseSink = BaseSink(observer: observer)
    }

    func on(_ event: Event<Element>, _ c: C) async {
        await self.synchronizedOn(event, c.call())
    }

    func synchronized_on(_ event: Event<Element>, _ c: C) async {
        switch event {
        case .next:
            if self.forwardElements {
                await self.forwardOn(event, c.call())
            }
        case .error:
            await self.forwardOn(event, c.call())
            await self.dispose()
        case .completed:
            if self.forwardElements {
                await self.forwardOn(event, c.call())
            }
            await self.dispose()
        }
    }

    func run(_ c: C) async -> Disposable {
        let sourceSubscription = await self.parent.source.subscribe(c.call(), self)
        let otherObserver = await SkipUntilSinkOther(parent: self)
        let otherSubscription = await self.parent.other.subscribe(c.call(), otherObserver)
        await self.sourceSubscription.setDisposable(sourceSubscription)
        await otherObserver.subscription.setDisposable(otherSubscription)

        return await Disposables.create(sourceSubscription, otherObserver.subscription)
    }
}

private final class SkipUntil<Element, Other>: Producer<Element> {
    fileprivate let source: Observable<Element>
    fileprivate let other: Observable<Other>

    init(source: Observable<Element>, other: Observable<Other>) async {
        self.source = source
        self.other = other
        await super.init()
    }

    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> SynchronizedDisposable where Observer.Element == Element {
        let sink = await SkipUntilSink(parent: self, observer: observer)
        let subscription = await sink.run(c.call())
        return sink
    }
}
