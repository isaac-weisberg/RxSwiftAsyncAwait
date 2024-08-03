//
//  Materialize.swift
//  RxSwift
//
//  Created by sergdort on 08/03/2017.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

public extension ObservableType {
    /**
     Convert any Observable into an Observable of its events.
     - seealso: [materialize operator on reactivex.io](http://reactivex.io/documentation/operators/materialize-dematerialize.html)
     - returns: An observable sequence that wraps events in an Event<E>. The returned Observable never errors, but it does complete after observing all of the events of the underlying Observable.
     */
    func materialize() async -> Observable<Event<Element>> {
        await Materialize(source: self.asObservable())
    }
}

private final actor MaterializeSink<Element, Observer: ObserverType>: Sink, ObserverType where Observer.Element == Event<Element> {
    let baseSink: BaseSink<Observer>
    init(observer: Observer, cancel: SynchronizedCancelable) async {
        self.baseSink = await BaseSink(observer: observer, cancel: cancel)
    }
    func on(_ event: Event<Element>, _ c: C) async {
        await self.forwardOn(.next(event), c.call())
        if event.isStopEvent {
            await self.forwardOn(.completed, c.call())
            await self.dispose()
        }
    }
}

private final class Materialize<T>: Producer<Event<T>> {
    private let source: Observable<T>

    init(source: Observable<T>) async {
        self.source = source
        await super.init()
    }

    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer, cancel: SynchronizedCancelable) async -> (sink: SynchronizedDisposable, subscription: SynchronizedDisposable) where Observer.Element == Element {
        let sink = await MaterializeSink(observer: observer, cancel: cancel)
        let subscription = await self.source.subscribe(c.call(), sink)

        return (sink: sink, subscription: subscription)
    }
}
