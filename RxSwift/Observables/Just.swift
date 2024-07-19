//
//  Just.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 8/30/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

public extension ObservableType {
    /**
     Returns an observable sequence that contains a single element.

     - seealso: [just operator on reactivex.io](http://reactivex.io/documentation/operators/just.html)

     - parameter element: Single element in the resulting observable sequence.
     - returns: An observable sequence containing the single specified element.
     */
    static func just(_ element: Element) async -> Observable<Element> {
        await Just(element: element)
    }

    /**
     Returns an observable sequence that contains a single element.

     - seealso: [just operator on reactivex.io](http://reactivex.io/documentation/operators/just.html)

     - parameter element: Single element in the resulting observable sequence.
     - parameter scheduler: Scheduler to send the single element on.
     - returns: An observable sequence containing the single specified element.
     */
    static func just(_ element: Element, scheduler: ImmediateSchedulerType) async -> Observable<Element> {
        await JustScheduled(element: element, scheduler: scheduler)
    }
}

private final class JustScheduledSink<Observer: ObserverType>: Sink<Observer> {
    typealias Parent = JustScheduled<Observer.Element>

    private let parent: Parent

    init(parent: Parent, observer: Observer, cancel: Cancelable) async {
        self.parent = parent
        await super.init(observer: observer, cancel: cancel)
    }

    func run(_ c: C) async -> Disposable {
        let scheduler = self.parent.scheduler
        return await scheduler.schedule(self.parent.element, c.call()) { c, element in
            await self.forwardOn(.next(element), c.call())
            return await scheduler.schedule((), c.call()) { c, _ in
                await self.forwardOn(.completed, c.call())
                await self.dispose()
                return Disposables.create()
            }
        }
    }
}

private final class JustScheduled<Element>: Producer<Element> {
    fileprivate let scheduler: ImmediateSchedulerType
    fileprivate let element: Element

    init(element: Element, scheduler: ImmediateSchedulerType) async {
        self.scheduler = scheduler
        self.element = element
        await super.init()
    }

    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer, cancel: Cancelable) async -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        let sink = await JustScheduledSink(parent: self, observer: observer, cancel: cancel)
        let subscription = await sink.run(C())
        return (sink: sink, subscription: subscription)
    }
}

private final class Just<Element>: Producer<Element> {
    private let element: Element

    init(element: Element) async {
        self.element = element
        await super.init()
    }

    override func subscribe<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> Disposable where Observer.Element == Element {
        await observer.on(.next(self.element), c.call())
        await observer.on(.completed, c.call())
        return Disposables.create()
    }
}
