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
    func on(_ event: Event<Element>, _ stack: C) async
}

/// Convenience API extensions to provide alternate next, error, completed events
public extension ObserverType {
    /// Convenience method equivalent to `on(.next(element: Element))`
    ///
    /// - parameter element: Next element to send to observer(s)
    func onNext(_ element: Element, _ stack: C) async {
        await self.on(.next(element), stack)
    }

    /// Convenience method equivalent to `on(.completed)`
    func onCompleted(_ stack: C) async {
        await self.on(.completed, stack)
    }

    /// Convenience method equivalent to `on(.error(Swift.Error))`
    /// - parameter error: Swift.Error to send to observer(s)
    func onError(_ error: Swift.Error, _ stack: C) async {
        await self.on(.error(error), stack)
    }
}
