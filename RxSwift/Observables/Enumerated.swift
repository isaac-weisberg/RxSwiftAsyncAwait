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
        -> Observable<(index: Int, element: Element)> {
        Enumerated(source: self)
    }
}

private final actor EnumeratedSink<Source: ObservableType, Observer: ObserverType>: Sink,
    ObserverType where Observer.Element == (
        index: Int,
        element: Source.Element
    ) {
    var index = 0

    let source: Source
    let baseSink: BaseSink<Observer>

    init(source: Source, observer: Observer) {
        self.source = source
        baseSink = BaseSink(observer: observer)
    }

    var innerDisposable: Disposable?

    func on(_ event: Event<Source.Element>, _ c: C) async {
        switch event {
        case .next(let value):
            do {
                let nextIndex = try incrementChecked(&index)
                let next = (index: nextIndex, element: value)
                await forwardOn(.next(next), c.call())
            } catch let e {
                await self.forwardOn(.error(e), c.call())
                await self.dispose()
            }
        case .completed:
            await forwardOn(.completed, c.call())
            await dispose()
        case .error(let error):
            await forwardOn(.error(error), c.call())
            await dispose()
        }
    }

    func run(_ c: C) async {
        innerDisposable = await source.subscribe(c.call(), self)
    }

    func dispose() async {
        if setDisposed() {
            await innerDisposable?.dispose()
            innerDisposable = nil
        }
    }
}

private final class Enumerated<Source: ObservableType>: Producer<(index: Int, element: Source.Element)> {
    private let source: Source

    init(source: Source) {
        self.source = source
        super.init()
    }

    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> Disposable
        where Observer.Element == (
            index: Int,
            element: Source.Element
        ) {
        let sink = EnumeratedSink(source: source, observer: observer)
        await sink.run(c.call())
        return sink
    }
}
