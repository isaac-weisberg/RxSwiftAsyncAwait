//
//  StartWith.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 4/6/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

public extension ObservableType {
    /**
     Prepends a sequence of values to an observable sequence.

     - seealso: [startWith operator on reactivex.io](http://reactivex.io/documentation/operators/startwith.html)

     - parameter elements: Elements to prepend to the specified sequence.
     - returns: The source sequence prepended with the specified values.
     */
    func startWith(_ elements: Element ...) -> Observable<Element> {
        StartWith(source: asObservable(), elements: elements)
    }
}

private final class StartWith<Element: Sendable>: Producer<Element> {
    let elements: [Element]
    let source: Observable<Element>

    init(source: Observable<Element>, elements: [Element]) {
        self.source = source
        self.elements = elements
        super.init()
    }

    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> AsynchronousDisposable
        where Observer.Element == Element {
        for e in elements {
            await observer.on(.next(e), c.call())
        }

        return await source.subscribe(c.call(), observer)
    }
}
