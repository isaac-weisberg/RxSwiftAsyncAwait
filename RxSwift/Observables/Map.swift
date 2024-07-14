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

private final class MapSink<SourceType, Observer: ObserverType>: Sink<Observer>, ObserverType {
    typealias Transform = (SourceType) async throws -> ResultType

    typealias ResultType = Observer.Element

    private let transform: Transform

    init(transform: @escaping Transform, observer: Observer, cancel: Cancelable) async {
        self.transform = transform
        await super.init(observer: observer, cancel: cancel)
    }

    func on(_ event: Event<SourceType>) async {
        switch event {
        case .next(let element):
            do {
                let mappedElement = try await self.transform(element)
                await self.forwardOn(.next(mappedElement))
            }
            catch let e {
                await self.forwardOn(.error(e))
                await self.dispose()
            }
        case .error(let error):
            await self.forwardOn(.error(error))
            await self.dispose()
        case .completed:
            await self.forwardOn(.completed)
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

    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) async -> (sink: Disposable, subscription: Disposable) where Observer.Element == ResultType {
        let sink = await MapSink(transform: self.transform, observer: observer, cancel: cancel)
        let subscription = await self.source.subscribe(sink)
        return (sink: sink, subscription: subscription)
    }
}
