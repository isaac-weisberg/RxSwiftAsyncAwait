//
//  ObservableType.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 8/8/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/// Represents a push style sequence.
public protocol ObservableType: ObservableConvertibleType {
    /**
     Subscribes `observer` to receive events for this sequence.

     ### Grammar

     **Next\* (Error | Completed)?**

     * sequences can produce zero or more elements so zero or more `Next` events can be sent to `observer`
     * once an `Error` or `Completed` event is sent, the sequence terminates and can't produce any other elements

     It is possible that events are sent from different threads, but no two events can be sent concurrently to
     `observer`.

     ### Resource Management

     When sequence sends `Complete` or `Error` event all internal resources that compute sequence elements
     will be freed.

     To cancel production of sequence elements and free resources immediately, call `dispose` on returned
     subscription.

     - returns: Subscription for `observer` that can be used to cancel production of sequence elements and free resources.
     */
    func subscribe<Observer: SynchronizedObserverType>(_ c: C, _ observer: Observer) async -> SynchronizedDisposable
        where Observer.Element == Element
}

public extension ObservableType {

    /// Default implementation of converting `ObservableType` to `Observable`.
    func asObservable() async -> Observable<Element> {
        // temporary workaround
        // return Observable.create(subscribe: self.subscribe)
        await Observable<Element>.create { c, o in await self.subscribe(c.call(), o) }
    }
}
/// Represents a push style sequence.
public protocol UnsynchronizedObservableType: UnsynchronizedObservableConvertibleType {
    /**
     Subscribes `observer` to receive events for this sequence.

     ### Grammar

     **Next\* (Error | Completed)?**

     * sequences can produce zero or more elements so zero or more `Next` events can be sent to `observer`
     * once an `Error` or `Completed` event is sent, the sequence terminates and can't produce any other elements

     It is possible that events are sent from different threads, but no two events can be sent concurrently to
     `observer`.

     ### Resource Management

     When sequence sends `Complete` or `Error` event all internal resources that compute sequence elements
     will be freed.

     To cancel production of sequence elements and free resources immediately, call `dispose` on returned
     subscription.

     - returns: Subscription for `observer` that can be used to cancel production of sequence elements and free resources.
     */
    func subscribe<Observer: UnsynchronizedObserverType>(_ c: C, _ observer: Observer) -> UnsynchronizedDisposable
        where Observer.Element == Element
}

public extension UnsynchronizedObservableType {

    /// Default implementation of converting `ObservableType` to `Observable`.
    func asObservable() -> UnsynchronizedObservable<Element> {
        // temporary workaround
        // return Observable.create(subscribe: self.subscribe)
        Observable<Element>.createUnsynchronized { c, o in self.subscribe(c.call(), o) }
    }
}
