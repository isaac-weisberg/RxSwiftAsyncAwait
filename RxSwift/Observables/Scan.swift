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
    func scan<A>(into seed: A, accumulator: @escaping (inout A, Element) throws -> Void)
        -> Observable<A> {
        Scan(source: asObservable(), seed: seed, accumulator: accumulator)
    }

    /**
     Applies an accumulator function over an observable sequence and returns each intermediate result. The specified seed value is used as the initial accumulator value.

     For aggregation behavior with no intermediate results, see `reduce`.

     - seealso: [scan operator on reactivex.io](http://reactivex.io/documentation/operators/scan.html)

     - parameter seed: The initial accumulator value.
     - parameter accumulator: An accumulator function to be invoked on each element.
     - returns: An observable sequence containing the accumulated values.
     */
    func scan<A>(_ seed: A, accumulator: @escaping (A, Element) throws -> A)
        -> Observable<A> {
        Scan(source: asObservable(), seed: seed) { acc, element in
            let currentAcc = acc
            acc = try accumulator(currentAcc, element)
        }
    }
}

private final actor ScanSink<Element: Sendable, Observer: ObserverType>: SinkOverSingleSubscription, ObserverType {
    typealias Accumulate = Observer.Element
    typealias Parent = Scan<Element, Accumulate>

    private let parent: Parent
    private var accumulate: Accumulate
    let baseSink: BaseSinkOverSingleSubscription<Observer>

    init(parent: Parent, observer: Observer) async {
        self.parent = parent
        accumulate = parent.seed
        baseSink = BaseSinkOverSingleSubscription(observer: observer)
    }

    func on(_ event: Event<Element>, _ c: C) async {
        switch event {
        case .next(let element):
            do {
                try parent.accumulator(&accumulate, element)
                await forwardOn(.next(accumulate), c.call())
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

private final class Scan<Element: Sendable, Accumulate: Sendable>: Producer<Accumulate> {
    typealias Accumulator = (inout Accumulate, Element) throws -> Void

    private let source: Observable<Element>
    fileprivate let seed: Accumulate
    fileprivate let accumulator: Accumulator

    init(source: Observable<Element>, seed: Accumulate, accumulator: @escaping Accumulator) {
        self.source = source
        self.seed = seed
        self.accumulator = accumulator
        super.init()
    }

    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> AsynchronousDisposable
        where Observer.Element == Accumulate {
        let sink = await ScanSink(parent: self, observer: observer)
        await sink.run(c.call(), source)
        return sink
    }
}
