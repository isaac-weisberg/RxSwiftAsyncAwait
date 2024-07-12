//
//  Timeout.swift
//  RxSwift
//
//  Created by Tomi Koskinen on 13/11/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

import Foundation

public extension ObservableType {
    /**
     Applies a timeout policy for each element in the observable sequence. If the next element isn't received within the specified timeout duration starting from its predecessor, a TimeoutError is propagated to the observer.

     - seealso: [timeout operator on reactivex.io](http://reactivex.io/documentation/operators/timeout.html)

     - parameter dueTime: Maximum duration between values before a timeout occurs.
     - parameter scheduler: Scheduler to run the timeout timer on.
     - returns: An observable sequence with a `RxError.timeout` in case of a timeout.
     */
    func timeout(_ dueTime: RxTimeInterval, scheduler: SchedulerType)
        -> Observable<Element>
    {
        return Timeout(source: self.asObservable(), dueTime: dueTime, other: Observable.error(RxError.timeout), scheduler: scheduler)
    }

    /**
     Applies a timeout policy for each element in the observable sequence, using the specified scheduler to run timeout timers. If the next element isn't received within the specified timeout duration starting from its predecessor, the other observable sequence is used to produce future messages from that point on.

     - seealso: [timeout operator on reactivex.io](http://reactivex.io/documentation/operators/timeout.html)

     - parameter dueTime: Maximum duration between values before a timeout occurs.
     - parameter other: Sequence to return in case of a timeout.
     - parameter scheduler: Scheduler to run the timeout timer on.
     - returns: The source sequence switching to the other sequence in case of a timeout.
     */
    func timeout<Source: ObservableConvertibleType>(_ dueTime: RxTimeInterval, other: Source, scheduler: SchedulerType)
        -> Observable<Element> where Element == Source.Element
    {
        return Timeout(source: self.asObservable(), dueTime: dueTime, other: other.asObservable(), scheduler: scheduler)
    }
}

private final class TimeoutSink<Observer: ObserverType>: Sink<Observer>, LockOwnerType, ObserverType {
    typealias Element = Observer.Element
    typealias Parent = Timeout<Element>
    
    private let parent: Parent
    
    let lock: RecursiveLock

    private let timerD: SerialDisposable
    private let subscription: SerialDisposable
    
    private var id = 0
    private var switched = false
    
    init(parent: Parent, observer: Observer, cancel: Cancelable) async {
        self.lock = await RecursiveLock()
        self.timerD = await SerialDisposable()
        self.subscription = await SerialDisposable()
        self.parent = parent
        await super.init(observer: observer, cancel: cancel)
    }
    
    func run() async -> Disposable {
        let original = await SingleAssignmentDisposable()
        await self.subscription.setDisposable(original)
        
        await self.createTimeoutTimer()
        
        await original.setDisposable(self.parent.source.subscribe(self))
        
        return await Disposables.create(self.subscription, self.timerD)
    }

    func on(_ event: Event<Element>) async {
        switch event {
        case .next:
            var onNextWins = false
            
            await self.lock.performLocked {
                onNextWins = !self.switched
                if onNextWins {
                    self.id = self.id &+ 1
                }
            }
            
            if onNextWins {
                await self.forwardOn(event)
                await self.createTimeoutTimer()
            }
        case .error, .completed:
            var onEventWins = false
            
            await self.lock.performLocked {
                onEventWins = !self.switched
                if onEventWins {
                    self.id = self.id &+ 1
                }
            }
            
            if onEventWins {
                await self.forwardOn(event)
                await self.dispose()
            }
        }
    }
    
    private func createTimeoutTimer() async {
        if await self.timerD.isDisposed() {
            return
        }
        
        let nextTimer = await SingleAssignmentDisposable()
        await self.timerD.setDisposable(nextTimer)
        
        let disposeSchedule = await self.parent.scheduler.scheduleRelative(self.id, dueTime: self.parent.dueTime) { state in
            
            var timerWins = false
            
            await self.lock.performLocked {
                self.switched = (state == self.id)
                timerWins = self.switched
            }
            
            if timerWins {
                await self.subscription.setDisposable(self.parent.other.subscribe(self.forwarder()))
            }
            
            return Disposables.create()
        }

        await nextTimer.setDisposable(disposeSchedule)
    }
}

private final class Timeout<Element>: Producer<Element> {
    fileprivate let source: Observable<Element>
    fileprivate let dueTime: RxTimeInterval
    fileprivate let other: Observable<Element>
    fileprivate let scheduler: SchedulerType
    
    init(source: Observable<Element>, dueTime: RxTimeInterval, other: Observable<Element>, scheduler: SchedulerType) {
        self.source = source
        self.dueTime = dueTime
        self.other = other
        self.scheduler = scheduler
    }
    
    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) async -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        let sink = await TimeoutSink(parent: self, observer: observer, cancel: cancel)
        let subscription = await sink.run()
        return (sink: sink, subscription: subscription)
    }
}
