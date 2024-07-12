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

public typealias RxObservable<Element> = RxSwift.Observable<Element>

public class Observable<Element>: ObservableType {
    init() async {
#if TRACE_RESOURCES
        _ = await Resources.incrementTotal()
#endif
    }

    public func subscribe<Observer: ObserverType>(_ observer: Observer) async -> Disposable where Observer.Element == Element {
        rxAbstractMethod()
    }

    public func asObservable() -> Observable<Element> { self }

    deinit {
#if TRACE_RESOURCES
        Task {
            _ = await Resources.decrementTotal()
        }
#endif
    }
}
