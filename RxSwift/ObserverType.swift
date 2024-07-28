//
//  ObserverType.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/8/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/// Supports push-style iteration over an observable sequence.
public protocol ObserverType {
    /// The type of elements in sequence that observer can observe.
    associatedtype Element

    /// Notify observer about sequence event.
    ///
    /// - parameter event: Event that occurred.
    func on(_ event: Event<Element>)
}

/// Convenience API extensions to provide alternate next, error, completed events
public extension ObserverType {

    /// Convenience method equivalent to `on(.next(element: Element))`
    ///
    /// - parameter element: Next element to send to observer(s)
    func onNext(_ element: Element) {
        on(.next(element))
    }

    /// Convenience method equivalent to `on(.completed)`
    func onCompleted() {
        on(.completed)
    }

    /// Convenience method equivalent to `on(.error(Swift.Error))`
    /// - parameter error: Swift.Error to send to observer(s)
    func onError(_ error: Swift.Error) {
        on(.error(error))
    }
}

public final actor ActorLock {
    public func perform(_ work: () -> Void) {
        work()
    }

    public init() {}
}

public protocol SynchronizedObserver {
    associatedtype Observer: ObserverType
    typealias Element = Observer.Element

    var unsynchronizedObserver: Observer { get }

    func on(_ event: Event<Element>) async
}

public struct SynchronizedObserverImpl<Observer: ObserverType>: SynchronizedObserver {
    public typealias Element = Observer.Element

    public let lock: ActorLock
    public let observer: Observer

    public var unsynchronizedObserver: Observer {
        observer
    }

    public init(lock: ActorLock, observer: Observer) {
        self.lock = lock
        self.observer = observer
    }

    public init(observer: Observer) {
        lock = ActorLock()
        self.observer = observer
    }

    public func on(_ event: Event<Element>) async {
        observer.on(event)
    }
}

public extension SynchronizedObserver {

    /// Convenience method equivalent to `on(.next(element: Element))`
    ///
    /// - parameter element: Next element to send to observer(s)
    func onNext(_ element: Element) async {
        await on(.next(element))
    }

    /// Convenience method equivalent to `on(.completed)`
    func onCompleted() async {
        await on(.completed)
    }

    /// Convenience method equivalent to `on(.error(Swift.Error))`
    /// - parameter error: Swift.Error to send to observer(s)
    func onError(_ error: Swift.Error) async {
        await on(.error(error))
    }

}
