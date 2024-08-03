//
//  SubscribeOn.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 6/14/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

public extension ObservableType {
    /**
     Wraps the source sequence in order to run its subscription and unsubscription logic on the specified
     scheduler.

     This operation is not commonly used.

     This only performs the side-effects of subscription and unsubscription on the specified scheduler.

     In order to invoke observer callbacks on a `scheduler`, use `observeOn`.

     - seealso: [subscribeOn operator on reactivex.io](http://reactivex.io/documentation/operators/subscribeon.html)

     - parameter scheduler: Scheduler to perform subscription and unsubscription actions on.
     - returns: The source sequence whose subscriptions and unsubscriptions happen on the specified scheduler.
     */
    func subscribe(on scheduler: ImmediateSchedulerType) async
        -> Observable<Element>
    {
        await SubscribeOn(source: self, scheduler: scheduler)
    }

    /**
     Wraps the source sequence in order to run its subscription and unsubscription logic on the specified
     scheduler.

     This operation is not commonly used.

     This only performs the side-effects of subscription and unsubscription on the specified scheduler.

     In order to invoke observer callbacks on a `scheduler`, use `observeOn`.

     - seealso: [subscribeOn operator on reactivex.io](http://reactivex.io/documentation/operators/subscribeon.html)

     - parameter scheduler: Scheduler to perform subscription and unsubscription actions on.
     - returns: The source sequence whose subscriptions and unsubscriptions happen on the specified scheduler.
     */
    @available(*, deprecated, renamed: "subscribe(on:)")
    func subscribeOn(_ scheduler: ImmediateSchedulerType) async
        -> Observable<Element>
    {
        await self.subscribe(on: scheduler)
    }
}

private final actor SubscribeOnSink<Ob: ObservableType, Observer: ObserverType>: Sink, ObserverType where Ob.Element == Observer.Element {
    typealias Element = Observer.Element
    typealias Parent = SubscribeOn<Ob>

    let parent: Parent
    let baseSink: BaseSink<Observer>

    init(parent: Parent, observer: Observer, cancel: SynchronizedCancelable) async {
        self.parent = parent
        self.baseSink = await BaseSink(observer: observer, cancel: cancel)
    }

    func on(_ event: Event<Element>, _ c: C) async {
        await self.forwardOn(event, c.call())

        if event.isStopEvent {
            await self.dispose()
        }
    }

    func run(_ c: C) async -> Disposable {
        let disposeEverything = await SerialDisposable()
        let cancelSchedule = await SingleAssignmentDisposable()

        await disposeEverything.setDisposable(cancelSchedule)

        let disposeSchedule = await self.parent.scheduler.schedule((), c.call()) { c, _ -> Disposable in
            let subscription = await self.parent.source.subscribe(c.call(), self)
            await disposeEverything.setDisposable(ScheduledDisposable(scheduler: self.parent.scheduler, disposable: subscription))
            return Disposables.create()
        }

        await cancelSchedule.setDisposable(disposeSchedule)

        return disposeEverything
    }
}

private final class SubscribeOn<Ob: ObservableType>: Producer<Ob.Element> {
    let source: Ob
    let scheduler: ImmediateSchedulerType

    init(source: Ob, scheduler: ImmediateSchedulerType) async {
        self.source = source
        self.scheduler = scheduler
        await super.init()
    }

    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer, cancel: SynchronizedCancelable) async -> (sink: SynchronizedDisposable, subscription: SynchronizedDisposable) where Observer.Element == Ob.Element {
        let sink = await SubscribeOnSink(parent: self, observer: observer, cancel: cancel)
        let subscription = await sink.run(c.call())
        return (sink: sink, subscription: subscription)
    }
}
