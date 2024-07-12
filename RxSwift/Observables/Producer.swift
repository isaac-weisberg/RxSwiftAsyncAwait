//
//  Producer.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/20/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

protocol

class ProducerLegacyyy<Element>: Observable<Element> {
    override init() {
        super.init()
    }

    override func subscribe<Observer: ObserverType>(_ observer: Observer) async -> Disposable where Observer.Element == Element {
        if !CurrentThreadScheduler.isScheduleRequired {
            // The returned disposable needs to release all references once it was disposed.
            let disposer = SinkDisposer()
            let sinkAndSubscription = self.run(observer, cancel: disposer)
            await disposer.setSinkAndSubscription(sink: sinkAndSubscription.sink, subscription: sinkAndSubscription.subscription)

            return disposer
        }
        else {
            return CurrentThreadScheduler.instance.schedule(()) { _ in
                let disposer = SinkDisposer()
                let sinkAndSubscription = self.run(observer, cancel: disposer)
                await disposer.setSinkAndSubscription(sink: sinkAndSubscription.sink, subscription: sinkAndSubscription.subscription)

                return disposer
            }
        }
    }

    func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        rxAbstractMethod()
    }
}

private final actor SinkDisposer: Cancelable {
    private enum DisposeState {
        case idle
        case disposed
        case sinkAndSubscriptionSet
    }

    private var state = DisposeState.idle
    private var sink: Disposable?
    private var subscription: Disposable?

    func isDisposed() async -> Bool {
        self.state == .disposed
    }

    func setSinkAndSubscription(sink: Disposable, subscription: Disposable) async {
        self.sink = sink
        self.subscription = subscription

        let previousState = self.state
        self.state = .sinkAndSubscriptionSet
        if previousState == .sinkAndSubscriptionSet {
            rxFatalError("Sink and subscription were already set")
        }

        if previousState == .disposed {
            await sink.dispose()
            await subscription.dispose()
            self.sink = nil
            self.subscription = nil
        }
    }

    func dispose() async {
        let previousState = self.state
        self.state = .disposed
        if previousState == .disposed {
            return
        }

        if previousState == .sinkAndSubscriptionSet {
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
