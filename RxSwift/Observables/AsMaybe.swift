//
//  AsMaybe.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 3/12/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

private final actor AsMaybeSink<Observer: ObserverType>: Sink, ObserverType {
    typealias Element = Observer.Element

    private var element: Event<Element>?
    let baseSink: BaseSink<Observer>

    init(observer: Observer, cancel: Cancelable) async {
        baseSink = await BaseSink(observer: observer, cancel: cancel)
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
            }
            await forwardOn(.completed, c.call())
            await dispose()
        }
    }
}

final class AsMaybe<Element>: Producer<Element> {
    private let source: Observable<Element>

    init(source: Observable<Element>) async {
        self.source = source
        await super.init()
    }

    override func run<Observer: ObserverType>(
        _ c: C,
        _ observer: Observer,
        cancel: Cancelable
    )
        async -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        let sink = await AsMaybeSink(observer: observer, cancel: cancel)
        let subscription = await source.subscribe(c.call(), sink)
        return (sink: sink, subscription: subscription)
    }
}
