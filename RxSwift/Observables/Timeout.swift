////
////  Timeout.swift
////  RxSwift
////
////  Created by Tomi Koskinen on 13/11/15.
////  Copyright © 2015 Krunoslav Zaher. All rights reserved.
////
//
//import Foundation
//
//public extension ObservableType {
//    /**
//     Applies a timeout policy for each element in the observable sequence. If the next element isn't received within the specified timeout duration starting from its predecessor, a TimeoutError is propagated to the observer.
//
//     - seealso: [timeout operator on reactivex.io](http://reactivex.io/documentation/operators/timeout.html)
//
//     - parameter dueTime: Maximum duration between values before a timeout occurs.
//     - parameter scheduler: Scheduler to run the timeout timer on.
//     - returns: An observable sequence with a `RxError.timeout` in case of a timeout.
//     */
//    func timeout(_ dueTime: RxTimeInterval, scheduler: SchedulerType) async
//        -> Observable<Element> {
//        await Timeout(
//            source: asObservable(),
//            dueTime: dueTime,
//            other: Observable.error(RxError.timeout),
//            scheduler: scheduler
//        )
//    }
//
//    /**
//     Applies a timeout policy for each element in the observable sequence, using the specified scheduler to run timeout timers. If the next element isn't received within the specified timeout duration starting from its predecessor, the other observable sequence is used to produce future messages from that point on.
//
//     - seealso: [timeout operator on reactivex.io](http://reactivex.io/documentation/operators/timeout.html)
//
//     - parameter dueTime: Maximum duration between values before a timeout occurs.
//     - parameter other: Sequence to return in case of a timeout.
//     - parameter scheduler: Scheduler to run the timeout timer on.
//     - returns: The source sequence switching to the other sequence in case of a timeout.
//     */
//    func timeout<Source: ObservableConvertibleType>(
//        _ dueTime: RxTimeInterval,
//        other: Source,
//        scheduler: SchedulerType
//    )
//        async -> Observable<Element> where Element == Source.Element {
//        await Timeout(source: asObservable(), dueTime: dueTime, other: other.asObservable(), scheduler: scheduler)
//    }
//}
//
//private final actor TimeoutSink<Observer: ObserverType>: Sink, ObserverType {
//    typealias Element = Observer.Element
//    typealias Parent = Timeout<Element>
//
//    private let parent: Parent
//
//    private let timerD: SerialDisposable
//    private let subscription: SerialDisposable
//
//    private var id = 0
//    private var switched = false
//    let baseSink: BaseSink<Observer>
//
//    init(parent: Parent, observer: Observer) async {
//        timerD = await SerialDisposable()
//        subscription = await SerialDisposable()
//        self.parent = parent
//        baseSink = BaseSink(observer: observer)
//    }
//
//    func run(_ c: C) async -> Disposable {
//        let original = await SingleAssignmentDisposable()
//        await subscription.setDisposable(original)
//
//        await createTimeoutTimer(c.call())
//
//        await original.setDisposable(parent.source.subscribe(c.call(), self))
//
//        return await Disposables.create(subscription, timerD)
//    }
//
//    func on(_ event: Event<Element>, _ c: C) async {
//        switch event {
//        case .next:
//            var onNextWins = false
//
//            onNextWins = !switched
//            if onNextWins {
//                id = id &+ 1
//            }
//
//            if onNextWins {
//                await forwardOn(event, c.call())
//                await createTimeoutTimer(c.call())
//            }
//        case .error, .completed:
//            var onEventWins = false
//
//            onEventWins = !switched
//            if onEventWins {
//                id = id &+ 1
//            }
//
//            if onEventWins {
//                await forwardOn(event, c.call())
//                await dispose()
//            }
//        }
//    }
//
//    private func createTimeoutTimer(_ c: C) async {
//        if await timerD.isDisposed() {
//            return
//        }
//
//        let nextTimer = await SingleAssignmentDisposable()
//        await timerD.setDisposable(nextTimer)
//
//        let disposeSchedule = await parent.scheduler
//            .scheduleRelative(id, c.call(), dueTime: parent.dueTime) { c, state in
//
//                var timerWins = false
//
//                self.switched = (state == self.id)
//                timerWins = self.switched
//
//                if timerWins {
//                    await self.subscription.setDisposable(self.parent.other.subscribe(c.call(), self))
//                }
//
//                return Disposables.create()
//            }
//
//        await nextTimer.setDisposable(disposeSchedule)
//    }
//}
//
//private final class Timeout<Element>: Producer<Element> {
//    fileprivate let source: Observable<Element>
//    fileprivate let dueTime: RxTimeInterval
//    fileprivate let other: Observable<Element>
//    fileprivate let scheduler: SchedulerType
//
//    init(
//        source: Observable<Element>,
//        dueTime: RxTimeInterval,
//        other: Observable<Element>,
//        scheduler: SchedulerType
//    )
//    async {
//        self.source = source
//        self.dueTime = dueTime
//        self.other = other
//        self.scheduler = scheduler
//        await super.init()
//    }
//
//    override func run<Observer: ObserverType>(
//        _ c: C,
//        _ observer: Observer
//    )
//        async -> AsynchronousDisposable where Observer.Element == Element {
//        let sink = await TimeoutSink(parent: self, observer: observer)
//        let subscription = await sink.run(c.call())
//        return sink
//    }
//}
