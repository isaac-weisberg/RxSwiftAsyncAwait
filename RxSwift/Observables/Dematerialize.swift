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
    func dematerialize() -> Observable<Element.Element> {
        Dematerialize(source: self.asObservable())
    }
}

private final class DematerializeSink<T: EventConvertible, Observer: ObserverType>: Sink<Observer>, ObserverType where Observer.Element == T.Element {
    fileprivate func on(_ event: Event<T>) async {
        switch event {
        case .next(let element):
            await self.forwardOn(element.event)
            if element.event.isStopEvent {
                await self.dispose()
            }
        case .completed:
            await self.forwardOn(.completed)
            await self.dispose()
        case .error(let error):
            await self.forwardOn(.error(error))
            await self.dispose()
        }
    }
}

private final class Dematerialize<T: EventConvertible>: Producer<T.Element> {
    private let source: Observable<T>

    init(source: Observable<T>) {
        self.source = source
    }

    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) async -> (sink: Disposable, subscription: Disposable) where Observer.Element == T.Element {
        let sink = await DematerializeSink<T, Observer>(observer: observer, cancel: cancel)
        let subscription = await self.source.subscribe(sink)
        return (sink: sink, subscription: subscription)
    }
}
