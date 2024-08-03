//
//  Delay.swift
//  RxSwift
//
//  Created by tarunon on 2016/02/09.
//  Copyright © 2016 Krunoslav Zaher. All rights reserved.
//

import Foundation

public extension ObservableType {
    /**
     Returns an observable sequence by the source observable sequence shifted forward in time by a specified delay. Error events from the source observable sequence are not delayed.

     - seealso: [delay operator on reactivex.io](http://reactivex.io/documentation/operators/delay.html)

     - parameter dueTime: Relative time shift of the source by.
     - parameter scheduler: Scheduler to run the subscription delay timer on.
     - returns: the source Observable shifted in time by the specified delay.
     */
    func delay(_ dueTime: RxTimeInterval, scheduler: SchedulerType) async
        -> Observable<Element> {
        await Delay(source: asObservable(), dueTime: dueTime, scheduler: scheduler)
    }
}

private final actor DelaySink<Observer: ObserverType>:
    Sink,
    ObserverType {
    typealias Element = Observer.Element
    typealias Source = Observable<Element>
    typealias DisposeKey = Bag<Disposable>.KeyType

    private let dueTime: RxTimeInterval
    private let scheduler: SchedulerType

    private let sourceSubscription: SingleAssignmentDisposable
    private let cancelable: SerialDisposable
    
    let baseSink: BaseSink<Observer>

    // is scheduled some action
    private var active = false
    // is "run loop" on different scheduler running
    private var running = false
    private var errorEvent: Event<Element>?

    // state
    private var queue = Queue<(eventTime: RxTime, event: Event<Element>)>(capacity: 0)

    init(observer: Observer, dueTime: RxTimeInterval, scheduler: SchedulerType, cancel: Cancelable) async {
        sourceSubscription = await SingleAssignmentDisposable()
        cancelable = await SerialDisposable()
        self.dueTime = dueTime
        self.scheduler = scheduler
        self.baseSink = await BaseSink(observer: observer, cancel: cancel)
    }

    // All of these complications in this method are caused by the fact that
    // error should be propagated immediately. Error can be potentially received on different
    // scheduler so this process needs to be synchronized somehow.
    //
    // Another complication is that scheduler is potentially concurrent so internal queue is used.
    func drainQueue(_: Void, _ c: C, scheduler: AnyRecursiveScheduler<Void>) async {
        let hasFailed = {
            let hasFailed = self.errorEvent != nil
            if !hasFailed {
                self.running = true
            }
            return hasFailed
        }()

        if hasFailed {
            return
        }

        var ranAtLeastOnce = false

        while true {
            let (eventToForwardImmediately, nextEventToScheduleOriginalTime) =  {
                let errorEvent = self.errorEvent

                let eventToForwardImmediately = ranAtLeastOnce ? nil : self.queue.dequeue()?.event
                let nextEventToScheduleOriginalTime: Date? = ranAtLeastOnce && !self.queue.isEmpty
                    ? self.queue.peek().eventTime
                    : nil

                if errorEvent == nil {
                    if eventToForwardImmediately != nil {}
                    else if nextEventToScheduleOriginalTime != nil {
                        self.running = false
                    } else {
                        self.running = false
                        self.active = false
                    }
                }
                return (eventToForwardImmediately, nextEventToScheduleOriginalTime)
            }()

            if let errorEvent {
                await forwardOn(errorEvent, c.call())
                await dispose()
                return
            } else {
                if let eventToForwardImmediately {
                    ranAtLeastOnce = true
                    await forwardOn(eventToForwardImmediately, c.call())
                    if case .completed = eventToForwardImmediately {
                        await dispose()
                        return
                    }
                } else if let nextEventToScheduleOriginalTime {
                    await scheduler.schedule(
                        (),
                        c.call(),
                        dueTime: dueTime.reduceWithSpanBetween(
                            earlierDate: nextEventToScheduleOriginalTime,
                            laterDate: self.scheduler.now
                        )
                    )
                    return
                } else {
                    return
                }
            }
        }
    }

    func on(_ event: Event<Element>, _ c: C) async {
        if event.isStopEvent {
            await sourceSubscription.dispose()
        }

        switch event {
        case .error:
            let shouldSendImmediately = {
                let shouldSendImmediately = !self.running
                self.queue = Queue(capacity: 0)
                self.errorEvent = event
                return shouldSendImmediately
            }()

            if shouldSendImmediately {
                await forwardOn(event, c.call())
                await dispose()
            }
        default:
            let shouldSchedule = {
                let shouldSchedule = !self.active
                self.active = true
                self.queue.enqueue((self.scheduler.now, event))
                return shouldSchedule
            }()

            if shouldSchedule {
                await cancelable.setDisposable(scheduler.scheduleRecursive((), c.call(), dueTime: dueTime, action: drainQueue))
            }
        }
    }

    func run(_ c: C, source: Observable<Element>) async -> Disposable {
        await sourceSubscription.setDisposable(source.subscribe(c.call(), self))
        return await Disposables.create(sourceSubscription, cancelable)
    }
}

private final class Delay<Element>: Producer<Element> {
    private let source: Observable<Element>
    private let dueTime: RxTimeInterval
    private let scheduler: SchedulerType

    init(source: Observable<Element>, dueTime: RxTimeInterval, scheduler: SchedulerType) async {
        self.source = source
        self.dueTime = dueTime
        self.scheduler = scheduler
        await super.init()
    }

    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer, cancel: SynchronizedCancelable) async -> (sink: SynchronizedDisposable, subscription: SynchronizedDisposable) where Observer.Element == Element {
        let sink = await DelaySink(observer: observer, dueTime: dueTime, scheduler: scheduler, cancel: cancel)
        let subscription = await sink.run(c.call(), source: source)
        return (sink: sink, subscription: subscription)
    }
}
