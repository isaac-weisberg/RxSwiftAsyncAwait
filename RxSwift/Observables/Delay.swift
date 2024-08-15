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
    func delay(_ dueTime: RxTimeInterval)
        -> Observable<Element> {
        Delay(source: asObservable(), dueTime: dueTime)
    }
}

private final actor DelaySink<Observer: ObserverType>:
    SinkOverSingleSubscription,
    ObserverType {
    typealias Element = Observer.Element
    typealias Source = Observable<Element>

    private let dueTime: RxTimeInterval
    let baseSink: BaseSinkOverSingleSubscription<Observer>

    var timers: Set<IdentityHashable<SingleAssignmentDisposableContainer<DisposableTimer>>>

    init(observer: Observer, dueTime: RxTimeInterval) async {
        self.dueTime = dueTime
        timers = Set()
        baseSink = BaseSinkOverSingleSubscription(observer: observer)
    }

    func on(_ event: Event<Element>, _ c: C) async {
        switch event {
        case .next(let element):
            let disposable = SingleAssignmentDisposableContainer<DisposableTimer>()
            let timer = DisposableTimer(dueTime) { [weak self] _ in
                await self?.handleEventAfterTimer(disposable, event, c.call())
            }
            if let rejectedTimer = disposable.setDisposable(timer) {
                rejectedTimer.dispose()
            } else {
                timers.insert(IdentityHashable(inner: disposable))
            }
        case .error(let error):
            let disposable = baseSink.setDisposed()

            await forwardOn(.error(error), c.call())

            await disposable?.dispose()
        case .completed:
            let disposable = SingleAssignmentDisposableContainer<DisposableTimer>()
            let timer = DisposableTimer(dueTime) { [weak self] _ in
                await self?.handleEventAfterTimer(disposable, event, c.call())
            }
            if let rejectedTimer = disposable.setDisposable(timer) {
                rejectedTimer.dispose()
            } else {
                timers.insert(IdentityHashable(inner: disposable))
            }
        }
    }

    func handleEventAfterTimer(
        _ timerDisposable: SingleAssignmentDisposableContainer<DisposableTimer>,
        _ event: Event<Element>,
        _ c: C
    )
        async {
        timerDisposable.dispose()?.dispose()
        timers.remove(IdentityHashable(inner: timerDisposable))
        await forwardOn(event, c.call())
    }

    func dispose() async {
        let disposable = baseSink.setDisposed()

        for timer in timers {
            rxAssert(!timer.inner.isDisposed) // when I disposed of it, I removed it
            timer.inner.dispose()?.dispose()
        }

        await disposable?.dispose()
    }
}

private final class Delay<Element: Sendable>: Producer<Element> {
    private let source: Observable<Element>
    private let dueTime: RxTimeInterval

    init(source: Observable<Element>, dueTime: RxTimeInterval) {
        self.source = source
        self.dueTime = dueTime
        super.init()
    }

    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> AsynchronousDisposable
        where Observer.Element == Element {
        let sink = await DelaySink(observer: observer, dueTime: dueTime)

        await sink.run(c.call(), source)
        return sink
    }
}
