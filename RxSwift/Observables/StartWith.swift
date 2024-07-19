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
    func startWith(_ elements: Element ...) async
        -> Observable<Element>
    {
        return await StartWith(source: self.asObservable(), elements: elements)
    }
}

private final class StartWith<Element>: Producer<Element> {
    let elements: [Element]
    let source: Observable<Element>

    init(source: Observable<Element>, elements: [Element]) async {
        self.source = source
        self.elements = elements
        await super.init()
    }

    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer, cancel: Cancelable) async -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        for e in self.elements {
            await observer.on(.next(e), c.call())
        }

        return (sink: Disposables.create(), subscription: await self.source.subscribe(c.call(), observer))
    }
}
