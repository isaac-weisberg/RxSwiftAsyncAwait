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

private final actor WithLatestFromSink<FirstType, SecondType, Observer: ObserverType>:
    Sink,
    ObserverType,
    SynchronizedOnType {
    typealias ResultType = Observer.Element
    typealias Parent = WithLatestFrom<FirstType, SecondType, ResultType>
    typealias Element = FirstType

    private let parent: Parent

    fileprivate var latest: SecondType?
    func setLatest(_ newValue: SecondType?) {
        latest = newValue
    }
    let baseSink: BaseSink<Observer>

    init(parent: Parent, observer: Observer) async {
        self.parent = parent

        self.baseSink = BaseSink(observer: observer)
    }

    func run(_ c: C) async -> Disposable {
        let sndSubscription = await SingleAssignmentDisposable()
        let sndO = WithLatestFromSecond(parent: self, disposable: sndSubscription)

        await sndSubscription.setDisposable(parent.second.subscribe(c.call(), sndO))
        let fstSubscription = await parent.first.subscribe(c.call(), self)

        return await Disposables.create(fstSubscription, sndSubscription)
    }

    func on(_ event: Event<Element>, _ c: C) async {
        await synchronizedOn(event, c.call())
    }

    func synchronized_on(_ event: Event<Element>, _ c: C) async {
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
}

private final class WithLatestFromSecond<FirstType, SecondType, Observer: ObserverType>:
    ObserverType,
    SynchronizedOnType {
    typealias ResultType = Observer.Element
    typealias Parent = WithLatestFromSink<FirstType, SecondType, Observer>
    typealias Element = SecondType

    private let parent: Parent
    private let disposable: Disposable

    init(parent: Parent, disposable: Disposable) {
        self.parent = parent
        self.disposable = disposable
    }

    func on(_ event: Event<Element>, _ c: C) async {
        await synchronizedOn(event, c.call())
    }

    func synchronized_on(_ event: Event<Element>, _ c: C) async {
        switch event {
        case .next(let value):
            await parent.setLatest(value)
        case .completed:
            await disposable.dispose()
        case .error(let error):
            await parent.forwardOn(.error(error), c.call())
            await parent.dispose()
        }
    }
}

private final class WithLatestFrom<FirstType, SecondType, ResultType>: Producer<ResultType> {
    typealias ResultSelector = (FirstType, SecondType) throws -> ResultType

    fileprivate let first: Observable<FirstType>
    fileprivate let second: Observable<SecondType>
    fileprivate let resultSelector: ResultSelector

    init(first: Observable<FirstType>, second: Observable<SecondType>, resultSelector: @escaping ResultSelector) async {
        self.first = first
        self.second = second
        self.resultSelector = resultSelector
        await super.init()
    }

    override func run<Observer: ObserverType>(
        _ c: C,
        _ observer: Observer
    )
        async -> SynchronizedDisposable where Observer.Element == ResultType {
        let sink = await WithLatestFromSink(parent: self, observer: observer)
        let subscription = await sink.run(c.call())
        return sink
    }
}
