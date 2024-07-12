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

    override func subscribe<Observer: ObserverType>(_ observer: Observer) async -> Disposable where Observer.Element == Element {
        if !CurrentThreadScheduler.isScheduleRequired {
            // The returned disposable needs to release all references once it was disposed.
            let disposer = await SinkDisposer()
            let sinkAndSubscription = await self.run(observer, cancel: disposer)
            await disposer.setSinkAndSubscription(sink: sinkAndSubscription.sink, subscription: sinkAndSubscription.subscription)

            return disposer
        }
        else {
            return await CurrentThreadScheduler.instance.schedule(()) { _ in
                let disposer = await SinkDisposer()
                let sinkAndSubscription = await self.run(observer, cancel: disposer)
                await disposer.setSinkAndSubscription(sink: sinkAndSubscription.sink, subscription: sinkAndSubscription.subscription)

                return disposer
            }
        }
    }

    func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) async -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        rxAbstractMethod()
    }
}

private final class SinkDisposer: Cancelable {
    private enum DisposeState: Int32 {
        case disposed = 1
        case sinkAndSubscriptionSet = 2
    }

    private let state: AtomicInt
    private var sink: Disposable?
    private var subscription: Disposable?

    init() async {
        self.state = await AtomicInt(0)
    }

    func isDisposed() async -> Bool {
        await isFlagSet(self.state, DisposeState.disposed.rawValue)
    }

    func setSinkAndSubscription(sink: Disposable, subscription: Disposable) async {
        self.sink = sink
        self.subscription = subscription

        let previousState = await fetchOr(self.state, DisposeState.sinkAndSubscriptionSet.rawValue)
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
        let previousState = await fetchOr(self.state, DisposeState.disposed.rawValue)

        if (previousState & DisposeState.disposed.rawValue) != 0 {
            return
        }

        if (previousState & DisposeState.sinkAndSubscriptionSet.rawValue) != 0 {
            guard let sink = self.sink else {
                rxFatalError("Sink not set")
            }
            guard let subscription = self.subscription else {
                rxFatalError("Subscription not set")
            }

            await sink.dispose()
            await subscription.dispose()

            self.sink = nil
            self.subscription = nil
        }
    }
}
