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

func ObservableInit() async {
#if TRACE_RESOURCES
        _ = await Resources.incrementTotal()
#endif
}

func ObservableDeinit() {
#if TRACE_RESOURCES
        Task {
            _ = await Resources.decrementTotal()
        }
#endif
}

public class Observable<Element>: ObservableType {
    init() async {
        await ObservableInit()
    }

    public func subscribe<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> SynchronizedDisposable where Observer.Element == Element {
        rxAbstractMethod()
    }

    public func asObservable() -> Observable<Element> { self }

    deinit {
        ObservableDeinit()
    }
}

public class UnsynchronizedObservable<Element>: UnsynchronizedObservableType {
    init() {
        Task {
            await ObservableInit()
        }
    }

    public func subscribe<Observer: ObserverType>(_ c: C, _ observer: Observer) -> UnsynchronizedDisposable where Observer.Element == Element {
        rxAbstractMethod()
    }

    public func asObservable() -> UnsynchronizedObservable<Element> { self }

    deinit {
        ObservableDeinit()
    }
}
