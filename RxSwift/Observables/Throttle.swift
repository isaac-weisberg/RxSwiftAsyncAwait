//
//  Throttle.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 3/22/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

import Foundation

public extension ObservableType {
    /**
     Returns an Observable that emits the first and the latest item emitted by the source Observable during sequential time windows of a specified duration.

     This operator makes sure that no two elements are emitted in less then dueTime.

     - seealso: [debounce operator on reactivex.io](http://reactivex.io/documentation/operators/debounce.html)

     - parameter dueTime: Throttling duration for each element.
     - parameter latest: Should latest element received in a dueTime wide time window since last element emission be emitted.
     - parameter scheduler: Scheduler to run the throttle timers on.
     - returns: The throttled sequence.
     */
    func throttle(_ dueTime: RxTimeInterval, latest: Bool = true, scheduler: SchedulerType) async
        -> Observable<Element> {
        await Throttle(source: asObservable(), dueTime: dueTime, latest: latest, scheduler: scheduler)
    }
}

private final actor ThrottleSink<Observer: ObserverType>:
    Sink,
    ObserverType,
    SynchronizedOnType {
    typealias Element = Observer.Element
    typealias ParentType = Throttle<Element>

    private let parent: ParentType

    let baseSink: BaseSink<Observer>

    // state
    private var lastUnsentElement: Element?
    private var lastSentTime: Date?
    private var completed = false

    let cancellable: SerialDisposable

    init(parent: ParentType, observer: Observer, cancel: Cancelable) async {
        self.parent = parent
        cancellable = await SerialDisposable()

        baseSink = await BaseSink(observer: observer, cancel: cancel)
    }

    func run(_ c: C) async -> Disposable {
        let subscription = await parent.source.subscribe(c.call(), self)

        return await Disposables.create(subscription, cancellable)
    }

    func on(_ event: Event<Element>, _ c: C) async {
        await synchronizedOn(event, c.call())
    }

    func synchronized_on(_ event: Event<Element>, _ c: C) async {
        switch event {
        case .next(let element):
            let now = parent.scheduler.now

            let reducedScheduledTime: RxTimeInterval

            if let lastSendingTime = lastSentTime {
                reducedScheduledTime = parent.dueTime.reduceWithSpanBetween(
                    earlierDate: lastSendingTime,
                    laterDate: now
                )
            } else {
                reducedScheduledTime = .nanoseconds(0)
            }

            if reducedScheduledTime.isNow {
                await sendNow(element: element, c.call())
                return
            }

            if !parent.latest {
                return
            }

            let isThereAlreadyInFlightRequest = lastUnsentElement != nil

            lastUnsentElement = element

            if isThereAlreadyInFlightRequest {
                return
            }

            let scheduler = parent.scheduler

            let d = await SingleAssignmentDisposable()
            await cancellable.setDisposable(d)

            await d.setDisposable(scheduler.scheduleRelative(
                0,
                c.call(),
                dueTime: reducedScheduledTime,
                action: propagate
            ))
        case .error:
            lastUnsentElement = nil
            await forwardOn(event, c.call())
            await dispose()
        case .completed:
            if lastUnsentElement != nil {
                completed = true
            } else {
                await forwardOn(.completed, c.call())
                await dispose()
            }
        }
    }

    private func sendNow(element: Element, _ c: C) async {
        lastUnsentElement = nil
        await forwardOn(.next(element), c.call())
        // in case element processing takes a while, this should give some more room
        lastSentTime = parent.scheduler.now
    }

    func propagate(_ c: C, _: Int) async -> Disposable {
        if let lastUnsentElement {
            await sendNow(element: lastUnsentElement, c.call())
        }

        if completed {
            await forwardOn(.completed, c.call())
            await dispose()
        }

        return Disposables.create()
    }
}

private final class Throttle<Element>: Producer<Element> {
    fileprivate let source: Observable<Element>
    fileprivate let dueTime: RxTimeInterval
    fileprivate let latest: Bool
    fileprivate let scheduler: SchedulerType

    init(source: Observable<Element>, dueTime: RxTimeInterval, latest: Bool, scheduler: SchedulerType) async {
        self.source = source
        self.dueTime = dueTime
        self.latest = latest
        self.scheduler = scheduler
        await super.init()
    }

    override func run<Observer: ObserverType>(
        _ c: C,
        _ observer: Observer,
        cancel: Cancelable
    )
        async -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        let sink = await ThrottleSink(parent: self, observer: observer, cancel: cancel)
        let subscription = await sink.run(c.call())
        return (sink: sink, subscription: subscription)
    }
}
