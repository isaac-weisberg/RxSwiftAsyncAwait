//
//  SubscribeOn.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 6/14/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

public extension ObservableConvertibleType {
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
    func subscribe(on scheduler: any AsyncScheduler)
        -> Observable<Element> {
        SubscribeOn(source: asObservable(), scheduler: scheduler)
    }
}

private final actor SubscribeOnSink<Ob: ObservableType, Observer: ObserverType>: Sink,
    ObserverType, ActorLock where Ob.Element == Observer.Element {
    typealias Element = Observer.Element
    typealias Parent = SubscribeOn<Ob>

    let parent: Parent
    let baseSink: BaseSink<Observer>

    init(parent: Parent, observer: Observer) {
        self.parent = parent
        baseSink = BaseSink(observer: observer)
    }

    func on(_ event: Event<Element>, _ c: C) async {
        await forwardOn(event, c.call())

        if event.isStopEvent {
            await dispose()
        }
    }

    let scheduleDisposable = SingleAssignmentSyncDisposable()
    let sourceDisposable = SingleAssignmentDisposable()

    func run(_ c: C) async {
        let disp = parent.scheduler.perform(c.call()) { c in
            let subscription = await self.parent.source.subscribe(c.call(), self)

            await self.sourceDisposable.setDisposable(subscription)?.dispose()
        }
        scheduleDisposable.setDisposable(disp)?.dispose()
    }

    func dispose() async {
        baseSink.setDisposed()
        scheduleDisposable.dispose()?.dispose()
        await sourceDisposable.dispose()?.dispose()
    }

    func perform<R>(_ work: () -> R) -> R {
        work()
    }
}

private final class SubscribeOn<Ob: ObservableType>: Producer<Ob.Element> {
    let source: Ob
    let scheduler: AsyncScheduler

    init(source: Ob, scheduler: AsyncScheduler) {
        self.source = source
        self.scheduler = scheduler
        super.init()
    }

    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> AsynchronousDisposable
        where Observer.Element == Ob.Element {
        let sink = SubscribeOnSink(parent: self, observer: observer)
        await sink.run(c.call())
        return sink
    }
}
