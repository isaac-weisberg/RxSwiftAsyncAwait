//
//  Take.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 6/12/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

import Foundation

public extension ObservableType {
    /**
     Returns a specified number of contiguous elements from the start of an observable sequence.

     - seealso: [take operator on reactivex.io](http://reactivex.io/documentation/operators/take.html)

     - parameter count: The number of elements to return.
     - returns: An observable sequence that contains the specified number of elements from the start of the input sequence.
     */
    func take(_ count: Int)
        -> Observable<Element> {
        if count == 0 {
            return Observable.empty()
        } else {
            return TakeCount(source: asObservable(), count: count)
        }
    }
}

public extension ObservableType {
    /**
     Takes elements for the specified duration from the start of the observable source sequence, using the specified scheduler to run timers.

     - seealso: [take operator on reactivex.io](http://reactivex.io/documentation/operators/take.html)

     - parameter duration: Duration for taking elements from the start of the sequence.
     - parameter scheduler: Scheduler to run the timer on.
     - returns: An observable sequence with the elements taken during the specified duration from the start of the source sequence.
     */
    func take(for duration: RxTimeInterval)
        -> Observable<Element> {
        TakeTime(source: asObservable(), duration: duration)
    }
}

// count version

private final actor TakeCountSink<Observer: ObserverType>: SinkOverSingleSubscription, ObserverType {
    let baseSink: BaseSinkOverSingleSubscription<Observer>

    typealias Element = Observer.Element
    typealias Parent = TakeCount<Element>

    private let parent: Parent

    private var remaining: Int

    init(parent: Parent, observer: Observer) {
        self.parent = parent
        remaining = parent.count
        baseSink = BaseSinkOverSingleSubscription(observer: observer)
    }

    func on(_ event: Event<Element>, _ c: C) async {
        switch event {
        case .next(let value):

            if remaining > 0 {
                remaining -= 1

                await forwardOn(.next(value), c.call())

                if remaining == 0 {
                    await forwardOn(.completed, c.call())
                    await dispose()
                }
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

private final class TakeCount<Element>: Producer<Element> {
    private let source: Observable<Element>
    fileprivate let count: Int

    init(source: Observable<Element>, count: Int) {
        if count < 0 {
            rxFatalError("count can't be negative")
        }
        self.source = source
        self.count = count
        super.init()
    }

    override func run<Observer: ObserverType>(
        _ c: C,
        _ observer: Observer
    )
        async -> AsynchronousDisposable where Observer.Element == Element {
        let sink = TakeCountSink(parent: self, observer: observer)
        await sink.run(c.call(), source)
        return sink
    }
}

// time version

private final actor TakeTimeSink<Element, Observer: ObserverType>:
    SinkOverSingleSubscription,
    ObserverType where Observer.Element == Element {
    let baseSink: BaseSinkOverSingleSubscription<Observer>

    typealias Parent = TakeTime<Element>

    private let parent: Parent

    init(parent: Parent, observer: Observer) {
        self.parent = parent
        baseSink = BaseSinkOverSingleSubscription(observer: observer)
    }

    let timerDisposable = SingleAssignmentDisposableContainer<DisposableTimer>()

    func on(_ event: Event<Element>, _ c: C) async {
        if baseSink.disposed {
            return
        }
        switch event {
        case .next(let value):
            await forwardOn(.next(value), c.call())
        case .error:
            await forwardOn(event, c.call())
            await dispose()
        case .completed:
            await forwardOn(event, c.call())
            await dispose()
        }
    }

    func tick(_ c: C) async {
        await forwardOn(.completed, c.call())
        await dispose()
    }

    func run(_ c: C, _ source: Observable<Element>) async {
        let disposeTimer = DisposableTimer(parent.duration) { _ in
            await self.tick(c.call())
        }
        timerDisposable.setDisposable(disposeTimer)?.dispose()

        await baseSink.sourceDisposable.setDisposable(parent.source.subscribe(c.call(), self))?.dispose()
    }

    func dispose() async {
        let disp = baseSink.setDisposed()
        timerDisposable.dispose()?.dispose()

        await disp?.dispose()
    }
}

private final class TakeTime<Element>: Producer<Element> {
    typealias TimeInterval = RxTimeInterval

    fileprivate let source: Observable<Element>
    fileprivate let duration: TimeInterval

    init(source: Observable<Element>, duration: TimeInterval) {
        self.source = source
        self.duration = duration
        super.init()
    }

    override func run<Observer: ObserverType>(
        _ c: C,
        _ observer: Observer
    )
        async -> AsynchronousDisposable where Observer.Element == Element {
        let sink = TakeTimeSink(parent: self, observer: observer)

        await sink.run(c.call(), source)
        return sink
    }
}
