//
//  Sink.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/19/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

protocol Sink: Disposable {
    associatedtype Observer: ObserverType

    var superclass: SinkSuperclass<Observer> { get }

    // private
    func observer() async -> Observer
    func cancel() async -> Cancelable

    // final
    func forwardOn(_ event: Event<Observer.Element>) async
    // final
    func isDisposed() async -> Bool
    // not-final
    func dispose() async

    // no super
    func forwarder() -> SinkForward<Self>
}

final actor SinkSuperclass<Observer: ObserverType>: Disposable {
    private let _observer: Observer
    private let _cancel: Cancelable
    private var disposed = false

    struct Subclass {
        let dispose: () async -> Void
    }

    var subclass: Subclass!

    #if DEBUG
        private let synchronizationTracker = SynchronizationTracker()
    #endif

    init(observer: Observer, cancel: Cancelable) {
        #if TRACE_RESOURCES
            _ = Resources.incrementTotal()
        #endif
        _observer = observer
        _cancel = cancel
    }

    func observer() async -> Observer {
        _observer
    }

    func cancel() async -> any Cancelable {
        _cancel
    }

    // final
    func forwardOn(_ event: Event<Observer.Element>) async {
        #if DEBUG
            synchronizationTracker.register(synchronizationErrorMessage: .default)
            defer { self.synchronizationTracker.unregister() }
        #endif
        if disposed {
            return
        }
        await observer().on(event)
    }

    // final
    func isDisposed() async -> Bool {
        disposed
    }

    func dispose() async {
        await subclass?.dispose()
        disposed = true
        await cancel().dispose()
    }

    deinit {
        #if TRACE_RESOURCES
            _ = Resources.decrementTotal()
        #endif
    }
}

//
// actor SinkLegacyyy<Observer: ObserverType>: Sink, Disposable {
//    fileprivate let observer: Observer
//    fileprivate let cancel: Cancelable
//    private let disposed = AtomicInt(0)
//
//    #if DEBUG
//        private let synchronizationTracker = SynchronizationTracker()
//    #endif
//
//    init(observer: Observer, cancel: Cancelable) {
//        #if TRACE_RESOURCES
//            _ = Resources.incrementTotal()
//        #endif
//        self.observer = observer
//        self.cancel = cancel
//    }
//
//    final func forwardOn(_ event: Event<Observer.Element>) {
//        #if DEBUG
//            self.synchronizationTracker.register(synchronizationErrorMessage: .default)
//            defer { self.synchronizationTracker.unregister() }
//        #endif
//        if isFlagSet(self.disposed, 1) {
//            return
//        }
//        self.observer.on(event)
//    }
//
//    final func forwarder() -> SinkForward<Observer> {
//        SinkForward(forward: self)
//    }
//
//    final var isDisposed: Bool {
//        isFlagSet(self.disposed, 1)
//    }
//
//    func dispose() async {
//        fetchOr(self.disposed, 1)
//        await self.cancel.dispose()
//    }
//
//    deinit {
//        #if TRACE_RESOURCES
//            _ = Resources.decrementTotal()
//        #endif
//    }
// }

final actor SinkForward<SomeSink: Sink>: ObserverType {
    typealias Element = SomeSink.Observer.Element

    private let forward: SomeSink

    init(forward: SomeSink) {
        self.forward = forward
    }

    final func on(_ event: Event<Element>) async {
        switch event {
        case .next:
            await forward.observer().on(event)
        case .error, .completed:
            await forward.observer().on(event)
            await forward.cancel().dispose()
        }
    }
}
