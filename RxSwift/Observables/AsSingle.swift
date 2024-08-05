//
//  AsSingle.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 3/12/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

private final actor AsSingleSink<Observer: ObserverType>: Sink, ObserverType {
    typealias Element = Observer.Element

    let baseSink: BaseSink<Observer>

    private var element: Event<Element>?

    init(observer: Observer) async {
        baseSink = BaseSink(observer: observer)
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
}

final class AsSingle<Element>: Producer<Element> {
    private let source: Observable<Element>

    init(source: Observable<Element>) async {
        self.source = source
        await super.init()
    }

    override func run<Observer: ObserverType>(
        _ c: C,
        _ observer: Observer
    )
        async -> SynchronizedDisposable where Observer.Element == Element {
        let sink = await AsSingleSink(observer: observer)
        let subscription = await source.subscribe(c.call(), sink)
        return sink
    }
}
