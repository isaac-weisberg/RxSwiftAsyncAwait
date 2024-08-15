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
        await source.subscribe(c.call(), AnyObserver<SourceType>(eventHandler: { event, c in
            switch event {
            case .next(let element):
                do {
                    if let mappedElement = try self.transform(element) {
                        await observer.on(.next(mappedElement), c.call())
                    }
                } catch let e {
                    await observer.on(.error(e), c.call())
                }
            case .error(let error):
                await observer.on(.error(error), c.call())
            case .completed:
                await observer.on(.completed, c.call())
            }
        }))
    }
}
