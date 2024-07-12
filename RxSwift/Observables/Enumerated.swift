//
//  Enumerated.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 8/6/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

public extension ObservableType {
    /**
     Enumerates the elements of an observable sequence.

     - seealso: [map operator on reactivex.io](http://reactivex.io/documentation/operators/map.html)

     - returns: An observable sequence that contains tuples of source sequence elements and their indexes.
     */
    func enumerated()
        -> Observable<(index: Int, element: Element)>
    {
        Enumerated(source: self.asObservable())
    }
}

private final class EnumeratedSink<Element, Observer: ObserverType>: Sink<Observer>, ObserverType where Observer.Element == (index: Int, element: Element) {
    var index = 0

    func on(_ event: Event<Element>) async {
        switch event {
        case .next(let value):
            do {
                let nextIndex = try incrementChecked(&self.index)
                let next = (index: nextIndex, element: value)
                await self.forwardOn(.next(next))
            }
            catch let e {
                await self.forwardOn(.error(e))
                await self.dispose()
            }
        case .completed:
            await self.forwardOn(.completed)
            await self.dispose()
        case .error(let error):
            await self.forwardOn(.error(error))
            await self.dispose()
        }
    }
}

private final class Enumerated<Element>: Producer<(index: Int, element: Element)> {
    private let source: Observable<Element>

    init(source: Observable<Element>) {
        self.source = source
    }

    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) async -> (sink: Disposable, subscription: Disposable) where Observer.Element == (index: Int, element: Element) {
        let sink = await EnumeratedSink<Element, Observer>(observer: observer, cancel: cancel)
        let subscription = await self.source.subscribe(sink)
        return (sink: sink, subscription: subscription)
    }
}
