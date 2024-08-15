//
//  Do.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/21/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

public extension ObservableType {
    /**
     Invokes an action for each event in the observable sequence, and propagates all observer messages through the result sequence.

     - seealso: [do operator on reactivex.io](http://reactivex.io/documentation/operators/do.html)

     - parameter onNext: Action to invoke for each element in the observable sequence.
     - parameter afterNext: Action to invoke for each element after the observable has passed an onNext event along to its downstream.
     - parameter onError: Action to invoke upon errored termination of the observable sequence.
     - parameter afterError: Action to invoke after errored termination of the observable sequence.
     - parameter onCompleted: Action to invoke upon graceful termination of the observable sequence.
     - parameter afterCompleted: Action to invoke after graceful termination of the observable sequence.
     - parameter onSubscribe: Action to invoke before subscribing to source observable sequence.
     - parameter onSubscribed: Action to invoke after subscribing to source observable sequence.
     - parameter onDispose: Action to invoke after subscription to source observable has been disposed for any reason. It can be either because sequence terminates for some reason or observer subscription being disposed.
     - returns: The source sequence with the side-effecting behavior applied.
     */
    func `do`(
        onNext: (@Sendable (Element) async throws -> Void)? = nil,
        afterNext: (@Sendable (Element) async throws -> Void)? = nil,
        onError: (@Sendable (Swift.Error) async throws -> Void)? = nil,
        afterError: (@Sendable (Swift.Error) async throws -> Void)? = nil,
        onCompleted: (@Sendable () async throws -> Void)? = nil,
        afterCompleted: (@Sendable () async throws -> Void)? = nil,
        onSubscribe: (@Sendable () async -> Void)? = nil,
        onSubscribed: (@Sendable () async -> Void)? = nil,
        onDispose: (@Sendable () async -> Void)? = nil
    )
        -> Observable<Element> {
        Do(source: asObservable(), eventHandler: { e in
            switch e {
            case .next(let element):
                try await onNext?(element)
            case .error(let e):
                try await onError?(e)
            case .completed:
                try await onCompleted?()
            }
        }, afterEventHandler: { e in
            switch e {
            case .next(let element):
                try await afterNext?(element)
            case .error(let e):
                try await afterError?(e)
            case .completed:
                try await afterCompleted?()
            }
        }, onSubscribe: onSubscribe, onSubscribed: onSubscribed, onDispose: onDispose)
    }
}

private final actor DoSink<Observer: ObserverType>: SinkOverSingleSubscription, ObserverType {
    typealias Element = Observer.Element
    typealias EventHandler = @Sendable (Event<Element>) async throws -> Void
    typealias AfterEventHandler = @Sendable (Event<Element>) async throws -> Void
    typealias OnDisposeHandler = @Sendable () async -> Void

    private let eventHandler: EventHandler
    private let afterEventHandler: AfterEventHandler
    private let onDisposeHandler: OnDisposeHandler?
    let baseSink: BaseSinkOverSingleSubscription<Observer>

    init(
        eventHandler: @escaping EventHandler,
        afterEventHandler: @escaping AfterEventHandler,
        onDisposeHandler: OnDisposeHandler?,
        observer: Observer
    ) {
        self.eventHandler = eventHandler
        self.afterEventHandler = afterEventHandler
        self.onDisposeHandler = onDisposeHandler
        baseSink = BaseSinkOverSingleSubscription(observer: observer)
    }

    func on(_ event: Event<Element>, _ c: C) async {
        do {
            try await eventHandler(event)
            await forwardOn(event, c.call())
            try await afterEventHandler(event)
            if event.isStopEvent {
                await dispose()
            }
        } catch {
            await forwardOn(.error(error), c.call())
            await dispose()
        }
    }

    func dispose() async {
        await baseSink.setDisposed()?.dispose()
        await onDisposeHandler?()
    }
}

private final class Do<Element: Sendable>: Producer<Element> {
    typealias EventHandler = @Sendable (Event<Element>) async throws -> Void
    typealias AfterEventHandler = @Sendable (Event<Element>) async throws -> Void

    private let source: Observable<Element>
    private let eventHandler: EventHandler
    private let afterEventHandler: AfterEventHandler
    private let onSubscribe: (@Sendable () async -> Void)?
    private let onSubscribed: (@Sendable () async -> Void)?
    private let onDispose: (@Sendable () async -> Void)?

    init(
        source: Observable<Element>,
        eventHandler: @escaping EventHandler,
        afterEventHandler: @escaping AfterEventHandler,
        onSubscribe: (@Sendable () async -> Void)?,
        onSubscribed: (@Sendable () async -> Void)?,
        onDispose: (@Sendable () async -> Void)?
    ) {
        self.source = source
        self.eventHandler = eventHandler
        self.afterEventHandler = afterEventHandler
        self.onSubscribe = onSubscribe
        self.onSubscribed = onSubscribed
        self.onDispose = onDispose
        super.init()
    }

    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> AsynchronousDisposable
        where Observer.Element == Element {

        await onSubscribe?()
        let sink = DoSink(
            eventHandler: eventHandler,
            afterEventHandler: afterEventHandler,
            onDisposeHandler: onDispose,
            observer: observer
        )
        await sink.run(c.call(), source)
        await onSubscribed?()
        return sink
    }
}
