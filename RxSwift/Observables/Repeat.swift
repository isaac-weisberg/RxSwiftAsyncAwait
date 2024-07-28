//
//  Repeat.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 9/13/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

public extension ObservableType {
    /**
     Generates an observable sequence that repeats the given element infinitely, using the specified scheduler to send out observer messages.

     - seealso: [repeat operator on reactivex.io](http://reactivex.io/documentation/operators/repeat.html)

     - parameter element: Element to repeat.
     - parameter scheduler: Scheduler to run the producer loop on.
     - returns: An observable sequence that repeats the given element infinitely.
     */
    static func repeatElement(_ element: Element, scheduler: ImmediateSchedulerType = CurrentThreadScheduler.instance) async -> Observable<Element> {
        await RepeatElement(element: element, scheduler: scheduler)
    }
}

private final class RepeatElement<Element>: Producer<Element> {
    fileprivate let element: Element
    fileprivate let scheduler: ImmediateSchedulerType

    init(element: Element, scheduler: ImmediateSchedulerType) async {
        self.element = element
        self.scheduler = scheduler
        await super.init()
    }

    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer, cancel: Cancelable) async -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        let sink = await RepeatElementSink(parent: self, observer: observer, cancel: cancel)
        let subscription = await sink.run(c.call())

        return (sink: sink, subscription: subscription)
    }
}

private final class RepeatElementSink<Observer: ObserverType>: Sink {
    typealias Parent = RepeatElement<Observer.Element>

    private let parent: Parent
    let baseSink: BaseSink<Observer>

    init(parent: Parent, observer: Observer, cancel: Cancelable) async {
        self.parent = parent
        self.baseSink = await BaseSink(observer: observer, cancel: cancel)
    }

    func run(_ c: C) async -> Disposable {
        return await self.parent.scheduler.scheduleRecursive(self.parent.element, c.call()) { e, c, recurse in
            await self.forwardOn(.next(e), c.call())
            await recurse(e)
        }
    }
}
