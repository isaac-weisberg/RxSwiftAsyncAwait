//
//  ElementAt.swift
//  RxSwift
//
//  Created by Junior B. on 21/10/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

public extension ObservableType {
    /**
     Returns a sequence emitting only element _n_ emitted by an Observable

     - seealso: [elementAt operator on reactivex.io](http://reactivex.io/documentation/operators/elementat.html)

     - parameter index: The index of the required element (starting from 0).
     - returns: An observable sequence that emits the desired element as its own sole emission.
     */
    @available(*, deprecated, renamed: "element(at:)")
    func elementAt(_ index: Int) async
        -> Observable<Element> {
        await element(at: index)
    }

    /**
     Returns a sequence emitting only element _n_ emitted by an Observable

     - seealso: [elementAt operator on reactivex.io](http://reactivex.io/documentation/operators/elementat.html)

     - parameter index: The index of the required element (starting from 0).
     - returns: An observable sequence that emits the desired element as its own sole emission.
     */
    func element(at index: Int) async
        -> Observable<Element> {
        await ElementAt(source: asObservable(), index: index, throwOnEmpty: true)
    }
}

private final actor ElementAtSink<Observer: ObserverType>: Sink, ObserverType {
    typealias SourceType = Observer.Element
    typealias Parent = ElementAt<SourceType>

    let baseSink: BaseSink<Observer>

    let parent: Parent
    var i: Int

    init(parent: Parent, observer: Observer, cancel: Cancelable) async {
        self.parent = parent
        i = parent.index

        baseSink = await BaseSink(observer: observer, cancel: cancel)
    }

    func on(_ event: Event<SourceType>, _ c: C) async {
        switch event {
        case .next:
            if i == 0 {
                await forwardOn(event, c.call())
                await forwardOn(.completed, c.call())
                await dispose()
            }

            do {
                _ = try decrementChecked(&i)
            } catch let e {
                await self.forwardOn(.error(e), c.call())
                await self.dispose()
                return
            }

        case .error(let e):
            await forwardOn(.error(e), c.call())
            await dispose()

        case .completed:
            if parent.throwOnEmpty {
                await forwardOn(.error(RxError.argumentOutOfRange), c.call())
            } else {
                await forwardOn(.completed, c.call())
            }

            await dispose()
        }
    }
}

private final class ElementAt<SourceType>: Producer<SourceType> {
    let source: Observable<SourceType>
    let throwOnEmpty: Bool
    let index: Int

    init(source: Observable<SourceType>, index: Int, throwOnEmpty: Bool) async {
        if index < 0 {
            rxFatalError("index can't be negative")
        }

        self.source = source
        self.index = index
        self.throwOnEmpty = throwOnEmpty
        await super.init()
    }

    override func run<Observer: ObserverType>(
        _ c: C,
        _ observer: Observer,
        cancel: Cancelable
    )
        async -> (sink: Disposable, subscription: Disposable) where Observer.Element == SourceType {
        let sink = await ElementAtSink(parent: self, observer: observer, cancel: cancel)
        let subscription = await source.subscribe(c.call(), sink)
        return (sink: sink, subscription: subscription)
    }
}
