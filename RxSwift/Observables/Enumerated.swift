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
    func enumerated() async
        -> Observable<(index: Int, element: Element)>
    {
        await Enumerated(source: self.asObservable())
    }
}

private final actor EnumeratedSink<Element, Observer: ObserverType>: Sink, ObserverType where Observer.Element == (index: Int, element: Element) {
    var index = 0
    
    let baseSink: BaseSink<Observer>
    
    init(observer: Observer) async {
        baseSink = BaseSink(observer: observer)
    }

    func on(_ event: Event<Element>, _ c: C) async {
        switch event {
        case .next(let value):
            do {
                let nextIndex = try incrementChecked(&self.index)
                let next = (index: nextIndex, element: value)
                await self.forwardOn(.next(next), c.call())
            }
            catch let e {
                await self.forwardOn(.error(e), c.call())
                await self.dispose()
            }
        case .completed:
            await self.forwardOn(.completed, c.call())
            await self.dispose()
        case .error(let error):
            await self.forwardOn(.error(error), c.call())
            await self.dispose()
        }
    }
}

private final class Enumerated<Element>: Producer<(index: Int, element: Element)> {
    private let source: Observable<Element>

    init(source: Observable<Element>) async {
        self.source = source
        await super.init()
    }

    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> AsynchronousDisposable where Observer.Element == (index: Int, element: Element) {
        let sink = await EnumeratedSink<Element, Observer>(observer: observer)
        let subscription = await self.source.subscribe(c.call(), sink)
        return sink
    }
}
