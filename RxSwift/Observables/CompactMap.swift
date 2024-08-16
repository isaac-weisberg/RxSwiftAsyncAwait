//
//  CompactMap.swift
//  RxSwift
//
//  Created by Michael Long on 04/09/2019.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

public extension ObservableType {
    /**
     Projects each element of an observable sequence into an optional form and filters all optional results.

     - parameter transform: A transform function to apply to each source element and which returns an element or nil.
     - returns: An observable sequence whose elements are the result of filtering the transform function for each element of the source.

     */
    func compactMap<Result>(_ transform: @Sendable @escaping (Element) throws -> Result?)
        -> Observable<Result> {
        CompactMap(source: asObservable(), transform: transform)
    }
}

private final actor CompactMapSink<Element: Sendable, Observer: ObserverType>: SinkOverSingleSubscription,
    ObserverType {
    typealias Predicate = (Element) throws -> Observer.Element?

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
                if let newElement = try predicate(element) {
                    await forwardOn(.next(newElement), c.call())
                }
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

private final class CompactMap<SourceType: Sendable, ResultType: Sendable>: Producer<ResultType> {
    typealias Transform = @Sendable (SourceType) throws -> ResultType?

    private let source: Observable<SourceType>

    private let transform: Transform

    init(source: Observable<SourceType>, transform: @escaping Transform) {
        self.source = source
        self.transform = transform
        super.init()
    }

    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> AsynchronousDisposable
        where Observer.Element == ResultType {

        let sink = CompactMapSink(predicate: transform, observer: observer)
        await sink.run(c.call(), source)
        return sink
    }
}
