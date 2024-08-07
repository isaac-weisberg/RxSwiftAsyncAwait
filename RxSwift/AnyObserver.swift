//
//  AnyObserver.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/28/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

public struct AnySyncObserver<Element: Sendable>: SyncObserverType, Sendable {
    /// Anonymous event handler type.
    public typealias EventHandler = SyncObserverEventHandler<Element>

    public let on: EventHandler

    /// Construct an instance whose `on(event)` calls `eventHandler(event)`
    ///
    /// - parameter eventHandler: Event handler that observes sequences events.
    public init(eventHandler: @escaping EventHandler) {
        on = eventHandler
    }
    
    public func on(_ event: Event<Element>, _ c: C) {
        self.on(event, c.call())
    }

    /// Construct an instance whose `on(event)` calls `observer.on(event)`
    ///
    /// - parameter observer: Observer that receives sequence events.
    public init<Observer: SyncObserverType>(_ observer: Observer) where Observer.Element == Element {
        self.on = observer.on(_:_:)
    }
}

//public struct AnyAsyncObserver<Element: Sendable>: AsyncObserverType {
//    /// Anonymous event handler type.
//    public typealias EventHandler = AsyncObserverEventHandler<Element>
//
//    public let on: EventHandler
//
//    /// Construct an instance whose `on(event)` calls `eventHandler(event)`
//    ///
//    /// - parameter eventHandler: Event handler that observes sequences events.
//    public init(eventHandler: @escaping EventHandler) {
//        on = eventHandler
//    }
//    
//    public func on(_ event: Event<Element>, _ c: C) async {
//        await self.on(event, c.call())
//    }
//
//    /// Construct an instance whose `on(event)` calls `observer.on(event)`
//    ///
//    /// - parameter observer: Observer that receives sequence events.
//    public init<Observer: SyncObserverType>(_ observer: Observer) where Observer.Element == Element {
//        self.on = observer.on(_:_:)
//    }
//}
//
///// A type-erased `ObserverType`.
/////
///// Forwards operations to an arbitrary underlying observer with the same `Element` type, hiding the specifics of the
///// underlying observer type.
//public struct AnyObserver<Element: Sendable>: ObserverType {
//    /// Anonymous event handler type.
//    public typealias EventHandler = ObserverEventHandler<Element>
//
//    public let on: EventHandler
//
//    /// Construct an instance whose `on(event)` calls `eventHandler(event)`
//    ///
//    /// - parameter eventHandler: Event handler that observes sequences events.
//    public init(eventHandler: EventHandler) {
//        on = eventHandler
//    }
//
//    /// Construct an instance whose `on(event)` calls `observer.on(event)`
//    ///
//    /// - parameter observer: Observer that receives sequence events.
//    public init<Observer: ObserverType>(_ observer: Observer) where Observer.Element == Element {
//        switch observer.on {
//        case .sync(let observer):
//            self.on = .sync { e, c in
//                observer(e, c.call())
//            }
//        case .async(let observer):
//            self.on = .async { e, c in
//                await observer(e, c.call())
//            }
//        }
//    }
//
//    /// Erases type of observer and returns canonical observer.
//    ///
//    /// - returns: type erased observer.
//    public func asObserver() -> AnyObserver<Element> {
//        self
//    }
//}
//
//extension AnyObserver {
//    /// Collection of `AnyObserver`s
//    typealias s = Bag<EventHandler>
//}
//
//public extension ObserverType {
//    /// Erases type of observer and returns canonical observer.
//    ///
//    /// - returns: type erased observer.
//    func asObserver() -> AnyObserver<Element> {
//        AnyObserver(self)
//    }
//
//    /// Transforms observer of type R to type E using custom transform method.
//    /// Each event sent to result observer is transformed and sent to `self`.
//    ///
//    /// - returns: observer that transforms events.
//    func mapObserver<Result>(_ transform: @Sendable @escaping (Result) throws -> Element) -> AnyObserver<Result> {
//        switch self.on {
//        case .sync(let observer):
//            return AnyObserver(eventHandler: .sync { e, c in
//                observer(e.map(transform), c.call())
//            })
//        case .async(let observer):
//            return AnyObserver(eventHandler: .async { e, c in
//                await observer(e.map(transform), c.call())
//            })
//        }
//    }
//}
