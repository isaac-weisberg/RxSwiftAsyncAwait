//
//  Buffer.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 9/13/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

import Foundation

public extension ObservableType {
    /**
     Projects each element of an observable sequence into a buffer that's sent out when either it's full or a given amount of time has elapsed, using the specified scheduler to run timers.

     A useful real-world analogy of this overload is the behavior of a ferry leaving the dock when all seats are taken, or at the scheduled time of departure, whichever event occurs first.

     - seealso: [buffer operator on reactivex.io](http://reactivex.io/documentation/operators/buffer.html)

     - parameter timeSpan: Maximum time length of a buffer.
     - parameter count: Maximum element count of a buffer.
     - parameter scheduler: Scheduler to run buffering timers on.
     - returns: An observable sequence of buffers.
     */
    func buffer(timeSpan: RxTimeInterval, count: Int, scheduler: SchedulerType) async
        -> Observable<[Element]>
    {
        await BufferTimeCount(source: self.asObservable(), timeSpan: timeSpan, count: count, scheduler: scheduler)
    }
}

private final class BufferTimeCount<Element>: Producer<[Element]> {
    fileprivate let timeSpan: RxTimeInterval
    fileprivate let count: Int
    fileprivate let scheduler: SchedulerType
    fileprivate let source: Observable<Element>
    
    init(source: Observable<Element>, timeSpan: RxTimeInterval, count: Int, scheduler: SchedulerType) async {
        self.source = source
        self.timeSpan = timeSpan
        self.count = count
        self.scheduler = scheduler
        await super.init()
    }
    
    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer, cancel: Cancelable) async -> (sink: Disposable, subscription: Disposable) where Observer.Element == [Element] {
        let sink = await BufferTimeCountSink(parent: self, observer: observer, cancel: cancel)
        let subscription = await sink.run(c.call())
        return (sink: sink, subscription: subscription)
    }
}

private final class BufferTimeCountSink<Element, Observer: ObserverType>:
    Sink<Observer>,
    LockOwnerType,
    ObserverType,
    SynchronizedOnType where Observer.Element == [Element]
{
    typealias Parent = BufferTimeCount<Element>
    
    private let parent: Parent
    
    let lock: RecursiveLock
    
    // state
    private let timerD: SerialDisposable
    private var buffer = [Element]()
    private var windowID = 0
    
    init(parent: Parent, observer: Observer, cancel: Cancelable) async {
        self.timerD = await SerialDisposable()
        self.lock = await RecursiveLock()
        self.parent = parent
        await super.init(observer: observer, cancel: cancel)
    }
 
    func run(_ c: C) async -> Disposable {
        await self.createTimer(c.call(), self.windowID)
        return await Disposables.create(self.timerD, await self.parent.source.subscribe(c.call(), self))
    }
    
    func startNewWindowAndSendCurrentOne(_ c: C) async {
        self.windowID = self.windowID &+ 1
        let windowID = self.windowID
        
        let buffer = self.buffer
        self.buffer = []
        await self.forwardOn(.next(buffer), c.call())
        
        await self.createTimer(c.call(), windowID)
    }
    
    func on(_ event: Event<Element>, _ c: C) async {
        await self.synchronizedOn(event, c.call())
    }

    func synchronized_on(_ event: Event<Element>, _ c: C) async {
        switch event {
        case .next(let element):
            self.buffer.append(element)
            
            if self.buffer.count == self.parent.count {
                await self.startNewWindowAndSendCurrentOne(c.call())
            }
            
        case .error(let error):
            self.buffer = []
            await self.forwardOn(.error(error), c.call())
            await self.dispose()

        case .completed:
            await self.forwardOn(.next(self.buffer), c.call())
            await self.forwardOn(.completed, c.call())
            await self.dispose()
        }
    }
    
    func createTimer(_ c: C, _ windowID: Int) async {
        if await self.timerD.isDisposed() {
            return
        }
        
        if self.windowID != windowID {
            return
        }

        let nextTimer = await SingleAssignmentDisposable()
        
        await self.timerD.setDisposable(nextTimer)

        let disposable = await self.parent.scheduler.scheduleRelative(windowID, c.call(), dueTime: self.parent.timeSpan) { c, previousWindowID in
            await self.lock.performLocked {
                if previousWindowID != self.windowID {
                    return
                }
             
                await self.startNewWindowAndSendCurrentOne(c.call())
            }
            
            return Disposables.create()
        }

        await nextTimer.setDisposable(disposable)
    }
}
