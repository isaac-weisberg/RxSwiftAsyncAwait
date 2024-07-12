//
//  Sink.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/19/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

class Sink<Observer: ObserverType>: Disposable {
    fileprivate let observer: Observer
    fileprivate let cancel: Cancelable
    private let disposed: AtomicInt

    #if DEBUG
        private let synchronizationTracker: SynchronizationTracker
    #endif

    init(observer: Observer, cancel: Cancelable) async {
        disposed = await AtomicInt(0)
        #if TRACE_RESOURCES
            _ = await Resources.incrementTotal()
        #endif
        #if DEBUG
            self.synchronizationTracker = await SynchronizationTracker()
        #endif
        self.observer = observer
        self.cancel = cancel
    }

    final func forwardOn(_ event: Event<Observer.Element>) async {
        #if DEBUG
            await self.synchronizationTracker.register(synchronizationErrorMessage: .default)
        #endif
        await scope {
            if await isFlagSet(self.disposed, 1) {
                return
            }
            await self.observer.on(event)
        }
        #if DEBUG
            await self.synchronizationTracker.unregister()
        #endif
    }

    final func forwarder() -> SinkForward<Observer> {
        SinkForward(forward: self)
    }

    final func isDisposed() async -> Bool {
        await isFlagSet(self.disposed, 1)
    }

    func dispose() async {
        await fetchOr(self.disposed, 1)
        await self.cancel.dispose()
    }

    deinit {
        #if TRACE_RESOURCES
            Task {
                _ = await Resources.decrementTotal()
            }
        #endif
    }
}

final class SinkForward<Observer: ObserverType>: ObserverType {
    typealias Element = Observer.Element

    private let forward: Sink<Observer>

    init(forward: Sink<Observer>) {
        self.forward = forward
    }

    final func on(_ event: Event<Element>) async {
        switch event {
        case .next:
            await self.forward.observer.on(event)
        case .error, .completed:
            await self.forward.observer.on(event)
            await self.forward.cancel.dispose()
        }
    }
}
