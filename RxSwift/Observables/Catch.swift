//
//  Catch.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 4/19/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

public extension ObservableType {
    /**
     Continues an observable sequence that is terminated by an error with the observable sequence produced by the handler.

     - seealso: [catch operator on reactivex.io](http://reactivex.io/documentation/operators/catch.html)

     - parameter handler: Error handler function, producing another observable sequence.
     - returns: An observable sequence containing the source sequence's elements, followed by the elements produced by the handler's resulting observable sequence in case an error occurred.
     */
    func `catch`(_ handler: @escaping (Swift.Error) async throws -> Observable<Element>) async
        -> Observable<Element> {
        await Catch(source: asObservable(), handler: handler)
    }

    /**
     Continues an observable sequence that is terminated by an error with the observable sequence produced by the handler.

     - seealso: [catch operator on reactivex.io](http://reactivex.io/documentation/operators/catch.html)

     - parameter handler: Error handler function, producing another observable sequence.
     - returns: An observable sequence containing the source sequence's elements, followed by the elements produced by the handler's resulting observable sequence in case an error occurred.
     */
    @available(*, deprecated, renamed: "catch(_:)")
    func catchError(_ handler: @escaping (Swift.Error) throws -> Observable<Element>) async
        -> Observable<Element> {
        await self.catch(handler)
    }

    /**
     Continues an observable sequence that is terminated by an error with a single element.

     - seealso: [catch operator on reactivex.io](http://reactivex.io/documentation/operators/catch.html)

     - parameter element: Last element in an observable sequence in case error occurs.
     - returns: An observable sequence containing the source sequence's elements, followed by the `element` in case an error occurred.
     */
    func catchAndReturn(_ element: Element) async
        -> Observable<Element> {
        await Catch(source: asObservable(), handler: { _ in await Observable.just(element) })
    }

    /**
     Continues an observable sequence that is terminated by an error with a single element.

     - seealso: [catch operator on reactivex.io](http://reactivex.io/documentation/operators/catch.html)

     - parameter element: Last element in an observable sequence in case error occurs.
     - returns: An observable sequence containing the source sequence's elements, followed by the `element` in case an error occurred.
     */
    @available(*, deprecated, renamed: "catchAndReturn(_:)")
    func catchErrorJustReturn(_ element: Element) async
        -> Observable<Element> {
        await catchAndReturn(element)
    }
}

public extension ObservableType {
    /**
     Continues an observable sequence that is terminated by an error with the next observable sequence.

     - seealso: [catch operator on reactivex.io](http://reactivex.io/documentation/operators/catch.html)

     - returns: An observable sequence containing elements from consecutive source sequences until a source sequence terminates successfully.
     */
    @available(*, deprecated, renamed: "catch(onSuccess:onFailure:onDisposed:)")
    static func catchError<Sequence: Swift.Sequence>(_ sequence: Sequence) async -> Observable<Element>
        where Sequence.Element == Observable<Element> {
        await self.catch(sequence: sequence)
    }

    /**
     Continues an observable sequence that is terminated by an error with the next observable sequence.

     - seealso: [catch operator on reactivex.io](http://reactivex.io/documentation/operators/catch.html)

     - returns: An observable sequence containing elements from consecutive source sequences until a source sequence terminates successfully.
     */
    static func `catch`<Sequence: Swift.Sequence>(sequence: Sequence) async -> Observable<Element>
        where Sequence.Element == Observable<Element> {
        await CatchSequence(sources: sequence)
    }
}

public extension ObservableType {
    /**
     Repeats the source observable sequence until it successfully terminates.

     **This could potentially create an infinite sequence.**

     - seealso: [retry operator on reactivex.io](http://reactivex.io/documentation/operators/retry.html)

     - returns: Observable sequence to repeat until it successfully terminates.
     */
    func retry() async -> Observable<Element> {
        await CatchSequence(sources: InfiniteSequence(repeatedValue: asObservable()))
    }

    /**
     Repeats the source observable sequence the specified number of times in case of an error or until it successfully terminates.

     If you encounter an error and want it to retry once, then you must use `retry(2)`

     - seealso: [retry operator on reactivex.io](http://reactivex.io/documentation/operators/retry.html)

     - parameter maxAttemptCount: Maximum number of times to repeat the sequence.
     - returns: An observable sequence producing the elements of the given sequence repeatedly until it terminates successfully.
     */
    func retry(_ maxAttemptCount: Int) async
        -> Observable<Element> {
        await CatchSequence(sources: Swift.repeatElement(asObservable(), count: maxAttemptCount))
    }
}

// catch with callback

private final class CatchSinkProxy<Observer: ObserverType>: ObserverType {
    typealias Element = Observer.Element
    typealias Parent = CatchSink<Observer>

    private let parent: Parent

    init(parent: Parent) {
        self.parent = parent
    }

    func on(_ event: Event<Element>, _ c: C) async {
        await parent.forwardOn(event, c.call())

        switch event {
        case .next:
            break
        case .error, .completed:
            await parent.dispose()
        }
    }
}

private final actor CatchSink<Observer: ObserverType>: Sink, ObserverType {
    typealias Element = Observer.Element
    typealias Parent = Catch<Element>

    let baseSink: BaseSink<CatchSink<Observer>>
    private let parent: Parent
    private let subscription: SerialDisposable

    init(parent: Parent, observer: Observer, cancel: Cancelable) async {
        self.parent = parent
        subscription = await SerialDisposable()
        baseSink = await BaseSink(observer: observer, cancel: cancel)
    }

    func run(_ c: C) async -> Disposable {
        let d1 = await SingleAssignmentDisposable()
        await subscription.setDisposable(d1)
        await d1.setDisposable(parent.source.subscribe(c.call(), self))

        return subscription
    }

    func on(_ event: Event<Element>, _ c: C) async {
        switch event {
        case .next:
            await forwardOn(event, c.call())
        case .completed:
            await forwardOn(event, c.call())
            await dispose()
        case .error(let error):
            do {
                let catchSequence = try await parent.handler(error)

                let observer = CatchSinkProxy(parent: self)

                await subscription.setDisposable(catchSequence.subscribe(c.call(), observer))
            } catch let e {
                await self.forwardOn(.error(e), c.call())
                await self.dispose()
            }
        }
    }
}

private final class Catch<Element>: Producer<Element> {
    typealias Handler = (Swift.Error) async throws -> Observable<Element>

    fileprivate let source: Observable<Element>
    fileprivate let handler: Handler

    init(source: Observable<Element>, handler: @escaping Handler) async {
        self.source = source
        self.handler = handler
        await super.init()
    }

    override func run<Observer: ObserverType>(
        _ c: C,
        _ observer: Observer,
        cancel: Cancelable
    )
        async -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        let sink = await CatchSink(parent: self, observer: observer, cancel: cancel)
        let subscription = await sink.run(c.call())
        return (sink: sink, subscription: subscription)
    }
}

// catch enumerable

private final actor CatchSequenceSink<
    Sequence: Swift.Sequence,
    Observer: ObserverType
>: Sink, ObserverType, InvocableWithValueType
    where Sequence.Element: ObservableConvertibleType, Sequence.Element.Element == Observer.Element {
    typealias Observer = Observer

    typealias TheBaseSink = TailRecursiveSink<Sequence, CatchSequenceSink<Sequence, Observer>>

    typealias Element = Observer.Element
    typealias Parent = CatchSequence<Sequence>
    typealias Value = TailRecursiveSinkCommand

    private var lastError: Swift.Error?

    let baseSink: TailRecursiveSink<Sequence, CatchSequenceSink<Sequence, Observer>>

    init(observer: Observer, cancel: Cancelable) async {
        baseSink = await TailRecursiveSink<Sequence, CatchSequenceSink<Sequence, Observer>>(
            observer: observer,
            cancel: cancel
        )
    }

    func run(
        _ c: C,
        _ sources: TailRecursiveSink<Sequence, CatchSequenceSink<Sequence, Observer>>.SequenceGenerator
    )
        async -> Disposable {
        baseSink.generators.append(sources)

        await scheduleMoveNext(c.call())

        return baseSink.subscription
    }

    func scheduleMoveNext(_ c: C) async {
        let iterator = baseSink.schedule(InvocableScheduledItem<CatchSequenceSink<Sequence, Observer>>(
            invocable: self,
            state: .moveNext
        ))
        for item in iterator {
            await item.invoke(c.call())
        }
    }
    
    func scheduleDispose(_ c: C) async {
        let iterator = baseSink.schedule(InvocableScheduledItem<CatchSequenceSink<Sequence, Observer>>(
            invocable: self,
            state: .dispose
        ))
        for item in iterator {
            await item.invoke(c.call())
        }
    }

    func invoke(_ c: C, _ value: TailRecursiveSinkCommand) async {
        switch value {
        case .dispose:
            disposeCommand()
        case .moveNext:
            var next: Observable<Element>?
            repeat {
                for nextCandidate in baseSink.moveNextCandidatesForExtraction() {
                    switch nextCandidate {
                    case .noMoreCandidates:
                        await done(c.call())
                    case .nextCandidate(let nextCandidate):
                        let nextGenerator = extract(nextCandidate)

                        if let existingNext = baseSink.moveNextAppendGeneratorOrUseCandidate(
                            nextGenerator,
                            nextCandidate
                        ) {
                            next = existingNext
                        }
                    }
                }
            } while next == nil

            guard let existingNext = next else {
                await done(c.call())
                return
            }

            let disposable = await SingleAssignmentDisposable()
            await baseSink.subscription.setDisposable(disposable)
            await disposable.setDisposable(subscribeToNext(c.call(), existingNext))
        }
    }

    func disposeCommand() {
        baseSink.disposed = true
        baseSink.generators.removeAll(keepingCapacity: false)
    }

    func on(_ event: Event<Element>, _ c: C) async {
        switch event {
        case .next:
            await baseSink.forwardOn(event, c.call())
        case .error(let error):
            lastError = error
            await scheduleMoveNext(c.call())
        case .completed:
            await baseSink.forwardOn(event, c.call())
            await dispose()
        }
    }

    func subscribeToNext(_ c: C, _ source: Observable<Element>) async -> Disposable {
        await source.subscribe(c.call(), self)
    }

    func done(_ c: C) async {
        if let lastError {
            await forwardOn(.error(lastError), c.call())
        } else {
            await forwardOn(.completed, c.call())
        }

        await dispose()
    }

    /* override */ func dispose() async {
        baseSink.setDisposedSyncPre()
        await baseSink.dispose()
        baseSink.setDisposedSyncPost()

        await scheduleDispose(C())
    }

    private func extract(_ observable: Observable<Element>)
        -> TailRecursiveSink<Sequence, CatchSequenceSink<Sequence, Observer>>.SequenceGenerator? {
        if let onError = observable as? CatchSequence<Sequence> {
            return (onError.sources.makeIterator(), nil)
        } else {
            return nil
        }
    }
}

private final class CatchSequence<Sequence: Swift.Sequence>: Producer<Sequence.Element.Element>
    where Sequence.Element: ObservableConvertibleType {
    typealias Element = Sequence.Element.Element

    let sources: Sequence

    init(sources: Sequence) async {
        self.sources = sources
        await super.init()
    }

    override func run<Observer: ObserverType>(
        _ c: C,
        _ observer: Observer,
        cancel: Cancelable
    )
        async -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        let sink = await CatchSequenceSink<Sequence, Observer>(observer: observer, cancel: cancel)
        let subscription = await sink.run(c.call(), (sources.makeIterator(), nil))
        return (sink: sink, subscription: subscription)
    }
}
