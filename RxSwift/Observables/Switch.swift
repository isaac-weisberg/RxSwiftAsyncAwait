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
//    func flatMapLatest<Source: ObservableConvertibleType>(_ selector: @escaping (Element) async throws -> Source)
//    async
//        -> Observable<Source.Element> {
//        await FlatMapLatest(source: asObservable(), selector: selector)
//    }

    /**
     Projects each element of an observable sequence into a new sequence of observable sequences and then
     transforms an observable sequence of observable sequences into an observable sequence producing values only from the most recent observable sequence.

     It is a combination of `map` + `switchLatest` operator

     - seealso: [flatMapLatest operator on reactivex.io](http://reactivex.io/documentation/operators/flatmap.html)

     - parameter selector: A transform function to apply to each element.
     - returns: An observable sequence whose elements are the result of invoking the transform function on each element of source producing an
     Observable of Observable sequences and that at any point in time produces the elements of the most recent inner observable sequence that has been received.
     */
//    func flatMapLatest<Source: InfallibleType>(_ selector: @escaping (Element) throws -> Source) async
//        -> Infallible<Source.Element> {
//        await Infallible(flatMapLatest(selector))
//    }
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
//    func switchLatest() async -> Observable<Element.Element> {
//        await Switch(source: asObservable())
//    }
}

private actor SwitchSink<SourceType, Source: ObservableConvertibleType, Observer: ObserverType>:
    Sink,
    ObserverType where Source.Element == Observer.Element {

    typealias Element = SourceType

    private let subscriptions: SingleAssignmentDisposable
    private let innerSubscription: SerialDisposable
    let baseSink: BaseSink<Observer>
    // state
    fileprivate var stopped = false
    fileprivate var latest = 0
    fileprivate var hasLatest = false

    func setHasLatest(_ hasLatest: Bool) {
        self.hasLatest = hasLatest
    }

    init(observer: Observer) async {
        subscriptions = await SingleAssignmentDisposable()
        innerSubscription = await SerialDisposable()
        baseSink = BaseSink(observer: observer)
    }

    func run(_ source: Observable<SourceType>, _ c: C) async -> Disposable {
        let subscription = await source.subscribe(c.call(), self)
        await subscriptions.setDisposable(subscription)
        return await Disposables.create(subscriptions, innerSubscription)
    }

    func performMap(_ element: SourceType) async throws -> Source {
        rxAbstractMethod()
    }

    @inline(__always)
    private final func nextElementArrived(element: Element, _ c: C) async -> (Int, Observable<Source.Element>)? {
        do {
            let observable = try await performMap(element).asObservable()
            hasLatest = true
            latest = latest &+ 1
            return (latest, observable)
        } catch {
            await forwardOn(.error(error), c.call())
            await dispose()
        }

        return nil
    }

    func on(_ event: Event<Element>, _ c: C) async {
        switch event {
        case .next(let element):
            if let (latest, observable) = await nextElementArrived(element: element, c.call()) {
                let d = await SingleAssignmentDisposable()
                await innerSubscription.setDisposable(d)

                let observer = SwitchSinkIter(parent: self, id: latest, this: d)
                let disposable = await observable.subscribe(c.call(), observer)
                await d.setDisposable(disposable)
            }

        case .error(let error):
            await forwardOn(.error(error), c.call())
            await dispose()

        case .completed:
            stopped = true

            await subscriptions.dispose()

            if !hasLatest {
                await forwardOn(.completed, c.call())
                await dispose()
            }
        }
    }
}

private final actor SwitchSinkIter<SourceType, Source: ObservableConvertibleType, Observer: ObserverType>:
    ObserverType,
    AsynchronousOnType where Source.Element == Observer.Element {
    typealias Element = Source.Element
    typealias Parent = SwitchSink<SourceType, Source, Observer>

    private let parent: Parent
    private let id: Int
    private let this: Disposable

    init(parent: Parent, id: Int, this: Disposable) {
        self.parent = parent
        self.id = id
        self.this = this
    }

    func on(_ event: Event<Element>, _ c: C) async {
        await AsynchronousOn(event, c.call())
    }

    func Asynchronous_on(_ event: Event<Element>, _ c: C) async {
        switch event {
        case .next: break
        case .error, .completed:
            await this.dispose()
        }

        if await parent.latest != id {
            return
        }

        switch event {
        case .next:
            await parent.forwardOn(event, c.call())
        case .error:
            await parent.forwardOn(event, c.call())
            await parent.dispose()
        case .completed:
            await parent.setHasLatest(false)
            if await parent.stopped {
                await parent.forwardOn(event, c.call())
                await parent.dispose()
            }
        }
    }
}

// MARK: Specializations

// private final actor SwitchIdentitySink<Source: ObservableConvertibleType, Observer: ObserverType>: SwitchSink<
//    Source,
//    Source,
//    Observer
// >
//    where Observer.Element == Source.Element {
//    override init(observer: Observer) async {
//        baseSink = BaseSink(observer: observer)
//    }
//
//    override func performMap(_ element: Source) async throws -> Source {
//        element
//    }
// }

// private final actor MapSwitchSink<SourceType, Source: ObservableConvertibleType, Observer: ObserverType>: SwitchSink<
//    SourceType,
//    Source,
//    Observer
// > where Observer.Element == Source.Element {
//    typealias Selector = (SourceType) async throws -> Source
//
//    private let selector: Selector
//
//    init(selector: @escaping Selector, observer: Observer) async {
//        self.selector = selector
//        baseSink = BaseSink(observer: observer)
//    }
//
//    override func performMap(_ element: SourceType) async throws -> Source {
//        try await selector(element)
//    }
// }

// MARK: Producers

// private final class Switch<Source: ObservableConvertibleType>: Producer<Source.Element> {
//    private let source: Observable<Source>
//
//    init(source: Observable<Source>) async {
//        self.source = source
//        await super.init()
//    }
//
//    override func run<Observer: ObserverType>(
//        _ c: C,
//        _ observer: Observer,
//        cancel: Cancelable
//    )
//        async -> (sink: Disposable, subscription: Disposable)
//        where Observer.Element == Source.Element {
//        let sink = await SwitchIdentitySink<Source, Observer>(observer: observer)
//        let subscription = await sink.run(source, c.call())
//        return sink
//    }
// }

// private final class FlatMapLatest<SourceType, Source: ObservableConvertibleType>: Producer<Source.Element> {
//    typealias Selector = (SourceType) async throws -> Source
//
//    private let source: Observable<SourceType>
//    private let selector: Selector
//
//    init(source: Observable<SourceType>, selector: @escaping Selector) async {
//        self.source = source
//        self.selector = selector
//        await super.init()
//    }
//
//    override func run<Observer: ObserverType>(
//        _ c: C,
//        _ observer: Observer,
//        cancel: Cancelable
//    )
//        async -> (sink: Disposable, subscription: Disposable)
//        where Observer.Element == Source.Element {
//        let sink = await MapSwitchSink<SourceType, Source, Observer>(
//            selector: selector,
//            observer: observer,
//            cancel: cancel
//        )
//        let subscription = await sink.run(source, c.call())
//        return sink
//    }
// }
