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
        Dematerialize(source: asObservable())
    }
}

private final actor DematerializeSink<T: EventConvertible, Observer: ObserverType>: SinkOverSingleSubscription,
    ObserverType where Observer.Element == T.Element {

    let baseSink: BaseSinkOverSingleSubscription<Observer>

    init(observer: Observer) async {
        baseSink = BaseSinkOverSingleSubscription(observer: observer)
    }

    fileprivate func on(_ event: Event<T>, _ c: C) async {
        switch event {
        case .next(let element):
            await forwardOn(element.event, c.call())
            if element.event.isStopEvent {
                await dispose()
            }
        case .completed:
            await forwardOn(.completed, c.call())
            await dispose()
        case .error(let error):
            await forwardOn(.error(error), c.call())
            await dispose()
        }
    }

    func dispose() async {
        await baseSink.setDisposed()?.dispose()
    }
}

private final class Dematerialize<T: EventConvertible>: Producer<T.Element> {
    private let source: Observable<T>

    init(source: Observable<T>) {
        self.source = source
        super.init()
    }

    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> AsynchronousDisposable
        where Observer.Element == T.Element {
        let sink = await DematerializeSink<T, Observer>(observer: observer)
        await sink.run(c.call(), source)
        return sink
    }
}
