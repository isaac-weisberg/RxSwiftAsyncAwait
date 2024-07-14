//
//  Scan.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 6/14/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

public extension ObservableType {
    /**
     Applies an accumulator function over an observable sequence and returns each intermediate result. The specified seed value is used as the initial accumulator value.

     For aggregation behavior with no intermediate results, see `reduce`.

     - seealso: [scan operator on reactivex.io](http://reactivex.io/documentation/operators/scan.html)

     - parameter seed: The initial accumulator value.
     - parameter accumulator: An accumulator function to be invoked on each element.
     - returns: An observable sequence containing the accumulated values.
     */
    func scan<A>(into seed: A, accumulator: @escaping (inout A, Element) throws -> Void) async
        -> Observable<A>
    {
        await Scan(source: self.asObservable(), seed: seed, accumulator: accumulator)
    }

    /**
     Applies an accumulator function over an observable sequence and returns each intermediate result. The specified seed value is used as the initial accumulator value.

     For aggregation behavior with no intermediate results, see `reduce`.

     - seealso: [scan operator on reactivex.io](http://reactivex.io/documentation/operators/scan.html)

     - parameter seed: The initial accumulator value.
     - parameter accumulator: An accumulator function to be invoked on each element.
     - returns: An observable sequence containing the accumulated values.
     */
    func scan<A>(_ seed: A, accumulator: @escaping (A, Element) async throws -> A) async
        -> Observable<A>
    {
        return await Scan(source: self.asObservable(), seed: seed) { acc, element in
            let currentAcc = acc
            acc = try await accumulator(currentAcc, element)
        }
    }
}

private final class ScanSink<Element, Observer: ObserverType>: Sink<Observer>, ObserverType {
    typealias Accumulate = Observer.Element
    typealias Parent = Scan<Element, Accumulate>

    private let parent: Parent
    private var accumulate: Accumulate

    init(parent: Parent, observer: Observer, cancel: Cancelable) async {
        self.parent = parent
        self.accumulate = parent.seed
        await super.init(observer: observer, cancel: cancel)
    }

    func on(_ event: Event<Element>) async {
        switch event {
        case .next(let element):
            do {
                try await self.parent.accumulator(&self.accumulate, element)
                await self.forwardOn(.next(self.accumulate))
            }
            catch {
                await self.forwardOn(.error(error))
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

private final class Scan<Element, Accumulate>: Producer<Accumulate> {
    typealias Accumulator = (inout Accumulate, Element) async throws -> Void

    private let source: Observable<Element>
    fileprivate let seed: Accumulate
    fileprivate let accumulator: Accumulator

    init(source: Observable<Element>, seed: Accumulate, accumulator: @escaping Accumulator) async {
        self.source = source
        self.seed = seed
        self.accumulator = accumulator
        await super.init()
    }

    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) async -> (sink: Disposable, subscription: Disposable) where Observer.Element == Accumulate {
        let sink = await ScanSink(parent: self, observer: observer, cancel: cancel)
        let subscription = await self.source.subscribe(sink)
        return (sink: sink, subscription: subscription)
    }
}
