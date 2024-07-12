//
//  Skip.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 6/25/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

import Foundation

public extension ObservableType {
    /**
     Bypasses a specified number of elements in an observable sequence and then returns the remaining elements.

     - seealso: [skip operator on reactivex.io](http://reactivex.io/documentation/operators/skip.html)

     - parameter count: The number of elements to skip before returning the remaining elements.
     - returns: An observable sequence that contains the elements that occur after the specified index in the input sequence.
     */
    func skip(_ count: Int)
        -> Observable<Element>
    {
        SkipCount(source: self.asObservable(), count: count)
    }
}

public extension ObservableType {
    /**
     Skips elements for the specified duration from the start of the observable source sequence, using the specified scheduler to run timers.

     - seealso: [skip operator on reactivex.io](http://reactivex.io/documentation/operators/skip.html)

     - parameter duration: Duration for skipping elements from the start of the sequence.
     - parameter scheduler: Scheduler to run the timer on.
     - returns: An observable sequence with the elements skipped during the specified duration from the start of the source sequence.
     */
    func skip(_ duration: RxTimeInterval, scheduler: SchedulerType)
        -> Observable<Element>
    {
        SkipTime(source: self.asObservable(), duration: duration, scheduler: scheduler)
    }
}

// count version

private final class SkipCountSink<Observer: ObserverType>: Sink<Observer>, ObserverType {
    typealias Element = Observer.Element
    typealias Parent = SkipCount<Element>

    let parent: Parent

    var remaining: Int

    init(parent: Parent, observer: Observer, cancel: Cancelable) async {
        self.parent = parent
        self.remaining = parent.count
        await super.init(observer: observer, cancel: cancel)
    }

    func on(_ event: Event<Element>) async {
        switch event {
        case .next(let value):

            if self.remaining <= 0 {
                await self.forwardOn(.next(value))
            }
            else {
                self.remaining -= 1
            }
        case .error:
            await self.forwardOn(event)
            await self.dispose()
        case .completed:
            await self.forwardOn(event)
            await self.dispose()
        }
    }
}

private final class SkipCount<Element>: Producer<Element> {
    let source: Observable<Element>
    let count: Int

    init(source: Observable<Element>, count: Int) {
        self.source = source
        self.count = count
    }

    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) async -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        let sink = await SkipCountSink(parent: self, observer: observer, cancel: cancel)
        let subscription = await self.source.subscribe(sink)

        return (sink: sink, subscription: subscription)
    }
}

// time version

private final class SkipTimeSink<Element, Observer: ObserverType>: Sink<Observer>, ObserverType where Observer.Element == Element {
    typealias Parent = SkipTime<Element>

    let parent: Parent

    // state
    var open = false

    init(parent: Parent, observer: Observer, cancel: Cancelable) async {
        self.parent = parent
        await super.init(observer: observer, cancel: cancel)
    }

    func on(_ event: Event<Element>) async {
        switch event {
        case .next(let value):
            if self.open {
                await self.forwardOn(.next(value))
            }
        case .error:
            await self.forwardOn(event)
            await self.dispose()
        case .completed:
            await self.forwardOn(event)
            await self.dispose()
        }
    }

    func tick() {
        self.open = true
    }

    func run() async -> Disposable {
        let disposeTimer = await self.parent.scheduler.scheduleRelative((), dueTime: self.parent.duration) { _ in
            self.tick()
            return Disposables.create()
        }

        let disposeSubscription = await self.parent.source.subscribe(self)

        return await Disposables.create(disposeTimer, disposeSubscription)
    }
}

private final class SkipTime<Element>: Producer<Element> {
    let source: Observable<Element>
    let duration: RxTimeInterval
    let scheduler: SchedulerType

    init(source: Observable<Element>, duration: RxTimeInterval, scheduler: SchedulerType) {
        self.source = source
        self.scheduler = scheduler
        self.duration = duration
    }

    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) async -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        let sink = await SkipTimeSink(parent: self, observer: observer, cancel: cancel)
        let subscription = await sink.run()
        return (sink: sink, subscription: subscription)
    }
}
