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
        -> Observable<Element> {
        SkipCount(source: asObservable(), count: count)
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
    func skip(_ duration: RxTimeInterval)
        -> Observable<Element> {
        SkipTime(source: asObservable(), duration: duration)
    }
}

// count version

private final actor SkipCountSink<Observer: ObserverType>: SinkOverSingleSubscription, ObserverType {
    typealias Element = Observer.Element
    typealias Parent = SkipCount<Element>

    let parent: Parent
    let baseSink: BaseSinkOverSingleSubscription<Observer>

    var remaining: Int

    init(parent: Parent, observer: Observer) {
        self.parent = parent
        remaining = parent.count
        baseSink = BaseSinkOverSingleSubscription(observer: observer)
    }

    func on(_ event: Event<Element>, _ c: C) async {
        switch event {
        case .next(let value):

            if remaining <= 0 {
                await forwardOn(.next(value), c.call())
            } else {
                remaining -= 1
            }
        case .error:
            await forwardOn(event, c.call())
            await dispose()
        case .completed:
            await forwardOn(event, c.call())
            await dispose()
        }
    }

    func dispose() async {
        await baseSink.setDisposed()?.dispose()
    }
}

private final class SkipCount<Element: Sendable>: Producer<Element> {
    let source: Observable<Element>
    let count: Int

    init(source: Observable<Element>, count: Int) {
        self.source = source
        self.count = count
        super.init()
    }

    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> AsynchronousDisposable
        where Observer.Element == Element {
        let sink = SkipCountSink(parent: self, observer: observer)
        await sink.run(c.call(), source)

        return sink
    }
}

// time version

private final actor SkipTimeSink<Element, Observer: ObserverType>: SinkOverSingleSubscription,
    ObserverType where Observer.Element == Element {
    typealias Parent = SkipTime<Element>

    let parent: Parent
    let baseSink: BaseSinkOverSingleSubscription<Observer>

    // state
    var open = false
    let timerDisposable = SingleAssignmentDisposableContainer<DisposableTimer>()

    init(parent: Parent, observer: Observer) async {
        self.parent = parent
        baseSink = BaseSinkOverSingleSubscription(observer: observer)
    }

    func on(_ event: Event<Element>, _ c: C) async {
        if baseSink.disposed {
            return
        }
        switch event {
        case .next(let value):
            if open {
                await forwardOn(.next(value), c.call())
            }
        case .error:
            await forwardOn(event, c.call())
            await dispose()
        case .completed:
            await forwardOn(event, c.call())
            await dispose()
        }
    }

    func tick() {
        open = true
    }

    func run(_ c: C, _ source: Observable<Element>) async {
        let timer = DisposableTimer(parent.duration) { [weak self] _ in
            await self?.tick()
        }

        timerDisposable.setDisposable(timer)?.dispose()

        await baseSink.sourceDisposable.setDisposable(source.subscribe(c.call(), self))?.dispose()
    }

    func dispose() async {
        let disp = baseSink.setDisposed()
        timerDisposable.dispose()?.dispose()

        await disp?.dispose()
    }
}

private final class SkipTime<Element: Sendable>: Producer<Element> {
    let source: Observable<Element>
    let duration: RxTimeInterval

    init(source: Observable<Element>, duration: RxTimeInterval) {
        self.source = source
        self.duration = duration
        super.init()
    }

    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> AsynchronousDisposable
        where Observer.Element == Element {
        let sink = await SkipTimeSink(parent: self, observer: observer)
        await sink.run(c.call(), source)
        return sink
    }
}
