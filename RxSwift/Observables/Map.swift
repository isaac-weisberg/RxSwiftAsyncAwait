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
    func map<Result>(_ transform: @escaping (Element) async throws -> Result) async
        -> Observable<Result>
    {
        await Map(source: self.asObservable(), transform: transform)
    }
}

private final actor MapSink<SourceType, Observer: ObserverType>: Sink, ObserverType {
    typealias Transform = (SourceType) async throws -> ResultType

    typealias ResultType = Observer.Element
    let baseSink: BaseSink<Observer>

    private let transform: Transform

    init(transform: @escaping Transform, observer: Observer, cancel: SynchronizedCancelable) async {
        self.transform = transform
        baseSink = await BaseSink(observer: observer, cancel: cancel)
    }

    func on(_ event: Event<SourceType>, _ c: C) async {
        switch event {
        case .next(let element):
            do {
                let mappedElement = try await self.transform(element)
                await self.forwardOn(.next(mappedElement), c.call())
            }
            catch let e {
                await self.forwardOn(.error(e), c.call())
                await self.dispose()
            }
        case .error(let error):
            await self.forwardOn(.error(error), c.call())
            await self.dispose()
        case .completed:
            await self.forwardOn(.completed, c.call())
            await self.dispose()
        }
    }
}

private final class Map<SourceType, ResultType>: Producer<ResultType> {
    typealias Transform = (SourceType) async throws -> ResultType

    private let source: Observable<SourceType>

    private let transform: Transform

    init(source: Observable<SourceType>, transform: @escaping Transform) async {
        self.source = source
        self.transform = transform
        await super.init()
    }

    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer, cancel: SynchronizedCancelable) async -> (sink: SynchronizedDisposable, subscription: SynchronizedDisposable) where Observer.Element == ResultType {
        let sink = await MapSink(transform: self.transform, observer: observer, cancel: cancel)
        let subscription = await self.source.subscribe(c.call(), sink)
        return (sink: sink, subscription: subscription)
    }
}
