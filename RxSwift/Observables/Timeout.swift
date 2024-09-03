//
//  Timeout.swift
//  RxSwift
//
//  Created by Tomi Koskinen on 13/11/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

import Foundation

public extension ObservableType {
    /**
     Applies a timeout policy for each element in the observable sequence. If the next element isn't received within the specified timeout duration starting from its predecessor, a TimeoutError is propagated to the observer.

     - seealso: [timeout operator on reactivex.io](http://reactivex.io/documentation/operators/timeout.html)

     - parameter dueTime: Maximum duration between values before a timeout occurs.
     - parameter scheduler: Scheduler to run the timeout timer on.
     - returns: An observable sequence with a `RxError.timeout` in case of a timeout.
     */
    func timeout(_ dueTime: RxTimeInterval) -> Observable<Element> {
        timeout(dueTime, other: Observable.error(RxError.timeout))
    }

    func timeout(
        _ dueTime: RxTimeInterval,
        scheduler: any AsyncScheduler
    ) -> Observable<Element> {
        timeout(dueTime)
            .observe(on: scheduler)
    }

    func timeout(
        _ dueTime: RxTimeInterval,
        scheduler: any MainLegacySchedulerProtocol
    ) -> ObserveOnMainActorObservable<Element> {
        timeout(dueTime)
            .observe(on: scheduler)
    }

    /**
     Applies a timeout policy for each element in the observable sequence, using the specified scheduler to run timeout timers. If the next element isn't received within the specified timeout duration starting from its predecessor, the other observable sequence is used to produce future messages from that point on.

     - seealso: [timeout operator on reactivex.io](http://reactivex.io/documentation/operators/timeout.html)

     - parameter dueTime: Maximum duration between values before a timeout occurs.
     - parameter other: Sequence to return in case of a timeout.
     - parameter scheduler: Scheduler to run the timeout timer on.
     - returns: The source sequence switching to the other sequence in case of a timeout.
     */
    func timeout<Source: ObservableConvertibleType>(
        _ dueTime: RxTimeInterval,
        other: Source
    ) -> Observable<Element> where Element == Source.Element {
        Timeout(
            source: asObservable(),
            dueTime: dueTime,
            other: other.asObservable()
        )
    }

    func timeout<Source: ObservableConvertibleType>(
        _ dueTime: RxTimeInterval,
        other: Source,
        scheduler: AsyncScheduler
    ) -> Observable<Element> where Element == Source.Element {
        timeout(dueTime, other: other)
            .observe(on: scheduler)
    }

    func timeout<Source: ObservableConvertibleType>(
        _ dueTime: RxTimeInterval,
        other: Source,
        scheduler: MainLegacySchedulerProtocol
    ) -> ObserveOnMainActorObservable<Element> where Element == Source.Element {
        timeout(dueTime, other: other)
            .observe(on: scheduler)
    }
}

private final actor TimeoutSink<Observer: ObserverType>: Sink, ObserverType {
    typealias Element = Observer.Element
    typealias Parent = Timeout<Element>

    private let parent: Parent

    private let timerD: SerialDisposableGeneric<DisposableTimer>
    private let sourceSub: SingleAssignmentDisposable
    private let otherSub: SingleAssignmentDisposable

    private var id = 0
    private var switched = false
    let baseSink: BaseSink<Observer>

    init(parent: Parent, observer: Observer) {
        timerD = SerialDisposableGeneric()
        sourceSub = SingleAssignmentDisposable()
        otherSub = SingleAssignmentDisposable()
        self.parent = parent
        baseSink = BaseSink(observer: observer)
    }

    func run(_ c: C) async {
        createTimeoutTimer(c.call())
        await sourceSub.setDisposable(parent.source.subscribe(c.call(), self))?.dispose()
    }

    func on(_ event: Event<Element>, _ c: C) async {
        if baseSink.disposed {
            return
        }
        switch event {
        case .next:
            var onNextWins = false

            onNextWins = !switched
            if onNextWins {
                id = id &+ 1
            }

            if onNextWins {
                createTimeoutTimer(c.call())
                await forwardOn(event, c.call())
            }
        case .error, .completed:
            var onEventWins = false

            onEventWins = !switched
            if onEventWins {
                id = id &+ 1
            }

            if onEventWins {
                timerD.dispose()?.dispose()
                await forwardOn(event, c.call())
                await dispose()
            }
        }
    }

    func dispose() async {
        baseSink.setDisposed()
        let timerDisp = timerD.dispose()
        let sourceDisp = sourceSub.dispose()
        let otherDisp = otherSub.dispose()

        timerDisp?.dispose()
        await sourceDisp?.dispose()
        await otherDisp?.dispose()
    }

    private func createTimeoutTimer(_ c: C) {
        let timerId = id
        let disposableTimer = DisposableTimer(parent.dueTime) { [weak self] _ in
            await self?.handleTimer(timerId, c.call())
        }
        timerD.replace(disposableTimer)?.dispose()
    }

    private func handleTimer(_ timerId: Int, _ c: C) async {
        if baseSink.disposed {
            return
        }

        switched = timerId == id
        let timerWins = switched

        if timerWins {
            async let sourceDispose: ()? = sourceSub.dispose()?.dispose()
            async let subscribeToOther: ()? = otherSub.setDisposable(parent.other.subscribe(c.call(), self))?.dispose()

            await sourceDispose
            await subscribeToOther
        }
    }
}

private final class Timeout<Element: Sendable>: Producer<Element>, @unchecked Sendable {
    fileprivate let source: Observable<Element>
    fileprivate let dueTime: RxTimeInterval
    fileprivate let other: Observable<Element>

    init(
        source: Observable<Element>,
        dueTime: RxTimeInterval,
        other: Observable<Element>
    ) {
        self.source = source
        self.dueTime = dueTime
        self.other = other
        super.init()
    }

    override func run<Observer: ObserverType>(
        _ c: C,
        _ observer: Observer
    )
        async -> AsynchronousDisposable where Observer.Element == Element {
        let sink = TimeoutSink(parent: self, observer: observer)
        await sink.run(c.call())
        return sink
    }
}
