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
    static func create(_ subscribe: @escaping (C, AnyObserver<Element>) async -> Disposable) async
        -> Observable<Element> {
        await AnonymousObservable(subscribe)
    }
}

private final actor AnonymousObservableSink<Observer: ObserverType>: Sink, ObserverType {
    typealias Element = Observer.Element
    typealias Parent = AnonymousObservable<Element>

    let baseSink: BaseSink<Observer>

    // state
    private let isStopped: NonAtomicInt

    #if DEBUG
        private let synchronizationTracker: SynchronizationTracker
    #endif

    init(observer: Observer, cancel: Cancelable) async {
        isStopped = NonAtomicInt(0)
        #if DEBUG
            synchronizationTracker = await SynchronizationTracker()
        #endif
        baseSink = await BaseSink(observer: observer, cancel: cancel)
    }

    func on(_ event: Event<Element>, _ c: C) async {
        #if DEBUG
            await synchronizationTracker.register(synchronizationErrorMessage: .default)
        #endif
        await scope {
            switch event {
            case .next:
                if load(self.isStopped) == 1 {
                    return
                }
                await self.forwardOn(event, c.call())
            case .error, .completed:
                if fetchOr(self.isStopped, 1) == 0 {
                    await self.forwardOn(event, c.call())
                    await self.dispose()
                }
            }
        }
        #if DEBUG
            await synchronizationTracker.unregister()
        #endif
    }

    func run(_ parent: Parent, _ c: C) async -> Disposable {
        await parent.subscribeHandler(c.call(), AnyObserver(self))
    }
}

private final class AnonymousObservable<Element>: Producer<Element> {
    typealias SubscribeHandler = (C, AnyObserver<Element>) async -> Disposable

    let subscribeHandler: SubscribeHandler

    init(_ subscribeHandler: @escaping SubscribeHandler) async {
        self.subscribeHandler = subscribeHandler
        await super.init()
    }

    override func run<Observer: ObserverType>(
        _ c: C,
        _ observer: Observer,
        cancel: Cancelable
    )
        async -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        let sink = await AnonymousObservableSink(observer: observer, cancel: cancel)
        let subscription = await sink.run(self, c.call())
        return (sink: sink, subscription: subscription)
    }
}

func scope<R>(_ work: () async -> R) async -> R {
    await work()
}
