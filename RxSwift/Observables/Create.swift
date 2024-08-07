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
    static func create(_ subscribe: @Sendable @escaping (C, AnyAsyncObserver<Element>) async -> AsynchronousDisposable)
        -> Observable<Element> {
        AnonymousObservable(subscribe)
    }
}

private final actor AnonymousObservableSink<
    Observer: AsyncObserverType
>: AsyncObserverType, AsynchronousDisposable {
    typealias Element = Observer.Element
    typealias SubscribeHandler = AnonymousObservable<Element>.SubscribeHandler

    // state
    private let isStopped: NonAtomicInt
    private var innerDisposable: AsynchronousDisposable?
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
            let innerDisposable = innerDisposable
            self.innerDisposable = nil
            await innerDisposable?.dispose()
        }
    }

    func run(_ subscribeHandler: SubscribeHandler, _ c: C) async {
        innerDisposable = await subscribeHandler(c.call(), AnyAsyncObserver(self))
    }
}

private final class AnonymousObservable<Element: Sendable>: Observable<Element> {
    typealias SubscribeHandler = @Sendable (C, AnyAsyncObserver<Element>) async -> AsynchronousDisposable

    let subscribeHandler: SubscribeHandler

    init(_ subscribeHandler: @escaping SubscribeHandler) {
        self.subscribeHandler = subscribeHandler
        ObservableInit()
    }

    override func subscribe<Observer>(_ c: C, _ observer: Observer) async -> any Disposable
        where Element == Observer.Element, Observer: ObserverType {
        let sink = AnonymousObservableSink(observer: observer)
        await sink.run(subscribeHandler, c.call())
        return sink
    }
}

func scope<R>(_ work: () async -> R) async -> R {
    await work()
}
