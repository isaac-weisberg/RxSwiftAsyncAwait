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
    static func deferred(_ observableFactory: @escaping () async throws -> Observable<Element>)
        -> Observable<Element> {
        Deferred(observableFactory: observableFactory)
    }
}

private final actor DeferredSink<Source: ObservableType, Observer: ObserverType>: Sink,
    ObserverType where Source.Element == Observer.Element {
    typealias Element = Observer.Element
    typealias Parent = Deferred<Source>
    let baseSink: BaseSink<Observer>
    let disposable = SingleAssignmentDisposable()

    init(observer: Observer) async {
        baseSink = BaseSink(observer: observer)
    }

    func run(_ c: C, _ parent: Parent) async {
        let result: Source
        do {
            result = try await parent.observableFactory()
        } catch let e {
            await self.forwardOn(.error(e), c.call())
            await self.dispose()
            return
        }

        await disposable.setDisposable(result.subscribe(c.call(), self))?.dispose()
    }

    func on(_ event: Event<Element>, _ c: C) async {
        await forwardOn(event, c.call())

        switch event {
        case .next:
            break
        case .error:
            await dispose()
        case .completed:
            await dispose()
        }
    }

    func dispose() async {
        baseSink.setDisposed()
        await disposable.dispose()?.dispose()
    }
}

private final class Deferred<Source: ObservableType>: Producer<Source.Element> {
    typealias Factory = () async throws -> Source

    let observableFactory: Factory

    init(observableFactory: @escaping Factory) {
        self.observableFactory = observableFactory
        super.init()
    }

    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> AsynchronousDisposable
        where Observer.Element == Source.Element {
        let sink = await DeferredSink<Source, Observer>(observer: observer)
        await sink.run(c.call(), self)
        return sink
    }
}
