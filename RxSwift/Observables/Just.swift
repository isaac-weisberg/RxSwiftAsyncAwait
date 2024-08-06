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
    static func just(_ element: Element) -> SynchronousObservable<Element> {
        Just(element: element)
    }

    /**
     Returns an observable sequence that contains a single element.

     - seealso: [just operator on reactivex.io](http://reactivex.io/documentation/operators/just.html)

     - parameter element: Single element in the resulting observable sequence.
     - parameter scheduler: Scheduler to send the single element on.
     - returns: An observable sequence containing the single specified element.
     */
    static func just(_ element: Element, scheduler: ActorScheduler) async -> SynchronousObservable<Element> {
        JustScheduled(element: element, scheduler: scheduler)
    }
}

private final actor JustScheduledSink<Observer: SyncObserverType>: SynchronousDisposable {
    typealias Parent = JustScheduled<Observer.Element>

    private let parent: Parent
    private let observer: Observer
    var disposed = false

    init(parent: Parent, observer: Observer) {
        self.parent = parent
        self.observer = observer
    }

    nonisolated func dispose() {
        Task {
            await dispose()
        }
    }

    func dispose() async {
        if !disposed {
            disposed = true
        }
    }

    func run(_ c: C) async {
        let scheduler = parent.scheduler
        let element = parent.element
        if disposed {
            return
        }
        await scheduler.perform(c.call()) { [observer] c in
            observer.on(.next(element), c.call())
            observer.on(.completed, c.call())
        }
        await dispose()
    }
}

private final class JustScheduled<Element>: SynchronousObservable<Element>, @unchecked Sendable {
    fileprivate let scheduler: ActorScheduler
    fileprivate let element: Element

    init(element: Element, scheduler: ActorScheduler) {
        self.scheduler = scheduler
        self.element = element
        super.init()
    }

    override func subscribe<Observer>(_ c: C, _ observer: Observer) -> any SynchronousDisposable
        where Element == Observer.Element, Observer: ObserverType {

        let sink = JustScheduledSink(parent: self, observer: AnySyncObserver(eventHandler: { e, c in
            switch observer.on {
            case .sync(let syncObserverEventHandler):
                syncObserverEventHandler(e, c.call())
            case .async(let asyncObserverEventHandler):
                Task {
                    await asyncObserverEventHandler(e, c.call())
                }
            }
        }))
        Task {
            await sink.run(c.call())
        }
        return sink
    }
}

private final class Just<Element>: SynchronousObservable<Element> {
    private let element: Element

    init(element: Element) {
        self.element = element
        super.init()
    }

    override func subscribe<Observer: ObserverType>(
        _ c: C,
        _ observer: Observer
    )
        -> SynchronousDisposable where Observer.Element == Element {

        switch observer.on {
        case .sync(let syncObserverEventHandler):

            syncObserverEventHandler(.next(element), c.call())
            syncObserverEventHandler(.completed, c.call())
        case .async(let asyncObserverEventHandler):

            Task {
                await asyncObserverEventHandler(.next(element), c.call())
                await asyncObserverEventHandler(.completed, c.call())
            }
        }
        return Disposables.create()
    }
}
