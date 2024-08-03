//
//  SkipWhile.swift
//  RxSwift
//
//  Created by Yury Korolev on 10/9/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

public extension ObservableType {
    /**
     Bypasses elements in an observable sequence as long as a specified condition is true and then returns the remaining elements.

     - seealso: [skipWhile operator on reactivex.io](http://reactivex.io/documentation/operators/skipwhile.html)

     - parameter predicate: A function to test each element for a condition.
     - returns: An observable sequence that contains the elements from the input sequence starting at the first element in the linear series that does not pass the test specified by predicate.
     */
    func skip(while predicate: @escaping (Element) throws -> Bool) async -> Observable<Element> {
        await SkipWhile(source: self.asObservable(), predicate: predicate)
    }

    /**
     Bypasses elements in an observable sequence as long as a specified condition is true and then returns the remaining elements.

     - seealso: [skipWhile operator on reactivex.io](http://reactivex.io/documentation/operators/skipwhile.html)

     - parameter predicate: A function to test each element for a condition.
     - returns: An observable sequence that contains the elements from the input sequence starting at the first element in the linear series that does not pass the test specified by predicate.
     */
    @available(*, deprecated, renamed: "skip(while:)")
    func skipWhile(_ predicate: @escaping (Element) throws -> Bool) async -> Observable<Element> {
        await SkipWhile(source: self.asObservable(), predicate: predicate)
    }
}

private final actor SkipWhileSink<Observer: ObserverType>: Sink, ObserverType {
    typealias Element = Observer.Element
    typealias Parent = SkipWhile<Element>

    private let parent: Parent
    private var running = false
    let baseSink: BaseSink<Observer>

    init(parent: Parent, observer: Observer, cancel: SynchronizedCancelable) async {
        self.parent = parent
        baseSink = await BaseSink(observer: observer, cancel: cancel)
    }

    func on(_ event: Event<Element>, _ c: C) async {
        switch event {
        case .next(let value):
            if !self.running {
                do {
                    self.running = try !self.parent.predicate(value)
                } catch let e {
                    await self.forwardOn(.error(e), c.call())
                    await self.dispose()
                    return
                }
            }

            if self.running {
                await self.forwardOn(.next(value), c.call())
            }
        case .error, .completed:
            await self.forwardOn(event, c.call())
            await self.dispose()
        }
    }
}

private final class SkipWhile<Element>: Producer<Element> {
    typealias Predicate = (Element) throws -> Bool

    private let source: Observable<Element>
    fileprivate let predicate: Predicate

    init(source: Observable<Element>, predicate: @escaping Predicate) async {
        self.source = source
        self.predicate = predicate
        await super.init()
    }

    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer, cancel: SynchronizedCancelable) async -> (sink: SynchronizedDisposable, subscription: SynchronizedDisposable) where Observer.Element == Element {
        let sink = await SkipWhileSink(parent: self, observer: observer, cancel: cancel)
        let subscription = await self.source.subscribe(c.call(), sink)
        return (sink: sink, subscription: subscription)
    }
}
