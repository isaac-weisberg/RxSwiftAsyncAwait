//
//  Deferred.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 4/19/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

public extension ObservableType {
    /**
     Returns an observable sequence that invokes the specified factory function whenever a new observer subscribes.

     - seealso: [defer operator on reactivex.io](http://reactivex.io/documentation/operators/defer.html)

     - parameter observableFactory: Observable factory function to invoke for each observer that subscribes to the resulting sequence.
     - returns: An observable sequence whose observers trigger an invocation of the given observable factory function.
     */
    static func deferred(_ observableFactory: @escaping () async throws -> Observable<Element>) async
        -> Observable<Element>
    {
        await Deferred(observableFactory: observableFactory)
    }
}

private final actor DeferredSink<Source: ObservableType, Observer: ObserverType>: Sink, ObserverType where Source.Element == Observer.Element {
    typealias Element = Observer.Element
    typealias Parent = Deferred<Source>
    let baseSink: BaseSink<Observer>
    
    init(observer: Observer, cancel: SynchronizedCancelable) async {
        baseSink = await BaseSink(observer: observer, cancel: cancel)
    }

    func run(_ c: C, _ parent: Parent) async -> Disposable {
        do {
            let result = try await parent.observableFactory()
            return await result.subscribe(c.call(), self)
        }
        catch let e {
            await self.forwardOn(.error(e), c.call())
            await self.dispose()
            return Disposables.create()
        }
    }

    func on(_ event: Event<Element>, _ c: C) async {
        await self.forwardOn(event, c.call())

        switch event {
        case .next:
            break
        case .error:
            await self.dispose()
        case .completed:
            await self.dispose()
        }
    }
}

private final class Deferred<Source: ObservableType>: Producer<Source.Element> {
    typealias Factory = () async throws -> Source

    let observableFactory: Factory

    init(observableFactory: @escaping Factory) async {
        self.observableFactory = observableFactory
        await super.init()
    }

    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer, cancel: SynchronizedCancelable) async -> (sink: SynchronizedDisposable, subscription: SynchronizedDisposable)
        where Observer.Element == Source.Element
    {
        let sink = await DeferredSink<Source, Observer>(observer: observer, cancel: cancel)
        let subscription = await sink.run(c.call(), self)
        return (sink: sink, subscription: subscription)
    }
}
