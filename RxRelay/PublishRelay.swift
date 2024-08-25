//
//  PublishRelay.swift
//  RxRelay
//
//  Created by Krunoslav Zaher on 3/28/15.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

import RxSwift

/// PublishRelay is a wrapper for `PublishSubject`.
///
/// Unlike `PublishSubject` it can't terminate with error or completed.
public final class PublishRelay<Element: Sendable>: ObservableType {
    private let subject: PublishSubject<Element>

    #if VICIOUS_TRACING
        public func accept(
            _ event: Element,
            file: StaticString = #file,
            function: StaticString = #function,
            line: UInt = #line
        )
            async {
            await subject.onNext(event, C(file, function, line))
        }
    #else
        public func accept(_ event: Element) async {
            await subject.onNext(event, C())
        }
    #endif
    
    /// Accepts `event` and emits it to subscribers
    public func accept(_ event: Element, _ c: C) async {
        await subject.onNext(event, c.call())
    }

    /// Initializes with internal empty subject.
    public init() {
        subject = PublishSubject()
    }

    /// Subscribes observer
    public func subscribe<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> Disposable
        where Observer.Element == Element {
        await subject.subscribe(c.call(), observer)
    }

    /// - returns: Canonical interface for push style sequence
    public func asObservable() -> Observable<Element> {
        subject.asObservable()
    }

    /// Convert to an `Infallible`
    ///
    /// - returns: `Infallible<Element>`
//    public func asInfallible() async -> Infallible<Element> {
//        await asInfallible(onErrorFallbackTo: .empty())
//    }
}
