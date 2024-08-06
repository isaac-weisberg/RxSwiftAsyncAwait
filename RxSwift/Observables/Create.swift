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

    /**
     Creates an observable sequence from a specified subscribe method implementation.

     - seealso: [create operator on reactivex.io](http://reactivex.io/documentation/operators/create.html)

     - parameter subscribe: Implementation of the resulting observable sequence's `subscribe` method.
     - returns: The observable sequence with the specified implementation for the `subscribe` method.
     */
    static func createUnsynchronized(
        _ subscribe: @escaping (C, AnyUnsynchronizedObserver<Element>)
            -> UnsynchronizedDisposable
    )
        -> UnsynchronizedObservable<Element> {
        AnonymousUnsynchronizedObservable(subscribe)
    }
}

final actor ActorSink<UnderlyingSink: UnsynchronizedDisposable & UnsynchronizedObserverType>: SynchronizedObserverType,
    SynchronizedDisposable,
    Actor {
    func on(_ event: Event<UnderlyingSink.Element>, _ stack: C) async {
        sink.on(event, stack.call())
    }

    typealias Element = UnderlyingSink.Element

    var sink: UnderlyingSink!
    func setSink(_ sink: UnderlyingSink) {
        self.sink = sink
    }

    func perform<R>(_ c: C, _ work: (C) -> R) -> R {
        work(c.call())
    }

    init() {}

    func dispose() async {
        sink.dispose()
    }
}

//
// private final actor AnonymousObservableSink<Observer: SynchronizedObserverType>: Sink, SynchronizedObserverType {
//    typealias Element = Observer.Element
//    typealias Parent = AnonymousObservable<Element>
//
//    let baseSink: BaseSink<Observer>
//
//    // state
//    private let isStopped: NonAtomicInt
//    private var innerDisposable: SynchronizedDisposable?
//
//    init(observer: Observer) {
//        isStopped = NonAtomicInt(0)
//        baseSink = BaseSink(observer: observer)
//    }
//
//    func on(_ event: Event<Element>, _ c: C) async {
//        switch event {
//        case .next:
//            if load(isStopped) == 1 {
//                return
//            }
//            await forwardOn(event, c.call())
//        case .error, .completed:
//            if fetchOr(isStopped, 1) == 0 {
//                await forwardOn(event, c.call())
//                await dispose()
//            }
//        }
//    }
//
//    func dispose() async {
//        if fetchOr(isStopped, 1) == 0 {
//            await innerDisposable?.dispose()
//            innerDisposable = nil
//        }
//
//    }
//
//    func forwardOn(_ event: Event<Observer.Element>, _ c: C) async {
//        await baseSink.observer.on(event, c.call())
//    }
//
//    func run(_ parent: Parent, _ c: C) async {
//        innerDisposable = await parent.subscribeHandler(c.call(), AnyObserver(self))
//    }
// }

private final class AnonymousObservable<Element>: Producer<Element> {
    typealias SubscribeHandler = (C, AnyObserver<Element>) async -> SynchronizedDisposable

    let subscribeHandler: SubscribeHandler

    init(_ subscribeHandler: @escaping SubscribeHandler) async {
        self.subscribeHandler = subscribeHandler
        await super.init()
    }

    override func run<Observer: SynchronizedObserverType>(
        _ c: C,
        _ observer: Observer
    )
        async -> SynchronizedDisposable where Observer.Element == Element {

        typealias UnderlyingSink = AnonymousUnsynchronizedObservableSink<AnyUnsynchronizedObserver<Element>>
        let actorSink = ActorSink<UnderlyingSink>()
        let unsyncObserver = AnyUnsynchronizedObserver { c, event in
            Task {
                await observer.on(event, c.call())
            }
        }
        let synchronizedSubscribeHandler = subscribeHandler

        let theSubscribeHandler: (C, AnyUnsynchronizedObserver<Element>) -> UnsynchronizedDisposable = { c, _ in
            Task {
                await synchronizedSubscribeHandler(c.call(), AnyObserver(eventHandler: { c, event in
                    await actorSink.on(event, c.call())
                }))
            }

            return Disposables.create {
                Task {
                    await actorSink.dispose()
                }
            }
        }
        let sink = AnonymousUnsynchronizedObservableSink(observer: unsyncObserver)
        await actorSink.setSink(sink)
        await actorSink.perform(c.call()) { [theSubscribeHandler] c in
            sink.run(theSubscribeHandler, c.call())
        }
        return actorSink
    }
}

func scope<R>(_ work: () async -> R) async -> R {
    await work()
}

private final class AnonymousUnsynchronizedObservableSink<
    Observer: UnsynchronizedObserverType
>: UnsynchronizedObserverType, UnsynchronizedDisposable {
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
        innerDisposable = subscribeHandler(c.call(), AnyUnsynchronizedObserver(self))
    }
}

private final class AnonymousUnsynchronizedObservable<Element>: UnsynchronizedObservable<Element> {
    typealias SubscribeHandler = (C, AnyUnsynchronizedObserver<Element>) -> UnsynchronizedDisposable

    let subscribeHandler: SubscribeHandler

    init(_ subscribeHandler: @escaping SubscribeHandler) {
        self.subscribeHandler = subscribeHandler
        super.init()
    }

    override func subscribe<Observer>(_ c: C, _ observer: Observer) -> any UnsynchronizedDisposable
        where Observer: UnsynchronizedObserverType, Observer.Element == Element {
        let sink = AnonymousUnsynchronizedObservableSink(observer: observer)
        sink.run(subscribeHandler, c.call())
        return sink
    }
}
