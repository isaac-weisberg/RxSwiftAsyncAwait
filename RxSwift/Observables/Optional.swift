////
////  Optional.swift
////  RxSwift
////
////  Created by tarunon on 2016/12/13.
////  Copyright © 2016 Krunoslav Zaher. All rights reserved.
////
//
//public extension ObservableType {
//    /**
//     Converts a optional to an observable sequence.
//
//     - seealso: [from operator on reactivex.io](http://reactivex.io/documentation/operators/from.html)
//
//     - parameter optional: Optional element in the resulting observable sequence.
//     - returns: An observable sequence containing the wrapped value or not from given optional.
//     */
//    static func from(optional: Element?) -> Observable<Element> {
//        ObservableOptional(optional: optional)
//    }
//
//    /**
//     Converts a optional to an observable sequence.
//
//     - seealso: [from operator on reactivex.io](http://reactivex.io/documentation/operators/from.html)
//
//     - parameter optional: Optional element in the resulting observable sequence.
//     - parameter scheduler: Scheduler to send the optional element on.
//     - returns: An observable sequence containing the wrapped value or not from given optional.
//     */
//    static func from<Scheduler: AsyncScheduler>(optional: Element?, scheduler: Scheduler) -> Observable<Element> {
//        ObservableOptionalScheduled(optional: optional, scheduler: scheduler)
//    }
//}
//
//private final actor ObservableOptionalScheduledSink<Observer: ObserverType, Scheduler: AsyncScheduler>: Sink {
//    typealias Element = Observer.Element
//    typealias Parent = ObservableOptionalScheduled<Element, Scheduler>
//
//    private let parent: Parent
//    let baseSink: BaseSink<Observer>
//
//    init(parent: Parent, observer: Observer) {
//        self.parent = parent
//        baseSink = BaseSink(observer: observer)
//    }
//
//    func run(_ c: C) async {
//        let optional = parent.optional
//        await parent.scheduler.perform(c.call(), { c in
//            if self.baseSink.disposed {
//                return
//            }
//            if let next = optional {
//                await self.forwardOn(.next(next), c.call())
//                return await self.parent.scheduler.perform(c.call(), { c in
//                    if self.baseSink.disposed {
//                        return
//                    }
//                    await self.forwardOn(.completed, c.call())
//                    await self.dispose()
//                })
//            } else {
//                await self.forwardOn(.completed, c.call())
//                await self.dispose()
//            }
//        })
//    }
//    
//    func dispose() async {
//        if setDisposed() {
//            
//        }
//    }
//}
//
//private final class ObservableOptionalScheduled<Element: Sendable, Scheduler: AsyncScheduler>: Producer<Element> {
//    fileprivate let optional: Element?
//    fileprivate let scheduler: Scheduler
//
//    init(optional: Element?, scheduler: Scheduler) {
//        self.optional = optional
//        self.scheduler = scheduler
//        super.init()
//    }
//
//    override func run<Observer: ObserverType>(
//        _ c: C,
//        _ observer: Observer
//    )
//        async -> AsynchronousDisposable where Observer.Element == Element {
//        let sink = ObservableOptionalScheduledSink(parent: self, observer: observer)
//        await sink.run(c.call())
//        return sink
//    }
//}
//
//private final class ObservableOptional<Element: Sendable>: Producer<Element> {
//    private let optional: Element?
//
//    init(optional: Element?) {
//        self.optional = optional
//        super.init()
//    }
//
//    override func subscribe<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> AsynchronousDisposable
//        where Observer.Element == Element {
//        if let element = optional {
//            await observer.on(.next(element), c.call())
//        }
//        await observer.on(.completed, c.call())
//        return Disposables.create()
//    }
//}
