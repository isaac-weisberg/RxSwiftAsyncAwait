//
//  Create.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/8/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

public extension ObservableType {
    // MARK: create

    /**
     Creates an observable sequence from a specified subscribe method implementation.

     - seealso: [create operator on reactivex.io](http://reactivex.io/documentation/operators/create.html)

     - parameter subscribe: Implementation of the resulting observable sequence's `subscribe` method.
     - returns: The observable sequence with the specified implementation for the `subscribe` method.
     */
    static func create(_ subscribe: @escaping (C, AnyAsyncObserver<Element>) async -> SynchronizedDisposable) async
        -> Observable<Element> {
        await AnonymousObservable(subscribe)
    }

    /**
     Creates an observable sequence from a specified subscribe method implementation.

     - seealso: [create operator on reactivex.io](http://reactivex.io/documentation/operators/create.html)

     - parameter subscribe: Implementation of the resulting observable sequence's `subscribe` method.
     - returns: The observable sequence with the specified implementation for the `subscribe` method.
     */
    static func createUnsynchronized(
        _ subscribe: @escaping (C, AnySyncObserver<Element>)
            -> UnsynchronizedDisposable
    )
        -> UnsynchronizedObservable<Element> {
        AnonymousUnsynchronizedObservable(subscribe)
    }
}

private final actor AnonymousObservableSink<
    Observer: AsyncObserverType
>: AsyncObserverType, SynchronizedDisposable {
    typealias Element = Observer.Element
    typealias SubscribeHandler = AnonymousObservable<Element>.SubscribeHandler

    // state
    private let isStopped: NonAtomicInt
    private var innerDisposable: SynchronizedDisposable?
    private let observer: Observer

    init(observer: Observer) {
        isStopped = NonAtomicInt(0)
        self.observer = observer
    }

    func on(_ event: Event<Element>, _ c: C) async {
        switch event {
        case .next:
            if load(isStopped) == 1 {
                return
            }
            await observer.on(event, c.call())
        case .error, .completed:
            if fetchOr(isStopped, 1) == 0 {
                await observer.on(event, c.call())
                await dispose()
            }
        }
    }

    func dispose() async {
        if fetchOr(isStopped, 1) == 0 {
            let innerDisposable = self.innerDisposable
            self.innerDisposable = nil
            await innerDisposable?.dispose()
        }
    }

    func run(_ subscribeHandler: SubscribeHandler, _ c: C) async {
        innerDisposable = await subscribeHandler(c.call(), AnyAsyncObserver(eventHandler: on))
    }
}

private final class AnonymousObservable<Element>: Observable<Element> {
    typealias SubscribeHandler = (C, AnyAsyncObserver<Element>) async -> SynchronizedDisposable

    let subscribeHandler: SubscribeHandler

    init(_ subscribeHandler: @escaping SubscribeHandler) async {
        self.subscribeHandler = subscribeHandler
        await super.init()
    }

    override func subscribe<Observer>(_ c: C, _ observer: Observer) async -> any SynchronizedDisposable
        where Element == Observer.Element, Observer: ObserverType {
        let sink = AnonymousObservableSink(observer: AnyAsyncObserver(eventHandler: { e, c in
            switch observer.on {
            case .sync(let syncObserverEventHandler):
                syncObserverEventHandler(e, c.call())
            case .async(let asyncObserverEventHandler):
                await asyncObserverEventHandler(e, c.call())
            }
        }))
        await sink.run(subscribeHandler, c.call())
        return sink
    }
}

func scope<R>(_ work: () async -> R) async -> R {
    await work()
}

private final class AnonymousUnsynchronizedObservableSink<
    Observer: SyncObserverType
>: SyncObserverType, UnsynchronizedDisposable {
    typealias Element = Observer.Element
    typealias SubscribeHandler = AnonymousUnsynchronizedObservable<Element>.SubscribeHandler

    // state
    private let isStopped: NonAtomicInt
    private var innerDisposable: UnsynchronizedDisposable?
    private let observer: Observer

    init(observer: Observer) {
        isStopped = NonAtomicInt(0)
        self.observer = observer
    }

    func on(_ event: Event<Element>, _ c: C) {
        switch event {
        case .next:
            if load(isStopped) == 1 {
                return
            }
            forwardOn(event, c.call())
        case .error, .completed:
            if fetchOr(isStopped, 1) == 0 {
                forwardOn(event, c.call())
                dispose()
            }
        }
    }

    func dispose() {
        if fetchOr(isStopped, 1) == 0 {
            innerDisposable?.dispose()
            innerDisposable = nil
        }
    }

    func forwardOn(_ event: Event<Observer.Element>, _ c: C) {
        observer.on(event, c.call())
    }

    func run(_ subscribeHandler: SubscribeHandler, _ c: C) {
        innerDisposable = subscribeHandler(c.call(), AnySyncObserver(eventHandler: on))
    }
}

private final class AnonymousUnsynchronizedObservable<Element>: UnsynchronizedObservable<Element> {
    typealias SubscribeHandler = (C, AnySyncObserver<Element>) -> UnsynchronizedDisposable

    let subscribeHandler: SubscribeHandler

    init(_ subscribeHandler: @escaping SubscribeHandler) {
        self.subscribeHandler = subscribeHandler
        super.init()
    }

    override func subscribe<Observer>(_ c: C, _ observer: Observer) -> any UnsynchronizedDisposable
        where Observer: ObserverType, Observer.Element == Element {
        let sink = AnonymousUnsynchronizedObservableSink(observer: AnySyncObserver(eventHandler: { event, c in
            switch observer.on {
            case .sync(let syncObserverEventHandler):
                syncObserverEventHandler(event, c.call())
            case .async(let asyncObserverEventHandler):
                Task {
                    await asyncObserverEventHandler(event, c.call())
                }
            }
        }))
        sink.run(subscribeHandler, c.call())
        return sink
    }
}
