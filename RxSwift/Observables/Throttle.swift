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
        -> Observable<Element>
    {
        await Throttle(source: self.asObservable(), dueTime: dueTime, latest: latest, scheduler: scheduler)
    }
}

private final class ThrottleSink<Observer: ObserverType>:
    Sink<Observer>,
    ObserverType,
    LockOwnerType,
    SynchronizedOnType
{
    typealias Element = Observer.Element
    typealias ParentType = Throttle<Element>

    private let parent: ParentType

    let lock: RecursiveLock

    // state
    private var lastUnsentElement: Element?
    private var lastSentTime: Date?
    private var completed: Bool = false

    let cancellable: SerialDisposable

    init(parent: ParentType, observer: Observer, cancel: Cancelable) async {
        self.parent = parent
        self.lock = await RecursiveLock()
        self.cancellable = await SerialDisposable()

        await super.init(observer: observer, cancel: cancel)
    }

    func run(_ c: C) async -> Disposable {
        let subscription = await self.parent.source.subscribe(c.call(), self)

        return await Disposables.create(subscription, self.cancellable)
    }

    func on(_ event: Event<Element>, _ c: C) async {
        await self.synchronizedOn(event, c.call())
    }

    func synchronized_on(_ event: Event<Element>, _ c: C) async {
        switch event {
        case .next(let element):
            let now = self.parent.scheduler.now

            let reducedScheduledTime: RxTimeInterval

            if let lastSendingTime = self.lastSentTime {
                reducedScheduledTime = self.parent.dueTime.reduceWithSpanBetween(earlierDate: lastSendingTime, laterDate: now)
            }
            else {
                reducedScheduledTime = .nanoseconds(0)
            }

            if reducedScheduledTime.isNow {
                await self.sendNow(element: element, c.call())
                return
            }

            if !self.parent.latest {
                return
            }

            let isThereAlreadyInFlightRequest = self.lastUnsentElement != nil

            self.lastUnsentElement = element

            if isThereAlreadyInFlightRequest {
                return
            }

            let scheduler = self.parent.scheduler

            let d = await SingleAssignmentDisposable()
            await self.cancellable.setDisposable(d)

            await d.setDisposable(scheduler.scheduleRelative(0, c.call(), dueTime: reducedScheduledTime, action: self.propagate))
        case .error:
            self.lastUnsentElement = nil
            await self.forwardOn(event, c.call())
            await self.dispose()
        case .completed:
            if self.lastUnsentElement != nil {
                self.completed = true
            }
            else {
                await self.forwardOn(.completed, c.call())
                await self.dispose()
            }
        }
    }

    private func sendNow(element: Element, _ c: C) async {
        self.lastUnsentElement = nil
        await self.forwardOn(.next(element), c.call())
        // in case element processing takes a while, this should give some more room
        self.lastSentTime = self.parent.scheduler.now
    }

    func propagate(_ c: C, _: Int) async -> Disposable {
        await self.lock.performLocked {
            if let lastUnsentElement = self.lastUnsentElement {
                await self.sendNow(element: lastUnsentElement, c.call())
            }

            if self.completed {
                await self.forwardOn(.completed, c.call())
                await self.dispose()
            }
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

    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer, cancel: Cancelable) async -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        let sink = await ThrottleSink(parent: self, observer: observer, cancel: cancel)
        let subscription = await sink.run(C())
        return (sink: sink, subscription: subscription)
    }
}
