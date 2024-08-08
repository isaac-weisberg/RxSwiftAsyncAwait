//
//  WithLatestFrom.swift
//  RxSwift
//
//  Created by Yury Korolev on 10/19/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

public extension ObservableType {
    /**
     Merges two observable sequences into one observable sequence by combining each element from self with the latest element from the second source, if any.

     - seealso: [combineLatest operator on reactivex.io](http://reactivex.io/documentation/operators/combinelatest.html)
     - note: Elements emitted by self before the second source has emitted any values will be omitted.

     - parameter second: Second observable source.
     - parameter resultSelector: Function to invoke for each element from the self combined with the latest element from the second source, if any.
     - returns: An observable sequence containing the result of combining each element of the self  with the latest element from the second source, if any, using the specified result selector function.
     */
    func withLatestFrom<Source: ObservableConvertibleType, ResultType>(
        _ second: Source,
        resultSelector: @escaping (Element, Source.Element) throws -> ResultType
    )
        async -> Observable<ResultType> {
        await WithLatestFrom(first: asObservable(), second: second.asObservable(), resultSelector: resultSelector)
    }

    /**
     Merges two observable sequences into one observable sequence by using latest element from the second sequence every time when `self` emits an element.

     - seealso: [combineLatest operator on reactivex.io](http://reactivex.io/documentation/operators/combinelatest.html)
     - note: Elements emitted by self before the second source has emitted any values will be omitted.

     - parameter second: Second observable source.
     - returns: An observable sequence containing the result of combining each element of the self  with the latest element from the second source, if any, using the specified result selector function.
     */
    func withLatestFrom<Source: ObservableConvertibleType>(_ second: Source) async -> Observable<Source.Element> {
        await WithLatestFrom(first: asObservable(), second: second.asObservable(), resultSelector: { $1 })
    }
}

private final actor WithLatestFromSink<FirstType: Sendable, SecondType: Sendable, Observer: ObserverType>:
    Sink,
    ObserverType {
    typealias ResultType = Observer.Element
    typealias Parent = WithLatestFrom<FirstType, SecondType, ResultType>
    typealias Element = FirstType

    private let parent: Parent

    private var latest: SecondType?
    private var firstSubscription: Disposable?
    private var secondSubscription: Disposable?

    let baseSink: BaseSink<Observer>

    init(parent: Parent, observer: Observer) {
        self.parent = parent

        baseSink = BaseSink(observer: observer)
    }

    func run(_ c: C) async {
        secondSubscription = await parent.second.subscribe(
            c.call(),
            AnyAsyncObserver(eventHandler: { [weak self] event, c in
                guard let self else { return }

                await onSecondEvent(event, c.call())
            })
        )

        firstSubscription = await parent.first.subscribe(c.call(), self)
    }

    func onSecondEvent(_ event: Event<SecondType>, _ c: C) async {
        switch event {
        case .next(let element):
            latest = element
        case .error(let error):
            await on(.error(error), c.call())
        case .completed:
            break // The sources usually dispose themselves...
        }
    }

    func on(_ event: Event<Element>, _ c: C) async {
        switch event {
        case .next(let value):
            guard let latest else { return }
            do {
                let res = try parent.resultSelector(value, latest)

                await forwardOn(.next(res), c.call())
            } catch let e {
                await self.forwardOn(.error(e), c.call())
                await self.dispose()
            }
        case .completed:
            await forwardOn(.completed, c.call())
            await dispose()
        case .error(let error):
            await forwardOn(.error(error), c.call())
            await dispose()
        }
    }

    func dispose() async {
        if setDisposed() {
            await firstSubscription?.dispose()
            firstSubscription = nil
            await secondSubscription?.dispose()
            secondSubscription = nil
        }
    }
}

private final class WithLatestFrom<
    FirstType: Sendable,
    SecondType: Sendable,
    ResultType: Sendable
>: Producer<ResultType> {
    typealias ResultSelector = (FirstType, SecondType) throws -> ResultType

    fileprivate let first: Observable<FirstType>
    fileprivate let second: Observable<SecondType>
    fileprivate let resultSelector: ResultSelector

    init(first: Observable<FirstType>, second: Observable<SecondType>, resultSelector: @escaping ResultSelector) {
        self.first = first
        self.second = second
        self.resultSelector = resultSelector
        super.init()
    }

    override func run<Observer: ObserverType>(
        _ c: C,
        _ observer: Observer
    )
        async -> AsynchronousDisposable where Observer.Element == ResultType {
        let sink = WithLatestFromSink(parent: self, observer: observer)
        await sink.run(c.call())
        return sink
    }
}
