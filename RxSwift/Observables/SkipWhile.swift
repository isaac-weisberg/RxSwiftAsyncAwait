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
    func skip(while predicate: @escaping (Element) throws -> Bool) -> Observable<Element> {
        SkipWhile(source: asObservable(), predicate: predicate)
    }

    /**
     Bypasses elements in an observable sequence as long as a specified condition is true and then returns the remaining elements.

     - seealso: [skipWhile operator on reactivex.io](http://reactivex.io/documentation/operators/skipwhile.html)

     - parameter predicate: A function to test each element for a condition.
     - returns: An observable sequence that contains the elements from the input sequence starting at the first element in the linear series that does not pass the test specified by predicate.
     */
    @available(*, deprecated, renamed: "skip(while:)")
    func skipWhile(_ predicate: @escaping (Element) throws -> Bool) -> Observable<Element> {
        SkipWhile(source: asObservable(), predicate: predicate)
    }
}

private final actor SkipWhileSink<Observer: ObserverType>: SinkOverSingleSubscription, ObserverType {
    typealias Element = Observer.Element
    typealias Parent = SkipWhile<Element>

    private let parent: Parent
    private var running = false
    let baseSink: BaseSinkOverSingleSubscription<Observer>

    init(parent: Parent, observer: Observer) {
        self.parent = parent
        baseSink = BaseSinkOverSingleSubscription(observer: observer)
    }

    func on(_ event: Event<Element>, _ c: C) async {
        if baseSink.disposed {
            return
        }
        switch event {
        case .next(let value):
            if !running {
                do {
                    running = try !parent.predicate(value)
                } catch let e {
                    await self.forwardOn(.error(e), c.call())
                    await self.dispose()
                    return
                }
            }

            if running {
                await forwardOn(.next(value), c.call())
            }
        case .error, .completed:
            await forwardOn(event, c.call())
            await dispose()
        }
    }

    func dispose() async {
        await baseSink.setDisposed()?.dispose()
    }
}

private final class SkipWhile<Element: Sendable>: Producer<Element> {
    typealias Predicate = (Element) throws -> Bool

    private let source: Observable<Element>
    fileprivate let predicate: Predicate

    init(source: Observable<Element>, predicate: @escaping Predicate) {
        self.source = source
        self.predicate = predicate
        super.init()
    }

    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> AsynchronousDisposable
        where Observer.Element == Element {
        let sink = SkipWhileSink(parent: self, observer: observer)
        await sink.run(c.call(), source)
        return sink
    }
}
