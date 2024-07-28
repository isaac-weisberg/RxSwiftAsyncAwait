//
//  Dematerialize.swift
//  RxSwift
//
//  Created by Jamie Pinkham on 3/13/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

public extension ObservableType where Element: EventConvertible {
    /**
     Convert any previously materialized Observable into it's original form.
     - seealso: [materialize operator on reactivex.io](http://reactivex.io/documentation/operators/materialize-dematerialize.html)
     - returns: The dematerialized observable sequence.
     */
    func dematerialize() async -> Observable<Element.Element> {
        await Dematerialize(source: self.asObservable())
    }
}

private final actor DematerializeSink<T: EventConvertible, Observer: ObserverType>: Sink, ObserverType where Observer.Element == T.Element {
    
    let baseSink: BaseSink<Observer>
    
    init(observer: Observer, cancel: Cancelable) async {
        baseSink = await BaseSink(observer: observer, cancel: cancel)
    }
    
    fileprivate func on(_ event: Event<T>, _ c: C) async {
        switch event {
        case .next(let element):
            await self.forwardOn(element.event, c.call())
            if element.event.isStopEvent {
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

private final class Dematerialize<T: EventConvertible>: Producer<T.Element> {
    private let source: Observable<T>

    init(source: Observable<T>) async {
        self.source = source
        await super.init()
    }

    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer, cancel: Cancelable) async -> (sink: Disposable, subscription: Disposable) where Observer.Element == T.Element {
        let sink = await DematerializeSink<T, Observer>(observer: observer, cancel: cancel)
        let subscription = await self.source.subscribe(c.call(), sink)
        return (sink: sink, subscription: subscription)
    }
}
