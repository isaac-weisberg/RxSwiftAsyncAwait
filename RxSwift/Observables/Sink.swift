//
//  Sink.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/19/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

protocol Sink: AsynchronousDisposable, AnyObject, Actor {
    associatedtype TheBaseSink: BaseSinkProtocol
    typealias Observer = TheBaseSink.Observer

    var baseSink: TheBaseSink { get }

    func forwardOn(_ event: Event<Observer.Element>, _ c: C) async
}

protocol BaseSinkProtocol: AnyObject, Sendable {
    associatedtype Observer: ObserverType

    var observer: Observer { get }

    var disposed: Bool { get }
    
    func setDisposed() -> Bool
}

extension Sink {
    func forwardOn(_ event: Event<Observer.Element>, _ c: C) async {
        if !baseSink.disposed {
            await baseSink.observer.on(event, c.call())
        }
    }
    
    func setDisposed() -> Bool {
        baseSink.setDisposed()
    }
}

final class BaseSink<Observer: ObserverType>: BaseSinkProtocol, @unchecked Sendable {
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
    
    var disposed: Bool = false
    
    func setDisposed() -> Bool {
        if !disposed {
            disposed = true
            return true
        }
        return false
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
//    init(observer: Observer) async {
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
