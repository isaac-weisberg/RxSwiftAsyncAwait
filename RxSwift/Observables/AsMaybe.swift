//
//  AsMaybe.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 3/12/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

private final class AsMaybeSink<Observer: ObserverType>: Sink<Observer>, ObserverType {
    typealias Element = Observer.Element

    private var element: Event<Element>?

    func on(_ event: Event<Element>, _ c: C) async {
        switch event {
        case .next:
            if self.element != nil {
                await self.forwardOn(.error(RxError.moreThanOneElement), c.call())
                await self.dispose()
            }

            self.element = event
        case .error:
            await self.forwardOn(event, c.call())
            await self.dispose()
        case .completed:
            if let element = self.element {
                await self.forwardOn(element, c.call())
            }
            await self.forwardOn(.completed, c.call())
            await self.dispose()
        }
    }
}

final class AsMaybe<Element>: Producer<Element> {
    private let source: Observable<Element>

    init(source: Observable<Element>) async {
        self.source = source
        await super.init()
    }

    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer, cancel: Cancelable) async -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        let sink = await AsMaybeSink(observer: observer, cancel: cancel)
        let subscription = await self.source.subscribe(c.call(), sink)
        return (sink: sink, subscription: subscription)
    }
}
