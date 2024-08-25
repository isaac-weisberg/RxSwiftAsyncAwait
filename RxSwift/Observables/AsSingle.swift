//
//  AsSingle.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 3/12/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

private final actor AsSingleSink<Observer: ObserverType>: SinkOverSingleSubscription, ObserverType {
    typealias Element = Observer.Element

    let baseSink: BaseSinkOverSingleSubscription<Observer>

    private var element: Event<Element>?

    init(observer: Observer) {
        baseSink = BaseSinkOverSingleSubscription(observer: observer)
    }

    func on(_ event: Event<Element>, _ c: C) async {
        switch event {
        case .next:
            if element != nil {
                await forwardOn(.error(RxError.moreThanOneElement), c.call())
                await dispose()
            }

            element = event
        case .error:
            await forwardOn(event, c.call())
            await dispose()
        case .completed:
            if let element {
                await forwardOn(element, c.call())
                await forwardOn(.completed, c.call())
            } else {
                await forwardOn(.error(RxError.noElements), c.call())
            }
            await dispose()
        }
    }

    func dispose() async {
        await baseSink.setDisposed()?.dispose()
    }
}

final class AsSingle<Element: Sendable>: Producer<Element> {
    private let source: Observable<Element>

    init(source: Observable<Element>) {
        self.source = source
        super.init()
    }

    override func run<Observer: ObserverType>(
        _ c: C,
        _ observer: Observer
    )
        async -> AsynchronousDisposable where Observer.Element == Element {
        let sink = AsSingleSink(observer: observer)
        await sink.run(c.call(), source)
        return sink
    }
}
