//
//  Observable.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/8/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/// A type-erased `ObservableType`.
///
/// It represents a push style sequence.

public typealias RxObservable<Element> = Observable<Element>

func ObservableInit() {
    #if TRACE_RESOURCES
        Task {
            _ = await Resources.incrementTotal()
        }
    #endif
}

func ObservableDeinit() {
    #if TRACE_RESOURCES
        Task {
            _ = await Resources.decrementTotal()
        }
    #endif
}

public class Observable<Element: Sendable>: ObservableType, @unchecked Sendable {
    init() {
        ObservableInit()
    }

    public func subscribe<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> AsynchronousDisposable
        where Observer.Element == Element {
        rxAbstractMethod()
    }

    public func asObservable() -> Observable<Element> { self }

    deinit {
        ObservableDeinit()
    }
}

public class AsyncObservableToAsyncObserver<Element: Sendable>: AsyncObservableToAsyncObserverType,
    @unchecked Sendable {
    init() {
        ObservableInit()
    }

    public func subscribe<Observer: AsyncObserverType>(_ c: C, _ observer: Observer) async -> AnyDisposable
        where Observer.Element == Element {
        rxAbstractMethod()
    }

    public func asObservable() -> AsyncObservableToAsyncObserver<Element> { self }

    deinit {
        ObservableDeinit()
    }
}

public class AsyncObservableToSyncObserver<Element: Sendable>: AsyncObservableToSyncObserverType, @unchecked Sendable {
    init() {
        ObservableInit()
    }

    public func subscribe<Observer: SyncObserverType>(_ c: C, _ observer: Observer) async -> AnyDisposable
        where Element == Observer.Element {
        rxAbstractMethod()
    }

    public func asObservable() -> AsyncObservableToSyncObserver<Element> { self }

    deinit {
        ObservableDeinit()
    }
}

public class SyncObservableToAsyncObserver<Element: Sendable>: SyncObservableToAsyncObserverType, @unchecked Sendable {
    init() {
        ObservableInit()
    }

    public func subscribe<Observer: AsyncObserverType>(_ c: C, _ observer: Observer) -> any SynchronousDisposable
        where Element == Observer.Element {
        rxAbstractMethod()
    }

    public func asObservable() -> SyncObservableToAsyncObserver<Element> { self }

    deinit {
        ObservableDeinit()
    }
}

public class SyncObservableToSyncObserver<Element: Sendable>: SyncObservableToSyncObserverType, @unchecked Sendable {
    init() {
        ObservableInit()
    }

    public func subscribe<Observer: SyncObserverType>(_ c: C, _ observer: Observer) -> any SynchronousDisposable
        where Element == Observer.Element {
        rxAbstractMethod()
    }

    public func asObservable() -> SyncObservableToSyncObserver<Element> { self }

    deinit {
        ObservableDeinit()
    }
}

public protocol SubscribeCallType: Sendable {
    
}

public protocol SyncToSyncSubscribeCallType: SubscribeCallType {
    func subscribe<Observer: SyncObserverType>(_ c: C, _ observer: Observer) -> DisposableType
}

public protocol SyncToAsyncSubscribeCallType: SubscribeCallType {
    func subscribe<Observer: AsyncObserverType>(_ c: C, _ observer: Observer) -> DisposableType
}

public protocol AsyncToSyncSubscribeCallType: SubscribeCallType {
    func subscribe<Observer: SyncObserverType>(_ c: C, _ observer: Observer) async -> DisposableType
}

public protocol AsyncToAsyncSubscribeCallType: SubscribeCallType {
    func subscribe<Observer: AsyncObserverType>(_ c: C, _ observer: Observer) async -> DisposableType
}

//
//public struct AnySyncSubscribeCall<Observer: ObserverType, Disposable: DisposableType>: SyncSubscribeCallType {
//    let call: @Sendable (C, Observer) -> Disposable
//    
//    public func subscribe<Observer: ObserverType>(_ c: C, _ observer: Observer) -> Disposable where Observer == Self.O {
//        call(c.call(), observer)
//    }
//}
//
//public struct AnyAsyncSubscribeCall<Disposable: DisposableType>: AsyncSubscribeCallType {
//    let call: @Sendable (C, Observer) async -> Disposable
//    
//    public func subscribe<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> Disposable {
//        await call(c.call(), observer)
//    }
//}

public struct AnyObservable<SubscribeCall: SubscribeCallType> {
    let subscribe: SubscribeCall
}
