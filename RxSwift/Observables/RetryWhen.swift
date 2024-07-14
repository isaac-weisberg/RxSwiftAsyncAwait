//
//  RetryWhen.swift
//  RxSwift
//
//  Created by Junior B. on 06/10/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

public extension ObservableType {
    /**
     Repeats the source observable sequence on error when the notifier emits a next value.
     If the source observable errors and the notifier completes, it will complete the source sequence.

     - seealso: [retry operator on reactivex.io](http://reactivex.io/documentation/operators/retry.html)

     - parameter notificationHandler: A handler that is passed an observable sequence of errors raised by the source observable and returns and observable that either continues, completes or errors. This behavior is then applied to the source observable.
     - returns: An observable sequence producing the elements of the given sequence repeatedly until it terminates successfully or is notified to error or complete.
     */
    func retry<TriggerObservable: ObservableType, Error: Swift.Error>(when notificationHandler: @escaping (Observable<Error>) async -> TriggerObservable) async
        -> Observable<Element>
    {
        await RetryWhenSequence(sources: InfiniteSequence(repeatedValue: self.asObservable()), notificationHandler: notificationHandler)
    }

    /**
     Repeats the source observable sequence on error when the notifier emits a next value.
     If the source observable errors and the notifier completes, it will complete the source sequence.

     - seealso: [retry operator on reactivex.io](http://reactivex.io/documentation/operators/retry.html)

     - parameter notificationHandler: A handler that is passed an observable sequence of errors raised by the source observable and returns and observable that either continues, completes or errors. This behavior is then applied to the source observable.
     - returns: An observable sequence producing the elements of the given sequence repeatedly until it terminates successfully or is notified to error or complete.
     */
    @available(*, deprecated, renamed: "retry(when:)")
    func retryWhen<TriggerObservable: ObservableType, Error: Swift.Error>(_ notificationHandler: @escaping (Observable<Error>) -> TriggerObservable) async
        -> Observable<Element>
    {
        await self.retry(when: notificationHandler)
    }

    /**
     Repeats the source observable sequence on error when the notifier emits a next value.
     If the source observable errors and the notifier completes, it will complete the source sequence.

     - seealso: [retry operator on reactivex.io](http://reactivex.io/documentation/operators/retry.html)

     - parameter notificationHandler: A handler that is passed an observable sequence of errors raised by the source observable and returns and observable that either continues, completes or errors. This behavior is then applied to the source observable.
     - returns: An observable sequence producing the elements of the given sequence repeatedly until it terminates successfully or is notified to error or complete.
     */
    func retry<TriggerObservable: ObservableType>(when notificationHandler: @escaping (Observable<Swift.Error>) async -> TriggerObservable) async
        -> Observable<Element>
    {
        await RetryWhenSequence(sources: InfiniteSequence(repeatedValue: self.asObservable()), notificationHandler: notificationHandler)
    }

    /**
     Repeats the source observable sequence on error when the notifier emits a next value.
     If the source observable errors and the notifier completes, it will complete the source sequence.

     - seealso: [retry operator on reactivex.io](http://reactivex.io/documentation/operators/retry.html)

     - parameter notificationHandler: A handler that is passed an observable sequence of errors raised by the source observable and returns and observable that either continues, completes or errors. This behavior is then applied to the source observable.
     - returns: An observable sequence producing the elements of the given sequence repeatedly until it terminates successfully or is notified to error or complete.
     */
    @available(*, deprecated, renamed: "retry(when:)")
    func retryWhen<TriggerObservable: ObservableType>(_ notificationHandler: @escaping (Observable<Swift.Error>) -> TriggerObservable) async
        -> Observable<Element>
    {
        await RetryWhenSequence(sources: InfiniteSequence(repeatedValue: self.asObservable()), notificationHandler: notificationHandler)
    }
}

private final class RetryTriggerSink<Sequence: Swift.Sequence, Observer: ObserverType, TriggerObservable: ObservableType, Error>:
    ObserverType where Sequence.Element: ObservableType, Sequence.Element.Element == Observer.Element
{
    typealias Element = TriggerObservable.Element

    typealias Parent = RetryWhenSequenceSinkIter<Sequence, Observer, TriggerObservable, Error>

    private let parent: Parent

    init(parent: Parent) {
        self.parent = parent
    }

    func on(_ event: Event<Element>) async {
        switch event {
        case .next:
            self.parent.parent.lastError = nil
            await self.parent.parent.schedule(.moveNext)
        case .error(let e):
            await self.parent.parent.forwardOn(.error(e))
            await self.parent.parent.dispose()
        case .completed:
            await self.parent.parent.forwardOn(.completed)
            await self.parent.parent.dispose()
        }
    }
}

private final class RetryWhenSequenceSinkIter<Sequence: Swift.Sequence, Observer: ObserverType, TriggerObservable: ObservableType, Error>:
    ObserverType,
    Disposable where Sequence.Element: ObservableType, Sequence.Element.Element == Observer.Element
{
    typealias Element = Observer.Element
    typealias Parent = RetryWhenSequenceSink<Sequence, Observer, TriggerObservable, Error>

    fileprivate let parent: Parent
    private let errorHandlerSubscription: SingleAssignmentDisposable
    private let subscription: Disposable

    init(parent: Parent, subscription: Disposable) async {
        self.errorHandlerSubscription = await SingleAssignmentDisposable()
        self.parent = parent
        self.subscription = subscription
    }

    func on(_ event: Event<Element>) async {
        switch event {
        case .next:
            await self.parent.forwardOn(event)
        case .error(let error):
            self.parent.lastError = error

            if let failedWith = error as? Error {
                // dispose current subscription
                await self.subscription.dispose()

                let errorHandlerSubscription = await self.parent.notifier.subscribe(RetryTriggerSink(parent: self))
                await self.errorHandlerSubscription.setDisposable(errorHandlerSubscription)
                await self.parent.errorSubject.on(.next(failedWith))
            }
            else {
                await self.parent.forwardOn(.error(error))
                await self.parent.dispose()
            }
        case .completed:
            await self.parent.forwardOn(event)
            await self.parent.dispose()
        }
    }

    final func dispose() async {
        await self.subscription.dispose()
        await self.errorHandlerSubscription.dispose()
    }
}

private final class RetryWhenSequenceSink<Sequence: Swift.Sequence, Observer: ObserverType, TriggerObservable: ObservableType, Error>:
    TailRecursiveSink<Sequence, Observer> where Sequence.Element: ObservableType, Sequence.Element.Element == Observer.Element
{
    typealias Element = Observer.Element
    typealias Parent = RetryWhenSequence<Sequence, TriggerObservable, Error>

    let lock: RecursiveLock

    private let parent: Parent

    fileprivate var lastError: Swift.Error?
    fileprivate let errorSubject: PublishSubject<Error>
    private let handler: Observable<TriggerObservable.Element>
    fileprivate let notifier: PublishSubject<TriggerObservable.Element>

    init(parent: Parent, observer: Observer, cancel: Cancelable) async {
        self.errorSubject = await PublishSubject<Error>()
        self.notifier = await PublishSubject<TriggerObservable.Element>()
        self.lock = await RecursiveLock()
        self.parent = parent
        self.handler = await parent.notificationHandler(self.errorSubject).asObservable()
        await super.init(observer: observer, cancel: cancel)
    }

    override func done() async {
        if let lastError = self.lastError {
            await self.forwardOn(.error(lastError))
            self.lastError = nil
        }
        else {
            await self.forwardOn(.completed)
        }

        await self.dispose()
    }

    override func extract(_ observable: Observable<Element>) -> SequenceGenerator? {
        // It is important to always return `nil` here because there are side effects in the `run` method
        // that are dependent on particular `retryWhen` operator so single operator stack can't be reused in this
        // case.
        return nil
    }

    override func subscribeToNext(_ source: Observable<Element>) async -> Disposable {
        let subscription = await SingleAssignmentDisposable()
        let iter = await RetryWhenSequenceSinkIter(parent: self, subscription: subscription)
        await subscription.setDisposable(source.subscribe(iter))
        return iter
    }

    override func run(_ sources: SequenceGenerator) async -> Disposable {
        let triggerSubscription = await self.handler.subscribe(self.notifier.asObserver())
        let superSubscription = await super.run(sources)
        return await Disposables.create(superSubscription, triggerSubscription)
    }
}

private final class RetryWhenSequence<Sequence: Swift.Sequence, TriggerObservable: ObservableType, Error>: Producer<Sequence.Element.Element> where Sequence.Element: ObservableType {
    typealias Element = Sequence.Element.Element

    private let sources: Sequence
    fileprivate let notificationHandler: (Observable<Error>) async -> TriggerObservable

    init(sources: Sequence, notificationHandler: @escaping (Observable<Error>) async -> TriggerObservable) async {
        self.sources = sources
        self.notificationHandler = notificationHandler
        await super.init()
    }

    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) async -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        let sink = await RetryWhenSequenceSink<Sequence, Observer, TriggerObservable, Error>(parent: self, observer: observer, cancel: cancel)
        let subscription = await sink.run((self.sources.makeIterator(), nil))
        return (sink: sink, subscription: subscription)
    }
}
