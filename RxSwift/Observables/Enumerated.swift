//
//  Enumerated.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 8/6/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

public extension ObservableConvertibleType {
    /**
     Enumerates the elements of an observable sequence.

     - seealso: [map operator on reactivex.io](http://reactivex.io/documentation/operators/map.html)

     - returns: An observable sequence that contains tuples of source sequence elements and their indexes.
     */
    func enumerated()
        -> Observable<(index: Int, element: Element)> {
        Enumerated(source: asObservable())
    }
}

private final actor EnumeratedSink<Source: Sendable, Observer: ObserverType>: SinkOverSingleSubscription,
    ObserverType where Observer.Element == (
        index: Int,
        element: Source
    ) {
    var index = 0

    let baseSink: BaseSinkOverSingleSubscription<Observer>

    init(observer: Observer) {
        baseSink = BaseSinkOverSingleSubscription(observer: observer)
    }

    func on(_ event: Event<Source>, _ c: C) async {
        if baseSink.disposed {
            return
        }

        switch event {
        case .next(let value):
            do {
                let nextIndex = try incrementChecked(&index)
                let next = (index: nextIndex, element: value)

                await baseSink.observer.on(.next(next), c.call())
            } catch let e {
                await baseSink.observer.on(.error(e), c.call())
                await self.dispose()
            }
        case .completed:
            await baseSink.observer.on(.completed, c.call())
            await dispose()
        case .error(let error):
            await baseSink.observer.on(.error(error), c.call())
            await dispose()
        }
    }

    func dispose() async {
        await baseSink.setDisposed()?.dispose()
    }
}

private final class Enumerated<Source: Sendable>: Producer<(index: Int, element: Source)> {
    private let source: Observable<Source>

    init(source: Observable<Source>) {
        self.source = source
        super.init()
    }

    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> Disposable
        where Observer.Element == (
            index: Int,
            element: Source
        ) {
        let sink = EnumeratedSink(observer: observer)
        await sink.run(c.call(), source)
        return sink
    }
}
