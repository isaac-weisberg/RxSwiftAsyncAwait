//
//  Switch.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 3/12/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

public extension ObservableType {
    /**
     Projects each element of an observable sequence into a new sequence of observable sequences and then
     transforms an observable sequence of observable sequences into an observable sequence producing values only from the most recent observable sequence.

     It is a combination of `map` + `switchLatest` operator

     - seealso: [flatMapLatest operator on reactivex.io](http://reactivex.io/documentation/operators/flatmap.html)

     - parameter selector: A transform function to apply to each element.
     - returns: An observable sequence whose elements are the result of invoking the transform function on each element of source producing an
     Observable of Observable sequences and that at any point in time produces the elements of the most recent inner observable sequence that has been received.
     */
    func flatMapLatest<Source: ObservableConvertibleType>(_ selector: @escaping (Element) async throws -> Source) async
        -> Observable<Source.Element>
    {
        return await FlatMapLatest(source: self.asObservable(), selector: selector)
    }

    /**
     Projects each element of an observable sequence into a new sequence of observable sequences and then
     transforms an observable sequence of observable sequences into an observable sequence producing values only from the most recent observable sequence.

     It is a combination of `map` + `switchLatest` operator

     - seealso: [flatMapLatest operator on reactivex.io](http://reactivex.io/documentation/operators/flatmap.html)

     - parameter selector: A transform function to apply to each element.
     - returns: An observable sequence whose elements are the result of invoking the transform function on each element of source producing an
     Observable of Observable sequences and that at any point in time produces the elements of the most recent inner observable sequence that has been received.
     */
    func flatMapLatest<Source: InfallibleType>(_ selector: @escaping (Element) throws -> Source) async
        -> Infallible<Source.Element>
    {
        return await Infallible(self.flatMapLatest(selector))
    }
}

public extension ObservableType where Element: ObservableConvertibleType {
    /**
     Transforms an observable sequence of observable sequences into an observable sequence
     producing values only from the most recent observable sequence.

     Each time a new inner observable sequence is received, unsubscribe from the
     previous inner observable sequence.

     - seealso: [switch operator on reactivex.io](http://reactivex.io/documentation/operators/switch.html)

     - returns: The observable sequence that at any point in time produces the elements of the most recent inner observable sequence that has been received.
     */
    func switchLatest() async -> Observable<Element.Element> {
        await Switch(source: self.asObservable())
    }
}

private class SwitchSink<SourceType, Source: ObservableConvertibleType, Observer: ObserverType>:
    Sink<Observer>,
    ObserverType where Source.Element == Observer.Element
{
    typealias Element = SourceType

    private let subscriptions: SingleAssignmentDisposable
    private let innerSubscription: SerialDisposable

    let lock: RecursiveLock

    // state
    fileprivate var stopped = false
    fileprivate var latest = 0
    fileprivate var hasLatest = false

    override init(observer: Observer, cancel: Cancelable) async {
        self.subscriptions = await SingleAssignmentDisposable()
        self.innerSubscription = await SerialDisposable()
        self.lock = await RecursiveLock()
        await super.init(observer: observer, cancel: cancel)
    }

    func run(_ source: Observable<SourceType>, _ c: C) async -> Disposable {
        let subscription = await source.subscribe(c.call(), self)
        await self.subscriptions.setDisposable(subscription)
        return await Disposables.create(self.subscriptions, self.innerSubscription)
    }

    func performMap(_ element: SourceType) async throws -> Source {
        rxAbstractMethod()
    }

    @inline(__always)
    private final func nextElementArrived(element: Element, _ c: C) async -> (Int, Observable<Source.Element>)? {
        await self.lock.performLocked(c.call()) { c in
            do {
                let observable = try await self.performMap(element).asObservable()
                self.hasLatest = true
                self.latest = self.latest &+ 1
                return (self.latest, observable)
            }
            catch {
                await self.forwardOn(.error(error), c.call())
                await self.dispose()
            }

            return nil
        }
    }

    func on(_ event: Event<Element>, _ c: C) async {
        switch event {
        case .next(let element):
            if let (latest, observable) = await self.nextElementArrived(element: element, c.call()) {
                let d = await SingleAssignmentDisposable()
                await self.innerSubscription.setDisposable(d)

                let observer = SwitchSinkIter(parent: self, id: latest, this: d)
                let disposable = await observable.subscribe(c.call(), observer)
                await d.setDisposable(disposable)
            }
        case .error(let error):
            await self.lock.performLocked(c.call()) { c in
                await self.forwardOn(.error(error), c.call())
                await self.dispose()
            }
        case .completed:
            await self.lock.performLocked(c.call()) { c in
                self.stopped = true

                await self.subscriptions.dispose()

                if !self.hasLatest {
                    await self.forwardOn(.completed, c.call())
                    await self.dispose()
                }
            }
        }
    }
}

private final class SwitchSinkIter<SourceType, Source: ObservableConvertibleType, Observer: ObserverType>:
    ObserverType,
    LockOwnerType,
    SynchronizedOnType where Source.Element == Observer.Element
{
    typealias Element = Source.Element
    typealias Parent = SwitchSink<SourceType, Source, Observer>

    private let parent: Parent
    private let id: Int
    private let this: Disposable

    var lock: RecursiveLock {
        self.parent.lock
    }

    init(parent: Parent, id: Int, this: Disposable) {
        self.parent = parent
        self.id = id
        self.this = this
    }

    func on(_ event: Event<Element>, _ c: C) async {
        await self.synchronizedOn(event, c.call())
    }

    func synchronized_on(_ event: Event<Element>, _ c: C) async {
        switch event {
        case .next: break
        case .error, .completed:
            await self.this.dispose()
        }

        if self.parent.latest != self.id {
            return
        }

        switch event {
        case .next:
            await self.parent.forwardOn(event, c.call())
        case .error:
            await self.parent.forwardOn(event, c.call())
            await self.parent.dispose()
        case .completed:
            self.parent.hasLatest = false
            if self.parent.stopped {
                await self.parent.forwardOn(event, c.call())
                await self.parent.dispose()
            }
        }
    }
}

// MARK: Specializations

private final class SwitchIdentitySink<Source: ObservableConvertibleType, Observer: ObserverType>: SwitchSink<Source, Source, Observer>
    where Observer.Element == Source.Element
{
    override init(observer: Observer, cancel: Cancelable) async {
        await super.init(observer: observer, cancel: cancel)
    }

    override func performMap(_ element: Source) async throws -> Source {
        element
    }
}

private final class MapSwitchSink<SourceType, Source: ObservableConvertibleType, Observer: ObserverType>: SwitchSink<SourceType, Source, Observer> where Observer.Element == Source.Element {
    typealias Selector = (SourceType) async throws -> Source

    private let selector: Selector

    init(selector: @escaping Selector, observer: Observer, cancel: Cancelable) async {
        self.selector = selector
        await super.init(observer: observer, cancel: cancel)
    }

    override func performMap(_ element: SourceType) async throws -> Source {
        try await self.selector(element)
    }
}

// MARK: Producers

private final class Switch<Source: ObservableConvertibleType>: Producer<Source.Element> {
    private let source: Observable<Source>

    init(source: Observable<Source>) async {
        self.source = source
        await super.init()
    }

    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer, cancel: Cancelable) async -> (sink: Disposable, subscription: Disposable) where Observer.Element == Source.Element {
        let sink = await SwitchIdentitySink<Source, Observer>(observer: observer, cancel: cancel)
        let subscription = await sink.run(self.source, c.call())
        return (sink: sink, subscription: subscription)
    }
}

private final class FlatMapLatest<SourceType, Source: ObservableConvertibleType>: Producer<Source.Element> {
    typealias Selector = (SourceType) async throws -> Source

    private let source: Observable<SourceType>
    private let selector: Selector

    init(source: Observable<SourceType>, selector: @escaping Selector) async {
        self.source = source
        self.selector = selector
        await super.init()
    }

    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer, cancel: Cancelable) async -> (sink: Disposable, subscription: Disposable) where Observer.Element == Source.Element {
        let sink = await MapSwitchSink<SourceType, Source, Observer>(selector: self.selector, observer: observer, cancel: cancel)
        let subscription = await sink.run(self.source, c.call())
        return (sink: sink, subscription: subscription)
    }
}
