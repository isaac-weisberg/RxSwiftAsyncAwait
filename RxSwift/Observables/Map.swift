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
    func map<Result>(_ transform: @escaping (Element) throws -> Result)
        -> Observable<Result> {
        Map(source: self, transform: transform)
    }
}

private final class Map<Source: ObservableType, ResultType: Sendable>: Producer<ResultType> {
    typealias SourceType = Source.Element
    typealias Transform = (SourceType) throws -> ResultType

    private let source: Source

    private let transform: Transform

    init(source: Source, transform: @escaping Transform) {
        self.source = source
        self.transform = transform
        super.init()
    }

    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> AsynchronousDisposable
        where Observer.Element == ResultType {
        let subscription = await source.subscribe(c.call(), AnonymousObserver(c.call()) { [transform] c, element in
            switch element {
            case .next(let element):
                do {
                    try await observer.onNext(transform(element), c.call())
                } catch {
                    await observer.onError(error, c.call())
                }
            case .error(let error):
                await observer.onError(error, c.call())
            case .completed:
                await observer.onCompleted(c.call())
            }
        })
        return subscription
    }
}
