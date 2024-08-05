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
    static func create(_ subscribe: @escaping (C, AnyObserver<Element>) async -> SynchronizedDisposable) async
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
    private var innerDisposable: SynchronizedDisposable?

    init(observer: Observer) {
        isStopped = NonAtomicInt(0)
        baseSink = BaseSink(observer: observer)
    }

    func on(_ event: Event<Element>, _ c: C) async {
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
    }

    func dispose() async {
        if fetchOr(isStopped, 1) == 0 {
            await innerDisposable?.dispose()
            innerDisposable = nil
        }

    }

    func forwardOn(_ event: Event<Observer.Element>, _ c: C) async {
        await baseSink.observer.on(event, c.call())
    }

    func run(_ parent: Parent, _ c: C) async {
        innerDisposable = await parent.subscribeHandler(c.call(), AnyObserver(self))
    }
}

private final class AnonymousObservable<Element>: Producer<Element> {
    typealias SubscribeHandler = (C, AnyObserver<Element>) async -> SynchronizedDisposable

    let subscribeHandler: SubscribeHandler

    init(_ subscribeHandler: @escaping SubscribeHandler) async {
        self.subscribeHandler = subscribeHandler
        await super.init()
    }

    override func run<Observer: ObserverType>(
        _ c: C,
        _ observer: Observer
    )
        async -> SynchronizedDisposable where Observer.Element == Element {
        let sink = AnonymousObservableSink(observer: observer)
        await sink.run(self, c.call())
        return sink
    }
}

func scope<R>(_ work: () async -> R) async -> R {
    await work()
}
