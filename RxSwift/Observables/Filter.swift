////
////  Filter.swift
////  RxSwift
////
////  Created by Krunoslav Zaher on 2/17/15.
////  Copyright © 2015 Krunoslav Zaher. All rights reserved.
////
//
//public extension ObservableType {
//    /**
//     Filters the elements of an observable sequence based on a predicate.
//
//     - seealso: [filter operator on reactivex.io](http://reactivex.io/documentation/operators/filter.html)
//
//     - parameter predicate: A function to test each source element for a condition.
//     - returns: An observable sequence that contains elements from the input sequence that satisfy the condition.
//     */
//    func filter(_ predicate: @escaping (Element) async throws -> Bool) async
//        -> Observable<Element>
//    {
//        await Filter(source: self.asObservable(), predicate: predicate)
//    }
//}
//
//public extension ObservableType {
//    /**
//     Skips elements and completes (or errors) when the observable sequence completes (or errors). Equivalent to filter that always returns false.
//
//     - seealso: [ignoreElements operator on reactivex.io](http://reactivex.io/documentation/operators/ignoreelements.html)
//
//     - returns: An observable sequence that skips all elements of the source sequence.
//     */
//    func ignoreElements() async
//        -> Observable<Never>
//    {
//        fatalError()
////        await self.flatMap { _ in await Observable<Never>.empty() }
//    }
//}
//
//private final actor FilterSink<Observer: ObserverType>: Sink, ObserverType {
//    typealias Predicate = (Element) async throws -> Bool
//    typealias Element = Observer.Element
//
//    private let predicate: Predicate
//    let baseSink: BaseSink<Observer>
//
//    init(predicate: @escaping Predicate, observer: Observer) async {
//        self.predicate = predicate
//        
//        self.baseSink = BaseSink(observer: observer)
//    }
//
//    func on(_ event: Event<Element>, _ c: C) async {
//        switch event {
//        case .next(let value):
//            do {
//                let satisfies = try await self.predicate(value)
//                if satisfies {
//                    await self.forwardOn(.next(value), c.call())
//                }
//            }
//            catch let e {
//                await self.forwardOn(.error(e), c.call())
//                await self.dispose()
//            }
//        case .completed, .error:
//            await self.forwardOn(event, c.call())
//            await self.dispose()
//        }
//    }
//}
//
//private final class Filter<Element>: Producer<Element> {
//    typealias Predicate = (Element) async throws -> Bool
//
//    private let source: Observable<Element>
//    private let predicate: Predicate
//
//    init(source: Observable<Element>, predicate: @escaping Predicate) async {
//        self.source = source
//        self.predicate = predicate
//        await super.init()
//    }
//
//    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> AsynchronousDisposable where Observer.Element == Element {
//        let sink = await FilterSink(predicate: self.predicate, observer: observer)
//        let subscription = await self.source.subscribe(c.call(), sink)
//        return sink
//    }
//}
