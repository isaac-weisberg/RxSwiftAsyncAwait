//
//  SingleAsync.swift
//  RxSwift
//
//  Created by Junior B. on 09/11/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

public extension ObservableType {
    /**
     The single operator is similar to first, but throws a `RxError.noElements` or `RxError.moreThanOneElement`
     if the source Observable does not emit exactly one element before successfully completing.

     - seealso: [single operator on reactivex.io](http://reactivex.io/documentation/operators/first.html)

     - returns: An observable sequence that emits a single element or throws an exception if more (or none) of them are emitted.
     */
    func single()
        -> Observable<Element>
    {
        SingleAsync(source: self.asObservable())
    }

    /**
     The single operator is similar to first, but throws a `RxError.NoElements` or `RxError.MoreThanOneElement`
     if the source Observable does not emit exactly one element before successfully completing.

     - seealso: [single operator on reactivex.io](http://reactivex.io/documentation/operators/first.html)

     - parameter predicate: A function to test each source element for a condition.
     - returns: An observable sequence that emits a single element or throws an exception if more (or none) of them are emitted.
     */
    func single(_ predicate: @escaping (Element) throws -> Bool)
        -> Observable<Element>
    {
        SingleAsync(source: self.asObservable(), predicate: predicate)
    }
}

private final class SingleAsyncSink<Observer: ObserverType>: Sink<Observer>, ObserverType {
    typealias Element = Observer.Element
    typealias Parent = SingleAsync<Element>

    private let parent: Parent
    private var seenValue: Bool = false

    init(parent: Parent, observer: Observer, cancel: Cancelable) async {
        self.parent = parent
        await super.init(observer: observer, cancel: cancel)
    }

    func on(_ event: Event<Element>) async {
        switch event {
        case .next(let value):
            do {
                let forward = try self.parent.predicate?(value) ?? true
                if !forward {
                    return
                }
            } catch {
                await self.forwardOn(.error(error as Swift.Error))
                await self.dispose()
                return
            }

            if self.seenValue {
                await self.forwardOn(.error(RxError.moreThanOneElement))
                await self.dispose()
                return
            }

            self.seenValue = true
            await self.forwardOn(.next(value))
        case .error:
            await self.forwardOn(event)
            await self.dispose()
        case .completed:
            if self.seenValue {
                await self.forwardOn(.completed)
            } else {
                await self.forwardOn(.error(RxError.noElements))
            }
            await self.dispose()
        }
    }
}

final class SingleAsync<Element>: Producer<Element> {
    typealias Predicate = (Element) throws -> Bool

    private let source: Observable<Element>
    fileprivate let predicate: Predicate?

    init(source: Observable<Element>, predicate: Predicate? = nil) {
        self.source = source
        self.predicate = predicate
    }

    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) async -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        let sink = await SingleAsyncSink(parent: self, observer: observer, cancel: cancel)
        let subscription = await self.source.subscribe(sink)
        return (sink: sink, subscription: subscription)
    }
}
