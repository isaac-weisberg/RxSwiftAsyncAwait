//
//  DelaySubscription.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 6/14/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

import Foundation

public extension ObservableType {
    /**
     Time shifts the observable sequence by delaying the subscription with the specified relative time duration, using the specified scheduler to run timers.

     - seealso: [delay operator on reactivex.io](http://reactivex.io/documentation/operators/delay.html)

     - parameter dueTime: Relative time shift of the subscription.
     - parameter scheduler: Scheduler to run the subscription delay timer on.
     - returns: Time-shifted sequence.
     */
    func delaySubscription(_ dueTime: RxTimeInterval)
        -> Observable<Element> {
        DelaySubscription(source: asObservable(), dueTime: dueTime)
    }
}

private final actor DelaySubscriptionSink<Observer: ObserverType>:
    Sink, ObserverType {
    typealias Element = Observer.Element

    let baseSink: BaseSink<Observer>
    let dueTime: RxTimeInterval
    let timerDisposable = SingleAssignmentDisposableContainer<DisposableTimer>()
    let sourceSubscription = SingleAssignmentDisposable()

    init(observer: Observer, dueTime: RxTimeInterval) {
        baseSink = BaseSink(observer: observer)
        self.dueTime = dueTime
    }

    func on(_ event: Event<Element>, _ c: C) async {
        if baseSink.disposed {}
        await forwardOn(event, c.call())
        if event.isStopEvent {
            await dispose()
        }
    }

    func run(_ c: C, _ source: Observable<Element>) {
        let timer = DisposableTimer(dueTime) { _ in
            await self.handleTimer(c.call(), source: source)
        }
        timerDisposable.setDisposable(timer)?.dispose()
    }

    func handleTimer(_ c: C, source: Observable<Element>) async {
        await sourceSubscription.setDisposable(source.subscribe(c.call(), self))?.dispose()
    }

    func dispose() async {
        baseSink.setDisposed()
        timerDisposable.dispose()?.dispose()
        await sourceSubscription.dispose()?.dispose()
    }
}

private final class DelaySubscription<Element: Sendable>: Producer<Element> {
    private let source: Observable<Element>
    private let dueTime: RxTimeInterval

    init(source: Observable<Element>, dueTime: RxTimeInterval) {
        self.source = source
        self.dueTime = dueTime
        super.init()
    }

    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> AsynchronousDisposable
        where Observer.Element == Element {
        let sink = DelaySubscriptionSink(observer: observer, dueTime: dueTime)
        await sink.run(c.call(), source)

        return sink
    }
}
