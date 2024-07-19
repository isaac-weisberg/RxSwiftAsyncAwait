//
//  Window.swift
//  RxSwift
//
//  Created by Junior B. on 29/10/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

import Foundation

public extension ObservableType {
    /**
     Projects each element of an observable sequence into a window that is completed when either it’s full or a given amount of time has elapsed.

     - seealso: [window operator on reactivex.io](http://reactivex.io/documentation/operators/window.html)

     - parameter timeSpan: Maximum time length of a window.
     - parameter count: Maximum element count of a window.
     - parameter scheduler: Scheduler to run windowing timers on.
     - returns: An observable sequence of windows (instances of `Observable`).
     */
    func window(timeSpan: RxTimeInterval, count: Int, scheduler: SchedulerType) async
        -> Observable<Observable<Element>>
    {
        return await WindowTimeCount(source: self.asObservable(), timeSpan: timeSpan, count: count, scheduler: scheduler)
    }
}

private final class WindowTimeCountSink<Element, Observer: ObserverType>:
    Sink<Observer>,
    ObserverType,
    LockOwnerType,
    SynchronizedOnType where Observer.Element == Observable<Element>
{
    typealias Parent = WindowTimeCount<Element>
    
    private let parent: Parent
    
    let lock: RecursiveLock
    
    private var subject: PublishSubject<Element>
    private var count = 0
    private var windowId = 0
    
    private let timerD: SerialDisposable
    private let refCountDisposable: RefCountDisposable
    private let groupDisposable: CompositeDisposable
    
    init(parent: Parent, observer: Observer, cancel: Cancelable) async {
        subject = await PublishSubject<Element>()
        self.timerD = await SerialDisposable()
        self.lock = await RecursiveLock()
        self.parent = parent
        self.groupDisposable = await CompositeDisposable()
        
        _ = await self.groupDisposable.insert(self.timerD)
        
        self.refCountDisposable = await RefCountDisposable(disposable: self.groupDisposable)
        await super.init(observer: observer, cancel: cancel)
    }
    
    func run(_ c: C) async -> Disposable {
        await self.forwardOn(.next(AddRef(source: self.subject, refCount: self.refCountDisposable).asObservable()), c.call())
        await self.createTimer(c.call(), self.windowId)
        
        _ = await self.groupDisposable.insert(self.parent.source.subscribe(c.call(), self))
        return self.refCountDisposable
    }
    
    func startNewWindowAndCompleteCurrentOne(_ c: C) async {
        await self.subject.on(.completed, c.call())
        self.subject = await PublishSubject<Element>()
        
        await self.forwardOn(.next(AddRef(source: self.subject, refCount: self.refCountDisposable).asObservable()), c.call())
    }

    func on(_ event: Event<Element>, _ c: C) async {
        await self.synchronizedOn(event, c.call())
    }

    func synchronized_on(_ event: Event<Element>, _ c: C) async {
        var newWindow = false
        var newId = 0
        
        switch event {
        case .next(let element):
            await self.subject.on(.next(element), c.call())
            
            do {
                _ = try incrementChecked(&self.count)
            } catch let e {
                await self.subject.on(.error(e as Swift.Error), c.call())
                await self.dispose()
            }
            
            if self.count == self.parent.count {
                newWindow = true
                self.count = 0
                self.windowId += 1
                newId = self.windowId
                await self.startNewWindowAndCompleteCurrentOne(c.call())
            }
            
        case .error(let error):
            await self.subject.on(.error(error), c.call())
            await self.forwardOn(.error(error), c.call())
            await self.dispose()

        case .completed:
            await self.subject.on(.completed, c.call())
            await self.forwardOn(.completed, c.call())
            await self.dispose()
        }

        if newWindow {
            await self.createTimer(c.call(), newId)
        }
    }
    
    func createTimer(_ c: C, _ windowId: Int) async {
        if await self.timerD.isDisposed() {
            return
        }
        
        if self.windowId != windowId {
            return
        }

        let nextTimer = await SingleAssignmentDisposable()

        await self.timerD.setDisposable(nextTimer)

        let scheduledRelative = await self.parent.scheduler.scheduleRelative(windowId, c.call(), dueTime: self.parent.timeSpan) { c, previousWindowId in
            
            var newId = 0
            
            await self.lock.performLocked {
                if previousWindowId != self.windowId {
                    return
                }
                
                self.count = 0
                self.windowId = self.windowId &+ 1
                newId = self.windowId
                await self.startNewWindowAndCompleteCurrentOne(C())
            }
            
            await self.createTimer(c.call(), newId)
            
            return Disposables.create()
        }

        await nextTimer.setDisposable(scheduledRelative)
    }
}

private final class WindowTimeCount<Element>: Producer<Observable<Element>> {
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
    
    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer, cancel: Cancelable) async -> (sink: Disposable, subscription: Disposable) where Observer.Element == Observable<Element> {
        let sink = await WindowTimeCountSink(parent: self, observer: observer, cancel: cancel)
        let subscription = await sink.run(C())
        return (sink: sink, subscription: subscription)
    }
}
