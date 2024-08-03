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

public func actorLocked<P, R>(_ lock: ActorLock, _ work: @escaping (P) -> R) -> (P) async -> R {
    { p in
        let r: R
        r = await lock.perform {
            work(p)
        }
        return r
    }
}

public final actor ActorLock {
    public func performLocked<R>(_ work: () -> R) -> R {
        work()
    }
    internal init() {
        
    }

    public static func with<R>(_ work: (ActorLock) -> R) async -> R {
        let lock = ActorLock()
        
        return await lock.perform {
            work(lock)
        }
    }
}

public protocol AsyncObserver {
    associatedtype Observer: ObserverType
    typealias Element = Observer.Element

    func on(_ event: Event<Element>) async
}

public struct AsyncLockedObserver<Observer: ObserverType>: AsyncObserver {
    public typealias Element = Observer.Element

    public let lock: ActorLock
    public let observer: Observer

    public init(lock: ActorLock, observer: Observer) {
        self.lock = lock
        self.observer = observer
    }

    public func on(_ event: Event<Element>) async {
        await lock.perform {
            observer.on(event)
        }
    }
}

extension ObserverType {
    func asyncLocked(_ actorLock: ActorLock) -> AsyncLockedObserver<Self> {
        AsyncLockedObserver(lock: actorLock, observer: self)
    }
}

public extension AsyncObserver {

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

protocol ObserverThatCapturesLock {
    associatedtype Element
    
    func on(_ lock: ActorLock, _ event: Event<Element>)
}


struct CaptureObserverWithLock<Observer: ObserverThatCapturesLock>: ObserverType {
    let lock: ActorLock
    let observer: Observer
    
    init(lock: ActorLock, observer: Observer) {
        self.observer = observer
        self.lock = lock
    }
    
    func on(_ event: Event<Observer.Element>) {
        self.observer.on(lock, event)
    }
}

extension ObserverThatCapturesLock {
    func capturing(_ lock: ActorLock) -> CaptureObserverWithLock<Self> {
        CaptureObserverWithLock(lock: lock, observer: self)
    }
}
