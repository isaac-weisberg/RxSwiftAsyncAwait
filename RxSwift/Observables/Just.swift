//
//  Just.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 8/30/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

public extension ObservableType {
    /**
     Returns an observable sequence that contains a single element.

     - seealso: [just operator on reactivex.io](http://reactivex.io/documentation/operators/just.html)

     - parameter element: Single element in the resulting observable sequence.
     - returns: An observable sequence containing the single specified element.
     */
    static func just(_ element: Element) -> Observable<Element> {
        Just(element: element)
    }

    /**
     Returns an observable sequence that contains a single element.

     - seealso: [just operator on reactivex.io](http://reactivex.io/documentation/operators/just.html)

     - parameter element: Single element in the resulting observable sequence.
     - parameter scheduler: Scheduler to send the single element on.
     - returns: An observable sequence containing the single specified element.
     */
    static func just(_ element: Element, scheduler: any AsyncScheduler) -> Observable<Element> {
        just(element)
            .assumeSyncAndReemitAll(on: scheduler, predictedEventCount: 2)
    }

    static func just(
        _ element: Element,
        scheduler: MainLegacySchedulerProtocol
    )
        -> AssumeSyncAndReemitAllOnMainScheduler<Observable<Element>> {
        just(element)
            .assumeSyncAndReemitAll(on: scheduler, predictedEventCount: 2)
    }
}

private final class Just<Element: Sendable>: Observable<Element> {
    private let element: Element

    init(element: Element) {
        self.element = element
        super.init()
    }

    override func subscribe<Observer>(_ c: C, _ observer: Observer) async -> any Disposable
        where Element == Observer.Element, Observer: ObserverType {
        await observer.on(.next(element), c.call())
        await observer.on(.completed, c.call())
        return Disposables.create()
    }
}

extension ObservableType {
    func assumeSyncAndReemitAll(
        on scheduler: AsyncScheduler,
        predictedEventCount: Int
    ) -> Observable<Element> {
        AssumeSyncAndReemitAllOnAsyncScheduler<Self>(
            self,
            scheduler,
            predictedEventCount: predictedEventCount
        )
    }
}

final class AssumeSyncAndReemitAllOnAsyncScheduler<
    Source: ObservableType
>: Observable<Source.Element> {
    let source: Source
    let predictedEventCount: Int
    let scheduler: AsyncScheduler

    init(_ source: Source, _ scheduler: AsyncScheduler, predictedEventCount: Int) {
        self.source = source
        self.scheduler = scheduler
        self.predictedEventCount = predictedEventCount
    }

    override func subscribe<Observer>(_ c: C, _ observer: Observer) async -> any Disposable
        where Element == Observer.Element, Observer: ObserverType {
        let sink = AssumeSyncAndReemitAllOnAsyncSchedulerSink(
            source,
            predictedEventCount: predictedEventCount,
            scheduler,
            observer
        )
        await sink.run(c.call())
        return sink
    }
}

final actor AssumeSyncAndReemitAllOnAsyncSchedulerSink<
    Source: ObservableType,
    Observer: ObserverType
>: Sink, ObserverType, Disposable where Observer.Element == Source.Element {
    typealias Element = Source.Element

    let source: Source
    let predictedEventCount: Int
    let scheduler: AsyncScheduler
    let baseSink: BaseSink<Observer>
    var events: [Event<Element>]

    let scheduleDisposable = SingleAssignmentSyncDisposable()

    init(_ source: Source, predictedEventCount: Int, _ scheduler: AsyncScheduler, _ observer: Observer) {
        self.source = source
        self.predictedEventCount = predictedEventCount
        self.scheduler = scheduler
        baseSink = BaseSink(observer: observer)
        events = []

        events.reserveCapacity(predictedEventCount)
    }

    func run(_ c: C) async {
        await source.subscribe(c.call(), self).dispose()

        let events = events
        assert(events.last?.isStopEvent == true)

        let disposeAction = scheduler.perform(c.call()) { c in
            for event in events {
                await self.forwardOn(event, c.call())
            }
        }

        scheduleDisposable.setDisposable(disposeAction)?.dispose()
    }

    func on(_ event: Event<Element>, _ c: C) async {
        events.append(event)
    }

    func dispose() async {
        baseSink.setDisposed()
        scheduleDisposable.dispose()?.dispose()
    }
}

extension ObservableType {
    func assumeSyncAndReemitAll(
        on scheduler: MainLegacySchedulerProtocol,
        predictedEventCount: Int
    ) -> AssumeSyncAndReemitAllOnMainScheduler<Self> {
        AssumeSyncAndReemitAllOnMainScheduler<Self>(
            self,
            scheduler,
            predictedEventCount: predictedEventCount
        )
    }
}

public final class AssumeSyncAndReemitAllOnMainScheduler<
    Source: ObservableType
>: MainActorObservable {
    public typealias Element = Source.Element

    let source: Source
    let predictedEventCount: Int
    let scheduler: MainLegacySchedulerProtocol

    init(_ source: Source, _ scheduler: MainLegacySchedulerProtocol, predictedEventCount: Int) {
        self.source = source
        self.scheduler = scheduler
        self.predictedEventCount = predictedEventCount
    }

    public func subscribe<Observer>(_ c: C, _ observer: Observer) async -> any Disposable
        where Observer: MainActorObserverType,
        Element == Observer.Element {
        let sink = AssumeSyncAndReemitAllOnMainSchedulerSink(
            source,
            predictedEventCount: predictedEventCount,
            scheduler,
            observer
        )
        await sink.run(c.call())
        return sink
    }
}

final actor AssumeSyncAndReemitAllOnMainSchedulerSink<
    Source: ObservableType,
    Observer: MainActorObserverType
>: ObserverType, Disposable where Observer.Element == Source.Element {
    typealias Element = Source.Element

    let source: Source
    let predictedEventCount: Int
    let scheduler: MainLegacySchedulerProtocol
    let observer: Observer
    var events: [Event<Element>]
    var disposed = false

    init(_ source: Source, predictedEventCount: Int, _ scheduler: MainLegacySchedulerProtocol, _ observer: Observer) {
        self.source = source
        self.predictedEventCount = predictedEventCount
        self.scheduler = scheduler
        self.observer = observer
        events = []

        events.reserveCapacity(predictedEventCount)
    }

    func run(_ c: C) async {
        await source.subscribe(c.call(), self).dispose()

        let events = events
        assert(events.last?.isStopEvent == true)

        await scheduler.perform(c.call()) { c in
            if await disposed {
                return
            }
            for event in events {
                await self.observer.on(event, c.call())
            }
        }
    }

    func on(_ event: Event<Element>, _ c: C) async {
        events.append(event)
    }

    func dispose() async {
        disposed = true
    }
}
