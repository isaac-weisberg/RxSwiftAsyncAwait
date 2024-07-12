//
//  AsSingle.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 3/12/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

private final class AsSingleSink<Observer: ObserverType>: Sink<Observer>, ObserverType {
    typealias Element = Observer.Element

    private var element: Event<Element>?

    func on(_ event: Event<Element>) async {
        switch event {
        case .next:
            if self.element != nil {
                await self.forwardOn(.error(RxError.moreThanOneElement))
                await self.dispose()
            }

            self.element = event
        case .error:
            await self.forwardOn(event)
            await self.dispose()
        case .completed:
            if let element = self.element {
                await self.forwardOn(element)
                await self.forwardOn(.completed)
            }
            else {
                await self.forwardOn(.error(RxError.noElements))
            }
            await self.dispose()
        }
    }
}

final class AsSingle<Element>: Producer<Element> {
    private let source: Observable<Element>

    init(source: Observable<Element>) {
        self.source = source
    }

    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) async -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        let sink = await AsSingleSink(observer: observer, cancel: cancel)
        let subscription = await self.source.subscribe(sink)
        return (sink: sink, subscription: subscription)
    }
}
