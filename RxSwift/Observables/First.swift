//
//  First.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 7/31/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

private final class FirstSink<Element, Observer: ObserverType>: Sink<Observer>, ObserverType where Observer.Element == Element? {
    typealias Parent = First<Element>

    func on(_ event: Event<Element>) async {
        switch event {
        case .next(let value):
            await self.forwardOn(.next(value))
            await self.forwardOn(.completed)
            await self.dispose()
        case .error(let error):
            await self.forwardOn(.error(error))
            await self.dispose()
        case .completed:
            await self.forwardOn(.next(nil))
            await self.forwardOn(.completed)
            await self.dispose()
        }
    }
}

final class First<Element>: Producer<Element?> {
    private let source: Observable<Element>

    init(source: Observable<Element>) async {
        self.source = source
        await super.init()
    }

    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) async -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element? {
        let sink = await FirstSink(observer: observer, cancel: cancel)
        let subscription = await self.source.subscribe(sink)
        return (sink: sink, subscription: subscription)
    }
}
