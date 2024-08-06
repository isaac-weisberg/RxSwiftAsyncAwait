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

public class SyncObservableToAsyncObserver<Element: Sendable>: SyncObservableToAsyncObserverType, @unchecked Sendable {
    init() {
        ObservableInit()
    }

    public func subscribe<Observer>(_ c: C, _ observer: Observer) -> any SynchronousDisposable
        where Observer: AsyncObserverType, Element == Observer.Element {
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

    public func subscribe<Observer>(_ c: C, _ observer: Observer) -> any SynchronousDisposable
        where Observer: SyncObserverType, Element == Observer.Element {
        rxAbstractMethod()
    }

    public func asObservable() -> SyncObservableToSyncObserver<Element> { self }

    deinit {
        ObservableDeinit()
    }
}
