////
////  Timer.swift
////  RxSwift
////
////  Created by Krunoslav Zaher on 6/7/15.
////  Copyright © 2015 Krunoslav Zaher. All rights reserved.
////
//
//public extension ObservableType where Element: RxAbstractInteger {
//    /**
//     Returns an observable sequence that produces a value after each period, using the specified scheduler to run timers and to send out observer messages.
//
//     - seealso: [interval operator on reactivex.io](http://reactivex.io/documentation/operators/interval.html)
//
//     - parameter period: Period for producing the values in the resulting sequence.
//     - parameter scheduler: Scheduler to run the timer on.
//     - returns: An observable sequence that produces a value after each period.
//     */
//    static func interval(_ period: RxTimeInterval)
//        -> Observable<Element> {
//        Timer(
//            dueTime: period,
//            period: period
//        )
//    }
//}
//
//public extension ObservableType where Element: RxAbstractInteger {
//    /**
//     Returns an observable sequence that periodically produces a value after the specified initial relative due time has elapsed, using the specified scheduler to run timers.
//
//     - seealso: [timer operator on reactivex.io](http://reactivex.io/documentation/operators/timer.html)
//
//     - parameter dueTime: Relative time at which to produce the first value.
//     - parameter period: Period to produce subsequent values.
//     - parameter scheduler: Scheduler to run timers on.
//     - returns: An observable sequence that produces a value after due time has elapsed and then each period.
//     */
//    static func timer(_ dueTime: RxTimeInterval, period: RxTimeInterval? = nil)
//        -> Observable<Element> {
//        Timer(
//            dueTime: dueTime,
//            period: period
//        )
//    }
//}
//
//private final actor TimerSink<Observer: ObserverType>: Sink where Observer.Element: RxAbstractInteger {
//    typealias Parent = Timer<Observer.Element>
//
//    private let parent: Parent
//    let baseSink: BaseSink<Observer>
//
//    init(parent: Parent, observer: Observer) {
//        self.parent = parent
//        baseSink = BaseSink(observer: observer)
//    }
//
//    var timerTask: Task<Void, Never>?
//
//    func run(_ c: C) async {
//        let period = parent.period!
//        let startAfter = parent.dueTime
//        timerTask = Task {
//            var state: Observer.Element = 0
//            if startAfter > 0 {
//                do {
//                    try await Task.sleep(nanoseconds: startAfter.nanoseconds)
//                } catch {
//                    return
//                }
//            }
//
//            await baseSink.observer.on(.next(state), c.call())
//
//            while true {
//                do {
//                    try await Task.sleep(nanoseconds: period.nanoseconds)
//                } catch {
//                    return
//                }
//                state += 1
//                await baseSink.observer.on(.next(state), c.call())
//            }
//        }
//    }
//
//    func dispose() async {
//        setDisposed()
//        timerTask?.cancel()
//        timerTask = nil
//
//    }
//}
//
//private final actor TimerOneOffSink<Observer: ObserverType>: Sink where Observer.Element: RxAbstractInteger {
//    fileprivate typealias Parent = Timer<Observer.Element>
//
//    private let parent: Parent
//    let baseSink: BaseSink<Observer>
//
//    fileprivate init(parent: Parent, observer: Observer) {
//        self.parent = parent
//        baseSink = BaseSink(observer: observer)
//    }
//
//    var timerTask: Task<Void, Never>?
//
//    func run(_ c: C) async {
//        timerTask = Task { [parent] in
//            if parent.dueTime.nanoseconds > 0 {
//                do {
//                    try await Task.sleep(nanoseconds: parent.dueTime.nanoseconds)
//                } catch {
//                    return
//                }
//            }
//
//            await baseSink.observer.on(.next(0), c.call())
//            await baseSink.observer.on(.completed, c.call())
//            await dispose()
//        }
//    }
//
//    func dispose() async {
//        baseSink.setDisposed()
//        timerTask?.cancel()
//        timerTask = nil
//    }
//}
//
//private final class Timer<Element: RxAbstractInteger>: Producer<Element> {
//    fileprivate let dueTime: RxTimeInterval
//    fileprivate let period: RxTimeInterval?
//
//    init(dueTime: RxTimeInterval, period: RxTimeInterval?) {
//        self.dueTime = dueTime
//        self.period = period
//        super.init()
//    }
//
//    override func run<Observer: ObserverType>(
//        _ c: C,
//        _ observer: Observer
//    )
//        async -> AsynchronousDisposable where Observer.Element == Element {
//        if period != nil {
//            let sink = TimerSink(parent: self, observer: observer)
//            await sink.run(c.call())
//            return sink
//        } else {
//            let sink = TimerOneOffSink(parent: self, observer: observer)
//            await sink.run(c.call())
//            return sink
//        }
//    }
//}
