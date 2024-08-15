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
    static func just(_ element: Element) -> Observable<Element> {
        Just(element: element)
    }

    /**
     Returns an observable sequence that contains a single element.

     - seealso: [just operator on reactivex.io](http://reactivex.io/documentation/operators/just.html)

     - parameter element: Single element in the resulting observable sequence.
     - parameter scheduler: Scheduler to send the single element on.
     - returns: An observable sequence containing the single specified element.
     */
    static func just(_ element: Element, scheduler: AsyncScheduler) async -> Observable<Element> {
        JustScheduled(element: element, scheduler: scheduler)
    }
}

private final actor JustScheduledSink<Observer: SyncObserverType>: AsynchronousDisposable, ActorLock {
    typealias Parent = JustScheduled<Observer.Element>

    private let parent: Parent
    private let observer: Observer
    private let disposedFlag = SingleAssignmentSyncDisposable()

    init(parent: Parent, observer: Observer) {
        self.parent = parent
        self.observer = observer
    }

    func dispose() {
        disposedFlag.dispose()?.dispose()
    }

    func run(_ c: C) async {
        let scheduler = parent.scheduler
        let element = parent.element
        scheduler.perform(locking(disposedFlag), c.call()) { [observer] c in
            await observer.on(.next(element), c.call())
            await observer.on(.completed, c.call())
        }
        dispose()
    }
    
    func perform<R>(_ work: () -> R) -> R {
        work()
    }
}

private final class JustScheduled<Element: Sendable>: Observable<Element>, @unchecked Sendable {
    fileprivate let scheduler: AsyncScheduler
    fileprivate let element: Element

    init(element: Element, scheduler: AsyncScheduler) {
        self.scheduler = scheduler
        self.element = element
        super.init()
    }

    override func subscribe<Observer>(_ c: C, _ observer: Observer) async -> any Disposable
        where Element == Observer.Element, Observer: ObserverType {
        let sink = JustScheduledSink(parent: self, observer: observer)
        await sink.run(c.call())
        return sink
    }
}

private final class Just<Element: Sendable>: Observable<Element> {
    private let element: Element

    init(element: Element) {
        self.element = element
        super.init()
    }
    
    override func subscribe<Observer>(_ c: C, _ observer: Observer) async -> any Disposable where Element == Observer.Element, Observer : ObserverType {
        await observer.on(.next(element), c.call())
        await observer.on(.completed, c.call())
        return Disposables.create()
    }
}
