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
    static func just(_ element: Element) -> SyncObservableToSyncObserver<Element> {
        Just(element: element)
    }

    /**
     Returns an observable sequence that contains a single element.

     - seealso: [just operator on reactivex.io](http://reactivex.io/documentation/operators/just.html)

     - parameter element: Single element in the resulting observable sequence.
     - parameter scheduler: Scheduler to send the single element on.
     - returns: An observable sequence containing the single specified element.
     */
    static func just(_ element: Element, scheduler: ActorScheduler) async -> AsyncObservableToSyncObserver<Element> {
        JustScheduled(element: element, scheduler: scheduler)
    }
}

private final actor JustScheduledSink<Observer: SyncObserverType>: AsynchronousDisposable {
    typealias Parent = JustScheduled<Observer.Element>

    private let parent: Parent
    private let observer: Observer
    var disposed = false

    init(parent: Parent, observer: Observer) {
        self.parent = parent
        self.observer = observer
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

private final class JustScheduled<Element: Sendable>: AsyncObservableToSyncObserver<Element>, @unchecked Sendable {
    fileprivate let scheduler: ActorScheduler
    fileprivate let element: Element

    init(element: Element, scheduler: ActorScheduler) {
        self.scheduler = scheduler
        self.element = element
        super.init()
    }

    override func subscribe<Observer>(_ c: C, _ observer: Observer) async -> AnyDisposable
        where Element == Observer.Element, Observer: SyncObserverType {
        let sink = JustScheduledSink(parent: self, observer: observer)
        await sink.run(c.call())
        return .async(sink)
    }
}

private final class Just<Element: Sendable>: SyncObservableToSyncObserver<Element> {
    private let element: Element

    init(element: Element) {
        self.element = element
        super.init()
    }

    override func subscribe<Observer>(_ c: C, _ observer: Observer) -> any SynchronousDisposable
        where Element == Observer.Element, Observer: SyncObserverType {
        observer.on(.next(element), c.call())
        observer.on(.completed, c.call())
        return Disposables.create()
    }

}
