//
//  Reduce.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 4/1/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

public extension ObservableType {
    /**
     Applies an `accumulator` function over an observable sequence, returning the result of the aggregation as a single element in the result sequence. The specified `seed` value is used as the initial accumulator value.

     For aggregation behavior with incremental intermediate results, see `scan`.

     - seealso: [reduce operator on reactivex.io](http://reactivex.io/documentation/operators/reduce.html)

     - parameter seed: The initial accumulator value.
     - parameter accumulator: A accumulator function to be invoked on each element.
     - parameter mapResult: A function to transform the final accumulator value into the result value.
     - returns: An observable sequence containing a single element with the final accumulator value.
     */
    func reduce<A, Result>(_ seed: A, accumulator: @escaping (A, Element) throws -> A, mapResult: @escaping (A) throws -> Result)
        -> Observable<Result>
    {
        Reduce(source: self.asObservable(), seed: seed, accumulator: accumulator, mapResult: mapResult)
    }

    /**
     Applies an `accumulator` function over an observable sequence, returning the result of the aggregation as a single element in the result sequence. The specified `seed` value is used as the initial accumulator value.

     For aggregation behavior with incremental intermediate results, see `scan`.

     - seealso: [reduce operator on reactivex.io](http://reactivex.io/documentation/operators/reduce.html)

     - parameter seed: The initial accumulator value.
     - parameter accumulator: A accumulator function to be invoked on each element.
     - returns: An observable sequence containing a single element with the final accumulator value.
     */
    func reduce<A>(_ seed: A, accumulator: @escaping (A, Element) throws -> A)
        -> Observable<A>
    {
        Reduce(source: self.asObservable(), seed: seed, accumulator: accumulator, mapResult: { $0 })
    }
}

private final class ReduceSink<SourceType, AccumulateType, Observer: ObserverType>: Sink<Observer>, ObserverType {
    typealias ResultType = Observer.Element
    typealias Parent = Reduce<SourceType, AccumulateType, ResultType>

    private let parent: Parent
    private var accumulation: AccumulateType

    init(parent: Parent, observer: Observer, cancel: Cancelable) async {
        self.parent = parent
        self.accumulation = parent.seed

        await super.init(observer: observer, cancel: cancel)
    }

    func on(_ event: Event<SourceType>) async {
        switch event {
        case .next(let value):
            do {
                self.accumulation = try self.parent.accumulator(self.accumulation, value)
            }
            catch let e {
                await self.forwardOn(.error(e))
                await self.dispose()
            }
        case .error(let e):
            await self.forwardOn(.error(e))
            await self.dispose()
        case .completed:
            do {
                let result = try self.parent.mapResult(self.accumulation)
                await self.forwardOn(.next(result))
                await self.forwardOn(.completed)
                await self.dispose()
            }
            catch let e {
                await self.forwardOn(.error(e))
                await self.dispose()
            }
        }
    }
}

private final class Reduce<SourceType, AccumulateType, ResultType>: Producer<ResultType> {
    typealias AccumulatorType = (AccumulateType, SourceType) throws -> AccumulateType
    typealias ResultSelectorType = (AccumulateType) throws -> ResultType

    private let source: Observable<SourceType>
    fileprivate let seed: AccumulateType
    fileprivate let accumulator: AccumulatorType
    fileprivate let mapResult: ResultSelectorType

    init(source: Observable<SourceType>, seed: AccumulateType, accumulator: @escaping AccumulatorType, mapResult: @escaping ResultSelectorType) {
        self.source = source
        self.seed = seed
        self.accumulator = accumulator
        self.mapResult = mapResult
    }

    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) async -> (sink: Disposable, subscription: Disposable) where Observer.Element == ResultType {
        let sink = await ReduceSink(parent: self, observer: observer, cancel: cancel)
        let subscription = await self.source.subscribe(sink)
        return (sink: sink, subscription: subscription)
    }
}
