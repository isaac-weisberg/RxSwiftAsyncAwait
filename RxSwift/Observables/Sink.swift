//
//  Sink.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/19/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

protocol Sink: AsynchronousDisposable, AnyObject, Actor {
    associatedtype Observer: ObserverType

    var baseSink: BaseSink<Observer> { get }
}

extension Sink {
    func forwardOn(_ event: Event<Observer.Element>, _ c: C) async {
        if baseSink.disposed {
            return
        }

        await baseSink.observer.on(event, c)
    }
}

protocol SinkOverSingleSubscription: AsynchronousDisposable, AnyObject, Actor, ObserverType {
    associatedtype Observer: ObserverType

    var baseSink: BaseSinkOverSingleSubscription<Observer> { get }
}

extension SinkOverSingleSubscription {
    func forwardOn(_ event: Event<Observer.Element>, _ c: C) async {
        if baseSink.disposed {
            return
        }

        await baseSink.observer.on(event, c)
    }

    func run(_ c: C, _ source: Observable<Element>) async {
        let disposable = await source.subscribe(c.call(), self)
        await baseSink.sourceDisposable.setDisposable(disposable)?.dispose()
    }
}

final class BaseSink<Observer: ObserverType>: @unchecked Sendable {
    let observer: Observer

    init(observer: Observer) {
        #if TRACE_RESOURCES
            Task {
                _ = await Resources.incrementTotal()
            }
        #endif
        self.observer = observer
    }

    deinit {
        #if TRACE_RESOURCES
            Task {
                _ = await Resources.decrementTotal()
            }
        #endif
    }

    var disposed = false

    var timesDisposed = 0
    func setDisposed() {
        timesDisposed += 1
        if timesDisposed > 2 {
            rxAssert(false) // The RxSwift behavior for Sinks for now is to allow only two calls to dispose
        }
        disposed = true
    }
}

final class BaseSinkOverSingleSubscription<Observer: ObserverType>: @unchecked Sendable {
    let observer: Observer

    init(observer: Observer) {
        #if TRACE_RESOURCES
            Task {
                _ = await Resources.incrementTotal()
            }
        #endif
        self.observer = observer
    }

    deinit {
        #if TRACE_RESOURCES
            Task {
                _ = await Resources.decrementTotal()
            }
        #endif
    }

    var disposed = false
    let sourceDisposable = SingleAssignmentDisposable()

    var timesDisposed = 0
    func setDisposed() -> Disposable? {
        timesDisposed += 1
        if timesDisposed > 2 {
            rxAssert(false) // The RxSwift behavior for Sinks for now is to allow only two calls to dispose
        }
        disposed = true
        return sourceDisposable.dispose()
    }
}
