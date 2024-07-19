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
    func compactMap<Result>(_ transform: @escaping (Element) async throws -> Result?) async
        -> Observable<Result>
    {
        await CompactMap(source: self.asObservable(), transform: transform)
    }
}

private final class CompactMapSink<SourceType, Observer: ObserverType>: Sink<Observer>, ObserverType {
    typealias Transform = (SourceType) async throws -> ResultType?

    typealias ResultType = Observer.Element
    typealias Element = SourceType

    private let transform: Transform

    init(transform: @escaping Transform, observer: Observer, cancel: Cancelable) async {
        self.transform = transform
        await super.init(observer: observer, cancel: cancel)
    }

    func on(_ event: Event<SourceType>, _ c: C) async {
        switch event {
        case .next(let element):
            do {
                if let mappedElement = try await self.transform(element) {
                    await self.forwardOn(.next(mappedElement), c.call())
                }
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

private final class CompactMap<SourceType, ResultType>: Producer<ResultType> {
    typealias Transform = (SourceType) async throws -> ResultType?

    private let source: Observable<SourceType>

    private let transform: Transform

    init(source: Observable<SourceType>, transform: @escaping Transform) async {
        self.source = source
        self.transform = transform
        await super.init()
    }

    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer, cancel: Cancelable) async -> (sink: Disposable, subscription: Disposable) where Observer.Element == ResultType {
        let sink = await CompactMapSink(transform: self.transform, observer: observer, cancel: cancel)
        let subscription = await self.source.subscribe(c.call(), sink)
        return (sink: sink, subscription: subscription)
    }
}
