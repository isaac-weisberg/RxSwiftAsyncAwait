//
//  Producer.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/20/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

class Producer<Element>: Observable<Element> {
    override init() async {
        await super.init()
    }

    override func subscribe<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> SynchronizedDisposable
        where Observer.Element == Element {

        // The returned disposable needs to release all references once it was disposed.
        let disposer = SinkDisposer()
        let sinkAndSubscription = await run(c.call(), observer, cancel: disposer)
        await disposer.setSinkAndSubscription(
            sink: sinkAndSubscription.sink,
            subscription: sinkAndSubscription.subscription
        )

        return disposer
    }

    func run<Observer: ObserverType>(
        _ c: C,
        _ observer: Observer,
        cancel: SynchronizedCancelable
    )
        async -> (sink: SynchronizedDisposable, subscription: SynchronizedDisposable)
        where Observer.Element == Element {
        rxAbstractMethod()
    }
}

private final actor SinkDisposer: SynchronizedCancelable {
    private enum DisposeState: Int32 {
        case disposed = 1
        case sinkAndSubscriptionSet = 2
    }

    private let state: NonAtomicInt
    private var sink: SynchronizedDisposable?
    private var subscription: SynchronizedDisposable?

    init() {
        state = NonAtomicInt(0)
    }

    func isDisposed() -> Bool {
        isFlagSet(state, DisposeState.disposed.rawValue)
    }

    func setSinkAndSubscription(sink: SynchronizedDisposable, subscription: SynchronizedDisposable) async {
        self.sink = sink
        self.subscription = subscription

        let previousState = fetchOr(state, DisposeState.sinkAndSubscriptionSet.rawValue)
        if (previousState & DisposeState.sinkAndSubscriptionSet.rawValue) != 0 {
            rxFatalError("Sink and subscription were already set")
        }

        if (previousState & DisposeState.disposed.rawValue) != 0 {
            await sink.dispose()
            await subscription.dispose()
            self.sink = nil
            self.subscription = nil
        }
    }

    func dispose() async {
        let previousState = fetchOr(state, DisposeState.disposed.rawValue)

        if (previousState & DisposeState.disposed.rawValue) != 0 {
            return
        }

        if (previousState & DisposeState.sinkAndSubscriptionSet.rawValue) != 0 {
            guard let sink else {
                rxFatalError("Sink not set")
            }
            guard let subscription else {
                rxFatalError("Subscription not set")
            }

            await sink.dispose()
            await subscription.dispose()

            self.sink = nil
            self.subscription = nil
        }
    }
}
