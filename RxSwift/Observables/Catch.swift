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
    func `catch`(_ handler: @escaping (Swift.Error) async throws -> Observable<Element>)
        -> Observable<Element> {
        Catch(source: asObservable(), handler: handler)
    }

    /**
     Continues an observable sequence that is terminated by an error with the observable sequence produced by the handler.

     - seealso: [catch operator on reactivex.io](http://reactivex.io/documentation/operators/catch.html)

     - parameter handler: Error handler function, producing another observable sequence.
     - returns: An observable sequence containing the source sequence's elements, followed by the elements produced by the handler's resulting observable sequence in case an error occurred.
     */
    @available(*, deprecated, renamed: "catch(_:)")
    func catchError(_ handler: @escaping (Swift.Error) throws -> Observable<Element>)
        -> Observable<Element> {
        self.catch(handler)
    }

    /**
     Continues an observable sequence that is terminated by an error with a single element.

     - seealso: [catch operator on reactivex.io](http://reactivex.io/documentation/operators/catch.html)

     - parameter element: Last element in an observable sequence in case error occurs.
     - returns: An observable sequence containing the source sequence's elements, followed by the `element` in case an error occurred.
     */
    func catchAndReturn(_ element: Element)
        -> Observable<Element> {
        Catch(source: asObservable(), handler: { _ in Observable.just(element) })
    }

    /**
     Continues an observable sequence that is terminated by an error with a single element.

     - seealso: [catch operator on reactivex.io](http://reactivex.io/documentation/operators/catch.html)

     - parameter element: Last element in an observable sequence in case error occurs.
     - returns: An observable sequence containing the source sequence's elements, followed by the `element` in case an error occurred.
     */
    @available(*, deprecated, renamed: "catchAndReturn(_:)")
    func catchErrorJustReturn(_ element: Element)
        -> Observable<Element> {
        catchAndReturn(element)
    }
}

public extension ObservableType {
    /**
     Continues an observable sequence that is terminated by an error with the next observable sequence.

     - seealso: [catch operator on reactivex.io](http://reactivex.io/documentation/operators/catch.html)

     - returns: An observable sequence containing elements from consecutive source sequences until a source sequence
     terminates successfully.
     */
    @available(*, deprecated, renamed: "catch(onSuccess:onFailure:onDisposed:)")
    static func catchError<Sequence: Swift.Sequence>(_ sequence: Sequence) -> Observable<Element>
        where Sequence.Element == Observable<Element> {
        self.catch(sequence: sequence)
    }

    /**
     Continues an observable sequence that is terminated by an error with the next observable sequence.

     - seealso: [catch operator on reactivex.io](http://reactivex.io/documentation/operators/catch.html)

     - returns: An observable sequence containing elements from consecutive source sequences until a source sequence
     terminates successfully.
     */
    static func `catch`<Sequence: Swift.Sequence>(sequence: Sequence) -> Observable<Element>
        where Sequence.Element == Observable<Element> {
        CatchSequence(sources: sequence)
    }
}

public extension ObservableType {
    /**
     Repeats the source observable sequence until it successfully terminates.

     **This could potentially create an infinite sequence.**

     - seealso: [retry operator on reactivex.io](http://reactivex.io/documentation/operators/retry.html)

     - returns: Observable sequence to repeat until it successfully terminates.
     */
    func retry() -> Observable<Element> {
        CatchSequence(sources: InfiniteSequence(repeatedValue: self))
    }

    /**
     Repeats the source observable sequence the specified number of times in case of an error or until it successfully
     terminates.

     If you encounter an error and want it to retry once, then you must use `retry(2)`

     - seealso: [retry operator on reactivex.io](http://reactivex.io/documentation/operators/retry.html)

     - parameter maxAttemptCount: Maximum number of times to repeat the sequence.
     - returns: An observable sequence producing the elements of the given sequence repeatedly until it terminates
     successfully.
     */
    func retry(_ maxAttemptCount: Int)
        -> Observable<Element> {
        CatchSequence(sources: Swift.repeatElement(self, count: maxAttemptCount))
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

    let baseSink: BaseSink<Observer>
    private let parent: Parent
    private let subscription: SerialDisposable

    init(parent: Parent, observer: Observer) {
        self.parent = parent
        subscription = SerialDisposable()
        baseSink = BaseSink(observer: observer)
    }

    func run(_ c: C) async {
        let d1 = SingleAssignmentDisposable()
        await subscription.setDisposable(d1)
        await d1.setDisposable(parent.source.subscribe(c.call(), self))
    }

    func dispose() async {
        if setDisposed() {
            await subscription.dispose()
        }
    }

    func on(_ event: Event<Element>, _ c: C) async {
        if baseSink.disposed {
            return
        }
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

private final class Catch<Element: Sendable>: Producer<Element> {
    typealias Handler = (Swift.Error) async throws -> Observable<Element>

    fileprivate let source: Observable<Element>
    fileprivate let handler: Handler

    init(source: Observable<Element>, handler: @escaping Handler) {
        self.source = source
        self.handler = handler
        super.init()
    }

    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> AsynchronousDisposable
        where Observer.Element == Element {
        let sink = CatchSink(parent: self, observer: observer)
        await sink.run(c.call())
        return sink
    }
}

//// catch enumerable
//
//private final actor CatchSequenceSink<Sequence: Swift.Sequence, Observer: ObserverType>: ObserverType, TailRecursiveSinkUser
//    where Sequence.Element: ObservableConvertibleType, Sequence.Element.Element == Observer.Element {
//    typealias Element = Observer.Element
//    typealias Parent = CatchSequence<Sequence>
//
//    private var lastError: Swift.Error?
//    var tailRecursiveSink: TailRecursiveSink<CatchSequenceSink<Sequence, Observer>, Observer>!
//
//    init(observer: Observer) async {
//        tailRecursiveSink = TailRecursiveSink(user: self, observer: observer)
//    }
//
//    func on(_ event: Event<Element>, _ c: C) async {
//        switch event {
//        case .next:
//            tailRecursiveSink.forwardOn(event, c.call())
//        case .error(let error):
//            lastError = error
//            await schedule(c.call(), .moveNext)
//        case .completed:
//            await tailRecursiveSink.forwardOn(event, c.call())
//            await dispose()
//        }
//    }
//
//    override func subscribeToNext(_ c: C, _ source: Observable<Element>) async -> Disposable {
//        await source.subscribe(c.call(), self)
//    }
//
//    override func done(_ c: C) async {
//        if let lastError {
//            await forwardOn(.error(lastError), c.call())
//        } else {
//            await forwardOn(.completed, c.call())
//        }
//
//        await dispose()
//    }
//
//    override func extract(_ c: C, _ observable: Observable<Element>) -> SequenceGenerator? {
//        if let onError = observable as? CatchSequence<Sequence> {
//            return (onError.sources.makeIterator(), nil)
//        } else {
//            return nil
//        }
//    }
//}
//
//private final class CatchSequence<Sequence: Swift.Sequence>: Producer<Sequence.Element.Element> where
//    Sequence.Element: ObservableConvertibleType {
//    typealias Element = Sequence.Element.Element
//
//    let sources: Sequence
//
//    init(sources: Sequence) {
//        self.sources = sources
//        super.init()
//    }
//
//    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> AsynchronousDisposable where
//        Observer.Element == Element {
//        let sink = CatchSequenceSink<Sequence, Observer>(observer: observer)
//        sink.run(c.call(), (sources.makeIterator(), nil))
//        return sink
//    }
//}
