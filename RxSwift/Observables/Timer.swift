//
//  Timer.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 6/7/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

public extension ObservableType where Element: RxAbstractInteger {
    /**
     Returns an observable sequence that produces a value after each period, using the specified scheduler to run timers and to send out observer messages.

     - seealso: [interval operator on reactivex.io](http://reactivex.io/documentation/operators/interval.html)

     - parameter period: Period for producing the values in the resulting sequence.
     - parameter scheduler: Scheduler to run the timer on.
     - returns: An observable sequence that produces a value after each period.
     */
    static func interval(_ period: RxTimeInterval, scheduler: SchedulerType) async
        -> Observable<Element> {
        await Timer(
            dueTime: period,
            period: period,
            scheduler: scheduler
        )
    }
}

public extension ObservableType where Element: RxAbstractInteger {
    /**
     Returns an observable sequence that periodically produces a value after the specified initial relative due time has elapsed, using the specified scheduler to run timers.

     - seealso: [timer operator on reactivex.io](http://reactivex.io/documentation/operators/timer.html)

     - parameter dueTime: Relative time at which to produce the first value.
     - parameter period: Period to produce subsequent values.
     - parameter scheduler: Scheduler to run timers on.
     - returns: An observable sequence that produces a value after due time has elapsed and then each period.
     */
    static func timer(_ dueTime: RxTimeInterval, period: RxTimeInterval? = nil, scheduler: SchedulerType) async
        -> Observable<Element> {
        await Timer(
            dueTime: dueTime,
            period: period,
            scheduler: scheduler
        )
    }
}

import Foundation

private final actor TimerSink<Observer: ObserverType>: Sink where Observer.Element: RxAbstractInteger {
    typealias Parent = Timer<Observer.Element>

    private let parent: Parent
    let baseSink: BaseSink<Observer>

    init(parent: Parent, observer: Observer) async {
        self.parent = parent
        baseSink = BaseSink(observer: observer)
    }

    func run(_ c: C) async -> Disposable {
        await parent.scheduler.schedulePeriodic(
            0 as Observer.Element,
            c.call(),
            startAfter: parent.dueTime,
            period: parent.period!
        ) { c, state in
            await self.forwardOn(.next(state), c.call())
            return state &+ 1
        }
    }
}

private final actor TimerOneOffSink<Observer: ObserverType>: Sink where Observer.Element: RxAbstractInteger {
    typealias Parent = Timer<Observer.Element>

    private let parent: Parent
    let baseSink: BaseSink<Observer>

    init(parent: Parent, observer: Observer) async {
        self.parent = parent
        baseSink = BaseSink(observer: observer)
    }

    func run(_ c: C) async -> Disposable {
        await parent.scheduler
            .scheduleRelative(self, c.call(), dueTime: parent.dueTime) { [unowned self] c, _ -> Disposable in
                await forwardOn(.next(0), c.call())
                await forwardOn(.completed, c.call())
                await dispose()

                return Disposables.create()
            }
    }
}

private final class Timer<Element: RxAbstractInteger>: Producer<Element> {
    fileprivate let scheduler: SchedulerType
    fileprivate let dueTime: RxTimeInterval
    fileprivate let period: RxTimeInterval?

    init(dueTime: RxTimeInterval, period: RxTimeInterval?, scheduler: SchedulerType) async {
        self.scheduler = scheduler
        self.dueTime = dueTime
        self.period = period
        await super.init()
    }

    override func run<Observer: ObserverType>(
        _ c: C,
        _ observer: Observer
    )
        async -> AsynchronousDisposable where Observer.Element == Element {
        if period != nil {
            let sink = await TimerSink(parent: self, observer: observer)
            let subscription = await sink.run(c.call())
            return sink
        } else {
            let sink = await TimerOneOffSink(parent: self, observer: observer)
            let subscription = await sink.run(c.call())
            return sink
        }
    }
}
