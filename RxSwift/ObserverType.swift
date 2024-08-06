//
//  ObserverType.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/8/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/// Supports push-style iteration over an observable sequence.
public protocol SynchronizedObserverType {
    /// The type of elements in sequence that observer can observe.
    associatedtype Element

    /// Notify observer about sequence event.
    ///
    /// - parameter event: Event that occurred.
    func on(_ event: Event<Element>, _ c: C) async
}

/// Convenience API extensions to provide alternate next, error, completed events
public extension SynchronizedObserverType {
    /// Convenience method equivalent to `on(.next(element: Element))`
    ///
    /// - parameter element: Next element to send to observer(s)
    func onNext(_ element: Element, _ c: C) async {
        await on(.next(element), c)
    }

    /// Convenience method equivalent to `on(.completed)`
    func onCompleted(_ c: C) async {
        await on(.completed, c)
    }

    /// Convenience method equivalent to `on(.error(Swift.Error))`
    /// - parameter error: Swift.Error to send to observer(s)
    func onError(_ error: Swift.Error, _ c: C) async {
        await on(.error(error), c)
    }
}

/// Supports push-style iteration over an observable sequence.
public protocol UnsynchronizedObserverType {
    /// The type of elements in sequence that observer can observe.
    associatedtype Element

    /// Notify observer about sequence event.
    ///
    /// - parameter event: Event that occurred.
    func on(_ event: Event<Element>, _ c: C)
}

/// Convenience API extensions to provide alternate next, error, completed events
public extension UnsynchronizedObserverType {
    /// Convenience method equivalent to `on(.next(element: Element))`
    ///
    /// - parameter element: Next element to send to observer(s)
    func onNext(_ element: Element, _ c: C) {
        on(.next(element), c)
    }

    /// Convenience method equivalent to `on(.completed)`
    func onCompleted(_ c: C) {
        on(.completed, c)
    }

    /// Convenience method equivalent to `on(.error(Swift.Error))`
    /// - parameter error: Swift.Error to send to observer(s)
    func onError(_ error: Swift.Error, _ c: C) {
        on(.error(error), c)
    }
}
