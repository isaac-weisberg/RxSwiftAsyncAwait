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
        -> Observable<Element>
    {
        await self.element(at: index)
    }

    /**
     Returns a sequence emitting only element _n_ emitted by an Observable

     - seealso: [elementAt operator on reactivex.io](http://reactivex.io/documentation/operators/elementat.html)

     - parameter index: The index of the required element (starting from 0).
     - returns: An observable sequence that emits the desired element as its own sole emission.
     */
    func element(at index: Int) async
        -> Observable<Element>
    {
        await ElementAt(source: self.asObservable(), index: index, throwOnEmpty: true)
    }
}

private final class ElementAtSink<Observer: ObserverType>: Sink<Observer>, ObserverType {
    typealias SourceType = Observer.Element
    typealias Parent = ElementAt<SourceType>

    let parent: Parent
    var i: Int

    init(parent: Parent, observer: Observer, cancel: Cancelable) async {
        self.parent = parent
        self.i = parent.index

        await super.init(observer: observer, cancel: cancel)
    }

    func on(_ event: Event<SourceType>, _ c: C) async {
        switch event {
        case .next:

            if self.i == 0 {
                await self.forwardOn(event, c.call())
                await self.forwardOn(.completed, c.call())
                await self.dispose()
            }

            do {
                _ = try decrementChecked(&self.i)
            } catch let e {
                await self.forwardOn(.error(e), c.call())
                await self.dispose()
                return
            }

        case .error(let e):
            await self.forwardOn(.error(e), c.call())
            await self.dispose()

        case .completed:
            if self.parent.throwOnEmpty {
                await self.forwardOn(.error(RxError.argumentOutOfRange), c.call())
            } else {
                await self.forwardOn(.completed, c.call())
            }

            await self.dispose()
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

    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer, cancel: Cancelable) async -> (sink: Disposable, subscription: Disposable) where Observer.Element == SourceType {
        let sink = await ElementAtSink(parent: self, observer: observer, cancel: cancel)
        let subscription = await self.source.subscribe(C(), sink)
        return (sink: sink, subscription: subscription)
    }
}
