//
//  Sink.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/19/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

protocol Sink: SynchronizedDisposable, AnyObject {
    associatedtype TheBaseSink: BaseSinkProtocol
    typealias Observer = TheBaseSink.Observer

    var baseSink: TheBaseSink { get }

    func forwardOn(_ event: Event<Observer.Element>, _ c: C) async
}

protocol BaseSinkProtocol {
    associatedtype Observer: ObserverType

    func beforeForwardOn()

    func afterForwardOn()

    func forwardOn(_ event: Event<Observer.Element>, _ c: C) async

    func isDisposed() -> Bool

    func setDisposedSync()

    func dispose() async

    var cancel: SynchronizedCancelable { get }
    var observer: Observer { get }
}

extension Sink {
    func forwarder() -> SinkForward<Self> {
        SinkForward(forward: self)
    }

//    func forwardOn(_ event: Event<Observer.Element>, _ c: C) async {
//        baseSink.beforeForwardOn()
//        if !baseSink.isDisposed() {
//            await baseSink.forwardOn(event, c.call())
//        }
//        baseSink.afterForwardOn()
//    }
//
//    func dispose() async {
//        baseSink.setDisposedSync()
//        await baseSink.dispose()
//    }
}

final class BaseSink<Observer: ObserverType>: BaseSinkProtocol {
    let observer: Observer
    let cancel: SynchronizedCancelable
    private let disposed: NonAtomicInt

    #if DEBUG
        private let synchronizationTracker: SynchronizationTrackerSync
    #endif

    init(observer: Observer, cancel: SynchronizedCancelable) async {
        disposed = NonAtomicInt(0)
        #if TRACE_RESOURCES
            _ = await Resources.incrementTotal()
        #endif
        #if DEBUG
            synchronizationTracker = SynchronizationTrackerSync()
        #endif
        self.observer = observer
        self.cancel = cancel
    }

    func beforeForwardOn() {
        #if DEBUG
            synchronizationTracker.register(synchronizationErrorMessage: .default)
        #endif
    }

    func afterForwardOn() {
        #if DEBUG
            synchronizationTracker.unregister()
        #endif
    }

    func forwardOn(_ event: Event<Observer.Element>, _ c: C) async {
        await observer.on(event, c.call())
    }

    func isDisposed() -> Bool {
        isFlagSet(disposed, 1)
    }

    func setDisposedSync() {
        fetchOr(disposed, 1)
    }

    func dispose() async {
        await cancel.dispose()
    }

    deinit {
        #if TRACE_RESOURCES
            Task {
                _ = await Resources.decrementTotal()
            }
        #endif
    }
}

// class BaseSinkLegacy<Observer: ObserverType>: Disposable {
//    fileprivate let observer: Observer
//    fileprivate let cancel: Cancelable
//    private let disposed: AtomicInt
//
//    #if DEBUG
//        private let synchronizationTracker: SynchronizationTracker
//    #endif
//
//    init(observer: Observer, cancel: SynchronizedCancelable) async {
//        disposed = await AtomicInt(0)
//        #if TRACE_RESOURCES
//            _ = await Resources.incrementTotal()
//        #endif
//        #if DEBUG
//            synchronizationTracker = await SynchronizationTracker()
//        #endif
//        self.observer = observer
//        self.cancel = cancel
//    }
//
//    final func forwardOn(_ event: Event<Observer.Element>, _ c: C) async {
//        #if DEBUG
//            await synchronizationTracker.register(synchronizationErrorMessage: .default)
//        #endif
//        await scope {
//            if await isFlagSet(self.disposed, 1) {
//                return
//            }
//            await self.observer.on(event, c.call())
//        }
//        #if DEBUG
//            await synchronizationTracker.unregister()
//        #endif
//    }
//
//    final func forwarder() -> SinkForward<Observer> {
//        SinkForward(forward: self)
//    }
//
//    final func isDisposed() async -> Bool {
//        await isFlagSet(disposed, 1)
//    }
//
//    func dispose() async {
//        await fetchOr(disposed, 1)
//        await cancel.dispose()
//    }
//
//    deinit {
//        #if TRACE_RESOURCES
//            Task {
//                _ = await Resources.decrementTotal()
//            }
//        #endif
//    }
// }

final class SinkForward<TheSink: Sink>: ObserverType {
    typealias Element = TheSink.Observer.Element

    private let forward: TheSink

    init(forward: TheSink) {
        self.forward = forward
    }

    final func on(_ event: Event<Element>, _ c: C) async {
        switch event {
        case .next:
            await forward.baseSink.observer.on(event, c.call())
        case .error, .completed:
            await forward.baseSink.observer.on(event, c.call())
            await forward.baseSink.cancel.dispose()
        }
    }
}
