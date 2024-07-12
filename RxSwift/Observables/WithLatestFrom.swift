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
    func withLatestFrom<Source: ObservableConvertibleType, ResultType>(_ second: Source, resultSelector: @escaping (Element, Source.Element) throws -> ResultType) async -> Observable<ResultType> {
        await WithLatestFrom(first: self.asObservable(), second: second.asObservable(), resultSelector: resultSelector)
    }

    /**
     Merges two observable sequences into one observable sequence by using latest element from the second sequence every time when `self` emits an element.

     - seealso: [combineLatest operator on reactivex.io](http://reactivex.io/documentation/operators/combinelatest.html)
     - note: Elements emitted by self before the second source has emitted any values will be omitted.

     - parameter second: Second observable source.
     - returns: An observable sequence containing the result of combining each element of the self  with the latest element from the second source, if any, using the specified result selector function.
     */
    func withLatestFrom<Source: ObservableConvertibleType>(_ second: Source) async -> Observable<Source.Element> {
        await WithLatestFrom(first: self.asObservable(), second: second.asObservable(), resultSelector: { $1 })
    }
}

private final class WithLatestFromSink<FirstType, SecondType, Observer: ObserverType>:
    Sink<Observer>,
    ObserverType,
    LockOwnerType,
    SynchronizedOnType
{
    typealias ResultType = Observer.Element
    typealias Parent = WithLatestFrom<FirstType, SecondType, ResultType>
    typealias Element = FirstType

    private let parent: Parent

    fileprivate let lock: RecursiveLock
    fileprivate var latest: SecondType?

    init(parent: Parent, observer: Observer, cancel: Cancelable) async {
        self.parent = parent
        self.lock = await RecursiveLock()

        await super.init(observer: observer, cancel: cancel)
    }

    func run() async -> Disposable {
        let sndSubscription = await SingleAssignmentDisposable()
        let sndO = WithLatestFromSecond(parent: self, disposable: sndSubscription)

        await sndSubscription.setDisposable(self.parent.second.subscribe(sndO))
        let fstSubscription = await self.parent.first.subscribe(self)

        return await Disposables.create(fstSubscription, sndSubscription)
    }

    func on(_ event: Event<Element>) async {
        await self.synchronizedOn(event)
    }

    func synchronized_on(_ event: Event<Element>) async {
        switch event {
        case let .next(value):
            guard let latest = self.latest else { return }
            do {
                let res = try self.parent.resultSelector(value, latest)

                await self.forwardOn(.next(res))
            } catch let e {
                await self.forwardOn(.error(e))
                await self.dispose()
            }
        case .completed:
            await self.forwardOn(.completed)
            await self.dispose()
        case let .error(error):
            await self.forwardOn(.error(error))
            await self.dispose()
        }
    }
}

private final class WithLatestFromSecond<FirstType, SecondType, Observer: ObserverType>:
    ObserverType,
    LockOwnerType,
    SynchronizedOnType
{
    typealias ResultType = Observer.Element
    typealias Parent = WithLatestFromSink<FirstType, SecondType, Observer>
    typealias Element = SecondType

    private let parent: Parent
    private let disposable: Disposable

    var lock: RecursiveLock {
        self.parent.lock
    }

    init(parent: Parent, disposable: Disposable) {
        self.parent = parent
        self.disposable = disposable
    }

    func on(_ event: Event<Element>) async {
        await self.synchronizedOn(event)
    }

    func synchronized_on(_ event: Event<Element>) async {
        switch event {
        case let .next(value):
            self.parent.latest = value
        case .completed:
            await self.disposable.dispose()
        case let .error(error):
            await self.parent.forwardOn(.error(error))
            await self.parent.dispose()
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

    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) async -> (sink: Disposable, subscription: Disposable) where Observer.Element == ResultType {
        let sink = await WithLatestFromSink(parent: self, observer: observer, cancel: cancel)
        let subscription = await sink.run()
        return (sink: sink, subscription: subscription)
    }
}
