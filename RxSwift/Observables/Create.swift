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
    static func create(_ subscribe: @escaping (AnyObserver<Element>) async -> Disposable) -> Observable<Element> {
        AnonymousObservable(subscribe)
    }
}

private final actor AnonymousObservableSink<Observer: ObserverType>: Sink, ObserverType {
    typealias Element = Observer.Element
    typealias Parent = AnonymousObservable<Element>

    private let superclass: SinkSuperclass<Observer>

    // state
    private var isStopped = false

    #if DEBUG
        private let synchronizationTracker = SynchronizationTracker()
    #endif

    init(observer: Observer, cancel: Cancelable) {
        superclass = SinkSuperclass(observer: observer, cancel: cancel)
    }

    func on(_ event: Event<Element>) async {
        #if DEBUG
            synchronizationTracker.register(synchronizationErrorMessage: .default)
            defer { self.synchronizationTracker.unregister() }
        #endif
        switch event {
        case .next:
            if isStopped {
                return
            }
            await forwardOn(event)
        case .error, .completed:
            let oldIsStopped = isStopped
            isStopped = true
            if !oldIsStopped {
                await forwardOn(event)
                await dispose()
            }
        }
    }

    func run(_ parent: Parent) async -> Disposable {
        await parent.subscribeHandler(AnyObserver(self))
    }

    func forwardOn(_ event: Event<Observer.Element>) async {
        await superclass.forwardOn(event)
    }

    nonisolated func forwarder() -> SinkForward<AnonymousObservableSink> {
        SinkForward(forward: self)
    }

    func isDisposed() async -> Bool {
        await superclass.isDisposed()
    }

    func dispose() async {
        await superclass.dispose()
    }

    func observer() async -> Observer {
        await superclass.observer()
    }

    func cancel() async -> any Cancelable {
        await superclass.cancel()
    }
}

private final class AnonymousObservable<Element>: Producer<Element> {
    typealias SubscribeHandler = (AnyObserver<Element>) async -> Disposable

    let subscribeHandler: SubscribeHandler

    init(_ subscribeHandler: @escaping SubscribeHandler) {
        self.subscribeHandler = subscribeHandler
    }

    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) async -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        let sink = AnonymousObservableSink(observer: observer, cancel: cancel)
        let subscription = await sink.run(self)
        return (sink: sink, subscription: subscription)
    }
}
