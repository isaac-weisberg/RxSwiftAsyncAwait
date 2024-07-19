//
//  Range.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 9/13/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

public extension ObservableType where Element: RxAbstractInteger {
    /**
     Generates an observable sequence of integral numbers within a specified range, using the specified scheduler to generate and send out observer messages.

     - seealso: [range operator on reactivex.io](http://reactivex.io/documentation/operators/range.html)

     - parameter start: The value of the first integer in the sequence.
     - parameter count: The number of sequential integers to generate.
     - parameter scheduler: Scheduler to run the generator loop on.
     - returns: An observable sequence that contains a range of sequential integral numbers.
     */
    static func range(start: Element, count: Element, scheduler: ImmediateSchedulerType = CurrentThreadScheduler.instance) async -> Observable<Element> {
        await RangeProducer<Element>(start: start, count: count, scheduler: scheduler)
    }
}

private final class RangeProducer<Element: RxAbstractInteger>: Producer<Element> {
    fileprivate let start: Element
    fileprivate let count: Element
    fileprivate let scheduler: ImmediateSchedulerType

    init(start: Element, count: Element, scheduler: ImmediateSchedulerType) async {
        guard count >= 0 else {
            rxFatalError("count can't be negative")
        }

        guard start &+ (count - 1) >= start || count == 0 else {
            rxFatalError("overflow of count")
        }

        self.start = start
        self.count = count
        self.scheduler = scheduler
        await super.init()
    }

    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer, cancel: Cancelable) async -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        let sink = await RangeSink(parent: self, observer: observer, cancel: cancel)
        let subscription = await sink.run(C())
        return (sink: sink, subscription: subscription)
    }
}

private final class RangeSink<Observer: ObserverType>: Sink<Observer> where Observer.Element: RxAbstractInteger {
    typealias Parent = RangeProducer<Observer.Element>

    private let parent: Parent

    init(parent: Parent, observer: Observer, cancel: Cancelable) async {
        self.parent = parent
        await super.init(observer: observer, cancel: cancel)
    }

    func run(_ c: C) async -> Disposable {
        return await self.parent.scheduler.scheduleRecursive(0 as Observer.Element, c.call()) { i, c, recurse in
            if i < self.parent.count {
                await self.forwardOn(.next(self.parent.start + i), c.call())
                await recurse(i + 1)
            }
            else {
                await self.forwardOn(.completed, c.call())
                await self.dispose()
            }
        }
    }
}
