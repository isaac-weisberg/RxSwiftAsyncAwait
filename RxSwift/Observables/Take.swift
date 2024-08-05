//
//  Take.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 6/12/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

import Foundation

public extension ObservableType {
    /**
     Returns a specified number of contiguous elements from the start of an observable sequence.

     - seealso: [take operator on reactivex.io](http://reactivex.io/documentation/operators/take.html)

     - parameter count: The number of elements to return.
     - returns: An observable sequence that contains the specified number of elements from the start of the input sequence.
     */
    func take(_ count: Int) async
        -> Observable<Element> {
        if count == 0 {
            return await Observable.empty()
        } else {
            return await TakeCount(source: asObservable(), count: count)
        }
    }
}

public extension ObservableType {
    /**
     Takes elements for the specified duration from the start of the observable source sequence, using the specified scheduler to run timers.

     - seealso: [take operator on reactivex.io](http://reactivex.io/documentation/operators/take.html)

     - parameter duration: Duration for taking elements from the start of the sequence.
     - parameter scheduler: Scheduler to run the timer on.
     - returns: An observable sequence with the elements taken during the specified duration from the start of the source sequence.
     */
    func take(for duration: RxTimeInterval, scheduler: SchedulerType) async
        -> Observable<Element> {
        await TakeTime(source: asObservable(), duration: duration, scheduler: scheduler)
    }

    /**
     Takes elements for the specified duration from the start of the observable source sequence, using the specified scheduler to run timers.

     - seealso: [take operator on reactivex.io](http://reactivex.io/documentation/operators/take.html)

     - parameter duration: Duration for taking elements from the start of the sequence.
     - parameter scheduler: Scheduler to run the timer on.
     - returns: An observable sequence with the elements taken during the specified duration from the start of the source sequence.
     */
    @available(*, deprecated, renamed: "take(for:scheduler:)")
    func take(_ duration: RxTimeInterval, scheduler: SchedulerType) async
        -> Observable<Element> {
        await take(for: duration, scheduler: scheduler)
    }
}

// count version

private final actor TakeCountSink<Observer: ObserverType>: Sink, ObserverType {
    let baseSink: BaseSink<Observer>

    typealias Element = Observer.Element
    typealias Parent = TakeCount<Element>

    private let parent: Parent

    private var remaining: Int

    init(parent: Parent, observer: Observer) async {
        self.parent = parent
        remaining = parent.count
        baseSink = BaseSink(observer: observer)
    }

    func on(_ event: Event<Element>, _ c: C) async {
        switch event {
        case .next(let value):

            if remaining > 0 {
                remaining -= 1

                await forwardOn(.next(value), c.call())

                if remaining == 0 {
                    await forwardOn(.completed, c.call())
                    await dispose()
                }
            }
        case .error:
            await forwardOn(event, c.call())
            await dispose()
        case .completed:
            await forwardOn(event, c.call())
            await dispose()
        }
    }
}

private final class TakeCount<Element>: Producer<Element> {
    private let source: Observable<Element>
    fileprivate let count: Int

    init(source: Observable<Element>, count: Int) async {
        if count < 0 {
            rxFatalError("count can't be negative")
        }
        self.source = source
        self.count = count
        await super.init()
    }

    override func run<Observer: ObserverType>(
        _ c: C,
        _ observer: Observer
    )
        async -> SynchronizedDisposable where Observer.Element == Element {
        let sink = await TakeCountSink(parent: self, observer: observer)
        let subscription = await source.subscribe(c.call(), sink)
        return sink
    }
}

// time version

private final actor TakeTimeSink<Element, Observer: ObserverType>:
    Sink,
    ObserverType,
    SynchronizedOnType where Observer.Element == Element {
    let baseSink: BaseSink<Observer>

    typealias Parent = TakeTime<Element>

    private let parent: Parent

    init(parent: Parent, observer: Observer) async {
        self.parent = parent
        baseSink = BaseSink(observer: observer)
    }

    func on(_ event: Event<Element>, _ c: C) async {
        await synchronizedOn(event, c.call())
    }

    func synchronized_on(_ event: Event<Element>, _ c: C) async {
        switch event {
        case .next(let value):
            await forwardOn(.next(value), c.call())
        case .error:
            await forwardOn(event, c.call())
            await dispose()
        case .completed:
            await forwardOn(event, c.call())
            await dispose()
        }
    }

    func tick(_ c: C) async {
        await forwardOn(.completed, c.call())
        await dispose()
    }

    func run(_ c: C) async -> Disposable {
        let disposeTimer = await parent.scheduler.scheduleRelative((), c.call(), dueTime: parent.duration) { c, _ in
            await self.tick(c.call())
            return Disposables.create()
        }

        let disposeSubscription = await parent.source.subscribe(c.call(), self)

        return await Disposables.create(disposeTimer, disposeSubscription)
    }
}

private final class TakeTime<Element>: Producer<Element> {
    typealias TimeInterval = RxTimeInterval

    fileprivate let source: Observable<Element>
    fileprivate let duration: TimeInterval
    fileprivate let scheduler: SchedulerType

    init(source: Observable<Element>, duration: TimeInterval, scheduler: SchedulerType) async {
        self.source = source
        self.scheduler = scheduler
        self.duration = duration
        await super.init()
    }

    override func run<Observer: ObserverType>(
        _ c: C,
        _ observer: Observer
    )
        async -> SynchronizedDisposable where Observer.Element == Element {
        let sink = await TakeTimeSink(parent: self, observer: observer)
        let subscription = await sink.run(c.call())
        return sink
    }
}
