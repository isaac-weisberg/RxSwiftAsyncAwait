//
//  First.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 7/31/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

private final actor FirstSink<Element, Observer: ObserverType>: SinkOverSingleSubscription,
    ObserverType where Observer.Element == Element? {
    typealias Parent = First<Element>
    let baseSink: BaseSinkOverSingleSubscription<Observer>

    init(observer: Observer) {
        baseSink = BaseSinkOverSingleSubscription(observer: observer)
    }

    func on(_ event: Event<Element>, _ c: C) async {
        if baseSink.disposed {
            return
        }
        switch event {
        case .next(let value):
            await forwardOn(.next(value), c.call())
            await forwardOn(.completed, c.call())
            await dispose()
        case .error(let error):
            await forwardOn(.error(error), c.call())
            await dispose()
        case .completed:
            await forwardOn(.next(nil), c.call())
            await forwardOn(.completed, c.call())
            await dispose()
        }
    }

    func dispose() async {
        await baseSink.setDisposed()?.dispose()
    }
}

final class First<Element: Sendable>: Producer<Element?> {
    private let source: Observable<Element>

    init(source: Observable<Element>) {
        self.source = source
        super.init()
    }

    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> AsynchronousDisposable
        where Observer.Element == Element? {
        let sink = FirstSink(observer: observer)
        await sink.run(c.call(), source)
        return sink
    }
}
