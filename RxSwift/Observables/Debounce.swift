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
        -> Observable<Element>
    {
        return await Debounce(source: self.asObservable(), dueTime: dueTime, scheduler: scheduler)
    }
}

private final class DebounceSink<Observer: ObserverType>:
    Sink<Observer>,
    ObserverType,
    LockOwnerType,
    SynchronizedOnType
{
    typealias Element = Observer.Element
    typealias ParentType = Debounce<Element>

    private let parent: ParentType

    let lock: RecursiveLock

    // state
    private var id = 0 as UInt64
    private var value: Element?

    let cancellable: SerialDisposable

    init(parent: ParentType, observer: Observer, cancel: Cancelable) async {
        self.cancellable = await SerialDisposable()
        self.lock = await RecursiveLock()
        self.parent = parent

        await super.init(observer: observer, cancel: cancel)
    }

    func run() async -> Disposable {
        let subscription = await self.parent.source.subscribe(self)

        return await Disposables.create(subscription, self.cancellable)
    }

    func on(_ event: Event<Element>) async {
        await self.synchronizedOn(event)
    }

    func synchronized_on(_ event: Event<Element>) async {
        switch event {
        case .next(let element):
            self.id = self.id &+ 1
            let currentId = self.id
            self.value = element

            let scheduler = self.parent.scheduler
            let dueTime = self.parent.dueTime

            let d = await SingleAssignmentDisposable()
            await self.cancellable.setDisposable(d)
            await d.setDisposable(scheduler.scheduleRelative(currentId, dueTime: dueTime, action: self.propagate))
        case .error:
            self.value = nil
            await self.forwardOn(event)
            await self.dispose()
        case .completed:
            if let value = self.value {
                self.value = nil
                await self.forwardOn(.next(value))
            }
            await self.forwardOn(.completed)
            await self.dispose()
        }
    }

    func propagate(_ currentId: UInt64) async -> Disposable {
        await self.lock.performLocked {
            let originalValue = self.value

            if let value = originalValue, self.id == currentId {
                self.value = nil
                await self.forwardOn(.next(value))
            }

            return Disposables.create()
        }
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

    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) async -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        let sink = await DebounceSink(parent: self, observer: observer, cancel: cancel)
        let subscription = await sink.run()
        return (sink: sink, subscription: subscription)
    }
}
