//
//  AnyObserver.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/28/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/// A type-erased `ObserverType`.
///
/// Forwards operations to an arbitrary underlying observer with the same `Element` type, hiding the specifics of the
/// underlying observer type.
public struct AnyObserver<Element>: SynchronizedObserverType {
    /// Anonymous event handler type.
    public typealias EventHandler = (C, Event<Element>) async -> Void

    private let observer: EventHandler

    /// Construct an instance whose `on(event)` calls `eventHandler(event)`
    ///
    /// - parameter eventHandler: Event handler that observes sequences events.
    public init(eventHandler: @escaping EventHandler) {
        observer = eventHandler
    }

    /// Construct an instance whose `on(event)` calls `observer.on(event)`
    ///
    /// - parameter observer: Observer that receives sequence events.
    public init<Observer: SynchronizedObserverType>(_ observer: Observer) where Observer.Element == Element {
        self.observer = { c, e in
            await observer.on(e, c)
        }
    }

    /// Send `event` to this observer.
    ///
    /// - parameter event: Event instance.
    public func on(_ event: Event<Element>, _ c: C) async {
        await observer(c.call(), event)
    }

    /// Erases type of observer and returns canonical observer.
    ///
    /// - returns: type erased observer.
    public func asObserver() -> AnyObserver<Element> {
        self
    }
}

extension AnyObserver {
    /// Collection of `AnyObserver`s
    typealias s = Bag<(Event<Element>, C) async -> Void>
}

public extension SynchronizedObserverType {
    /// Erases type of observer and returns canonical observer.
    ///
    /// - returns: type erased observer.
    func asObserver() -> AnyObserver<Element> {
        AnyObserver(self)
    }

    /// Transforms observer of type R to type E using custom transform method.
    /// Each event sent to result observer is transformed and sent to `self`.
    ///
    /// - returns: observer that transforms events.
    func mapObserver<Result>(_ transform: @escaping (Result) throws -> Element) -> AnyObserver<Result> {
        AnyObserver { c, e in
            await self.on(e.map(transform), c.call())
        }
    }
}

public struct AnyUnsynchronizedObserver<Element>: UnsynchronizedObserverType {
    /// Anonymous event handler type.
    public typealias EventHandler = (C, Event<Element>) -> Void

    private let observer: EventHandler

    /// Construct an instance whose `on(event)` calls `eventHandler(event)`
    ///
    /// - parameter eventHandler: Event handler that observes sequences events.
    public init(eventHandler: @escaping EventHandler) {
        observer = eventHandler
    }

    /// Construct an instance whose `on(event)` calls `observer.on(event)`
    ///
    /// - parameter observer: Observer that receives sequence events.
    public init<Observer: UnsynchronizedObserverType>(_ observer: Observer) where Observer.Element == Element {
        self.observer = { c, e in
            observer.on(e, c)
        }
    }

    /// Send `event` to this observer.
    ///
    /// - parameter event: Event instance.
    public func on(_ event: Event<Element>, _ c: C) {
        observer(c.call(), event)
    }

    /// Erases type of observer and returns canonical observer.
    ///
    /// - returns: type erased observer.
    public func asObserver() -> AnyUnsynchronizedObserver<Element> {
        self
    }
}

extension AnyUnsynchronizedObserver {
    /// Collection of `AnyObserver`s
    typealias s = Bag<(Event<Element>, C) -> Void>
}

public extension UnsynchronizedObserverType {
    /// Erases type of observer and returns canonical observer.
    ///
    /// - returns: type erased observer.
    func asObserver() -> AnyUnsynchronizedObserver<Element> {
        AnyUnsynchronizedObserver(self)
    }

    /// Transforms observer of type R to type E using custom transform method.
    /// Each event sent to result observer is transformed and sent to `self`.
    ///
    /// - returns: observer that transforms events.
    func mapObserver<Result>(_ transform: @escaping (Result) throws -> Element) -> AnyUnsynchronizedObserver<Result> {
        AnyUnsynchronizedObserver { c, e in
            self.on(e.map(transform), c.call())
        }
    }
}
