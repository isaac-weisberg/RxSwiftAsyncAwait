//
//  Filter.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/17/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

public extension ObservableType {
    /**
     Filters the elements of an observable sequence based on a predicate.

     - seealso: [filter operator on reactivex.io](http://reactivex.io/documentation/operators/filter.html)

     - parameter predicate: A function to test each source element for a condition.
     - returns: An observable sequence that contains elements from the input sequence that satisfy the condition.
     */
    func filter(_ predicate: @Sendable @escaping (Element) throws -> Bool)
        -> Observable<Element> {
        Filter(source: asObservable(), predicate: predicate)
    }
}

public extension ObservableType {
    /**
     Skips elements and completes (or errors) when the observable sequence completes (or errors). Equivalent to filter that always returns false.

     - seealso: [ignoreElements operator on reactivex.io](http://reactivex.io/documentation/operators/ignoreelements.html)

     - returns: An observable sequence that skips all elements of the source sequence.
     */
    func ignoreElements()
        -> Observable<Never> {
        flatMap { _ in Observable<Never>.empty() }
    }
}

private final actor FilterSink<Observer: ObserverType>: SinkOverSingleSubscription, ObserverType {
    typealias Predicate = (Element) throws -> Bool
    typealias Element = Observer.Element

    private let predicate: Predicate
    let baseSink: BaseSinkOverSingleSubscription<Observer>

    init(predicate: @escaping Predicate, observer: Observer) {
        self.predicate = predicate

        baseSink = BaseSinkOverSingleSubscription(observer: observer)
    }

    func on(_ event: Event<Element>, _ c: C) async {
        switch event {
        case .next(let value):
            do {
                let satisfies = try predicate(value)
                if satisfies {
                    await forwardOn(.next(value), c.call())
                }
            } catch let e {
                await self.forwardOn(.error(e), c.call())
                await self.dispose()
            }
        case .completed, .error:
            await forwardOn(event, c.call())
            await dispose()
        }
    }

    func dispose() async {
        await baseSink.setDisposed()?.dispose()
    }
}

private final class Filter<Element: Sendable>: Producer<Element> {
    typealias Predicate = @Sendable (Element) throws -> Bool

    private let source: Observable<Element>
    private let predicate: Predicate

    init(source: Observable<Element>, predicate: @escaping Predicate) {
        self.source = source
        self.predicate = predicate
        super.init()
    }

    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> AsynchronousDisposable
        where Observer.Element == Element {
        let sink = FilterSink(predicate: predicate, observer: observer)
        await sink.run(c.call(), source)
        return sink
    }
}
