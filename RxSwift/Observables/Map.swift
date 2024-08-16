//
//  Map.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 3/15/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

public extension ObservableType {
    /**
     Projects each element of an observable sequence into a new form.

     - seealso: [map operator on reactivex.io](http://reactivex.io/documentation/operators/map.html)

     - parameter transform: A transform function to apply to each source element.
     - returns: An observable sequence whose elements are the result of invoking the transform function on each element of source.

     */
    func map<Result>(_ transform: @Sendable @escaping (Element) throws -> Result)
        -> Observable<Result> {
        Map(source: asObservable(), transform: transform)
    }
}

private final actor MapSink<Element: Sendable, Observer: ObserverType>: SinkOverSingleSubscription, ObserverType {
    typealias Predicate = (Element) throws -> Observer.Element

    private let predicate: Predicate
    let baseSink: BaseSinkOverSingleSubscription<Observer>

    init(predicate: @escaping Predicate, observer: Observer) {
        self.predicate = predicate

        baseSink = BaseSinkOverSingleSubscription(observer: observer)
    }

    func on(_ event: Event<Element>, _ c: C) async {
        switch event {
        case .next(let element):
            do {
                let newElement = try predicate(element)
                await forwardOn(.next(newElement), c.call())
            } catch {
                await forwardOn(.error(error), c.call())
                await dispose()
            }
        case .error(let error):
            await forwardOn(.error(error), c.call())
            await dispose()
        case .completed:
            await forwardOn(.completed, c.call())
            await dispose()
        }
    }

    func dispose() async {
        await baseSink.setDisposed()?.dispose()
    }
}

private final class Map<Element: Sendable, ResultType: Sendable>: Producer<ResultType> {
    typealias SourceType = Element
    typealias Transform = @Sendable (SourceType) throws -> ResultType

    private let source: Observable<Element>

    private let transform: Transform

    init(source: Observable<Element>, transform: @escaping Transform) {
        self.source = source
        self.transform = transform
        super.init()
    }

    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> AsynchronousDisposable
        where Observer.Element == ResultType {
        let sink = MapSink(predicate: transform, observer: observer)
        await sink.run(c.call(), source)
        return sink
    }
}
