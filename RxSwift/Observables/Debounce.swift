//
//  Debounce.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 9/11/16.
//  Copyright © 2016 Krunoslav Zaher. All rights reserved.
//

import Foundation

public extension ObservableType {
    /**
     Ignores elements from an observable sequence which are followed by another element within a specified relative time duration, using the specified scheduler to run throttling timers.

     - seealso: [debounce operator on reactivex.io](http://reactivex.io/documentation/operators/debounce.html)

     - parameter dueTime: Throttling duration for each element.
     - parameter scheduler: Scheduler to run the throttle timers on.
     - returns: The throttled sequence.
     */
    func debounce(_ dueTime: RxTimeInterval, scheduler: SchedulerType) async
        -> Observable<Element> {
        await Debounce(source: asObservable(), dueTime: dueTime, scheduler: scheduler)
    }
}

private final actor DebounceSink<Observer: ObserverType>:
    Sink,
    ObserverType,
    AsynchronousOnType {
    typealias Element = Observer.Element
    typealias ParentType = Debounce<Element>

    let baseSink: BaseSink<Observer>

    private let parent: ParentType

    // state
    private var id = 0 as UInt64
    private var value: Element?

    let cancellable: SerialDisposable

    init(parent: ParentType, observer: Observer) async {
        cancellable = await SerialDisposable()
        self.parent = parent

        baseSink = BaseSink(observer: observer)
    }

    func run(_ c: C) async -> Disposable {
        let subscription = await parent.source.subscribe(c.call(), self)

        return await Disposables.create(subscription, cancellable)
    }

    func on(_ event: Event<Element>, _ c: C) async {
        await AsynchronousOn(event, c.call())
    }

    func Asynchronous_on(_ event: Event<Element>, _ c: C) async {
        switch event {
        case .next(let element):
            id = id &+ 1
            let currentId = id
            value = element

            let scheduler = parent.scheduler
            let dueTime = parent.dueTime

            let d = await SingleAssignmentDisposable()
            await cancellable.setDisposable(d)
            await d.setDisposable(scheduler.scheduleRelative(currentId, c.call(), dueTime: dueTime, action: propagate))
        case .error:
            value = nil
            await forwardOn(event, c.call())
            await dispose()
        case .completed:
            if let value {
                self.value = nil
                await forwardOn(.next(value), c.call())
            }
            await forwardOn(.completed, c.call())
            await dispose()
        }
    }

    func propagate(c: C, _ currentId: UInt64) async -> Disposable {
        let originalValue = value

        if let value = originalValue, id == currentId {
            self.value = nil
            await forwardOn(.next(value), c.call())
        }

        return Disposables.create()
    }
}

private final class Debounce<Element>: Producer<Element> {
    fileprivate let source: Observable<Element>
    fileprivate let dueTime: RxTimeInterval
    fileprivate let scheduler: SchedulerType

    init(source: Observable<Element>, dueTime: RxTimeInterval, scheduler: SchedulerType) async {
        self.source = source
        self.dueTime = dueTime
        self.scheduler = scheduler
        await super.init()
    }

    override func run<Observer: ObserverType>(
        _ c: C,
        _ observer: Observer
    )
        async -> AsynchronousDisposable where Observer.Element == Element {
        let sink = await DebounceSink(parent: self, observer: observer)
        let subscription = await sink.run(c.call())
        return sink
    }
}
