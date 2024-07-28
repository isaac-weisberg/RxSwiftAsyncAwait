//
//  Merge.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 3/28/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

public extension ObservableType {
    /**
     Projects each element of an observable sequence to an observable sequence and merges the resulting observable sequences into one observable sequence.

     - seealso: [flatMap operator on reactivex.io](http://reactivex.io/documentation/operators/flatmap.html)

     - parameter selector: A transform function to apply to each element.
     - returns: An observable sequence whose elements are the result of invoking the one-to-many transform function on each element of the input sequence.
     */
    func flatMap<Source: ObservableConvertibleType>(_ selector: @escaping (Element) async throws -> Source) async
        -> Observable<Source.Element> {
        await FlatMap(source: asObservable(), selector: selector)
    }
}

public extension ObservableType {
    /**
     Projects each element of an observable sequence to an observable sequence and merges the resulting observable sequences into one observable sequence.
     If element is received while there is some projected observable sequence being merged it will simply be ignored.

     - seealso: [flatMapFirst operator on reactivex.io](http://reactivex.io/documentation/operators/flatmap.html)

     - parameter selector: A transform function to apply to element that was observed while no observable is executing in parallel.
     - returns: An observable sequence whose elements are the result of invoking the one-to-many transform function on each element of the input sequence that was received while no other sequence was being calculated.
     */
    func flatMapFirst<Source: ObservableConvertibleType>(_ selector: @escaping (Element) async throws -> Source) async
        -> Observable<Source.Element> {
        await FlatMapFirst(source: asObservable(), selector: selector)
    }
}

public extension ObservableType where Element: ObservableConvertibleType {
    /**
     Merges elements from all observable sequences in the given enumerable sequence into a single observable sequence.

     - seealso: [merge operator on reactivex.io](http://reactivex.io/documentation/operators/merge.html)

     - returns: The observable sequence that merges the elements of the observable sequences.
     */
    func merge() async -> Observable<Element.Element> {
        await Merge(source: asObservable())
    }

    /**
     Merges elements from all inner observable sequences into a single observable sequence, limiting the number of concurrent subscriptions to inner sequences.

     - seealso: [merge operator on reactivex.io](http://reactivex.io/documentation/operators/merge.html)

     - parameter maxConcurrent: Maximum number of inner observable sequences being subscribed to concurrently.
     - returns: The observable sequence that merges the elements of the inner sequences.
     */
    func merge(maxConcurrent: Int) async
        -> Observable<Element.Element> {
        await MergeLimited(source: asObservable(), maxConcurrent: maxConcurrent)
    }
}

public extension ObservableType where Element: ObservableConvertibleType {
    /**
     Concatenates all inner observable sequences, as long as the previous observable sequence terminated successfully.

     - seealso: [concat operator on reactivex.io](http://reactivex.io/documentation/operators/concat.html)

     - returns: An observable sequence that contains the elements of each observed inner sequence, in sequential order.
     */
    func concat() async -> Observable<Element.Element> {
        await merge(maxConcurrent: 1)
    }
}

public extension ObservableType {
    /**
     Merges elements from all observable sequences from collection into a single observable sequence.

     - seealso: [merge operator on reactivex.io](http://reactivex.io/documentation/operators/merge.html)

     - parameter sources: Collection of observable sequences to merge.
     - returns: The observable sequence that merges the elements of the observable sequences.
     */
    static func merge<Collection: Swift.Collection>(_ sources: Collection) async -> Observable<Element>
        where Collection.Element == Observable<Element> {
        await MergeArray(sources: Array(sources))
    }

    /**
     Merges elements from all observable sequences from array into a single observable sequence.

     - seealso: [merge operator on reactivex.io](http://reactivex.io/documentation/operators/merge.html)

     - parameter sources: Array of observable sequences to merge.
     - returns: The observable sequence that merges the elements of the observable sequences.
     */
    static func merge(_ sources: [Observable<Element>]) async -> Observable<Element> {
        await MergeArray(sources: sources)
    }

    /**
     Merges elements from all observable sequences into a single observable sequence.

     - seealso: [merge operator on reactivex.io](http://reactivex.io/documentation/operators/merge.html)

     - parameter sources: Collection of observable sequences to merge.
     - returns: The observable sequence that merges the elements of the observable sequences.
     */
    static func merge(_ sources: Observable<Element>...) async -> Observable<Element> {
        await MergeArray(sources: sources)
    }
}

// MARK: concatMap

public extension ObservableType {
    /**
     Projects each element of an observable sequence to an observable sequence and concatenates the resulting observable sequences into one observable sequence.

     - seealso: [concat operator on reactivex.io](http://reactivex.io/documentation/operators/concat.html)

     - returns: An observable sequence that contains the elements of each observed inner sequence, in sequential order.
     */

    func concatMap<Source: ObservableConvertibleType>(_ selector: @escaping (Element) throws -> Source) async
        -> Observable<Source.Element> {
        await ConcatMap(source: asObservable(), selector: selector)
    }
}

private final class MergeLimitedSinkIter<
    SourceElement,
    SourceSequence: ObservableConvertibleType,
    Observer: ObserverType
>:
    ObserverType,
    LockOwnerType,
    SynchronizedOnType where SourceSequence.Element == Observer.Element {
    typealias Element = Observer.Element
    typealias DisposeKey = CompositeDisposable.DisposeKey
    typealias Parent = MergeLimitedSink<SourceElement, SourceSequence, Observer>

    private let parent: Parent
    private let disposeKey: DisposeKey

    var lock: RecursiveLock {
        parent.lock
    }

    init(parent: Parent, disposeKey: DisposeKey) {
        self.parent = parent
        self.disposeKey = disposeKey
    }

    func on(_ event: Event<Element>, _ c: C) async {
        await synchronizedOn(event, c.call())
    }

    func synchronized_on(_ event: Event<Element>, _ c: C) async {
        switch event {
        case .next:
            await parent.forwardOn(event, c.call())
        case .error:
            await parent.forwardOn(event, c.call())
            await parent.dispose()
        case .completed:
            await parent.group.remove(for: disposeKey)
            if let next = parent.queue.dequeue() {
                await parent.subscribe(next, group: parent.group, c.call())
            } else {
                parent.activeCount -= 1

                if parent.stopped, parent.activeCount == 0 {
                    await parent.forwardOn(.completed, c.call())
                    await parent.dispose()
                }
            }
        }
    }
}

private final class ConcatMapSink<
    SourceElement,
    SourceSequence: ObservableConvertibleType,
    Observer: ObserverType
>: MergeLimitedSink<SourceElement, SourceSequence, Observer> where Observer.Element == SourceSequence.Element {
    typealias Selector = (SourceElement) throws -> SourceSequence

    private let selector: Selector

    init(selector: @escaping Selector, observer: Observer, cancel: Cancelable) async {
        self.selector = selector
        await super.init(maxConcurrent: 1, observer: observer, cancel: cancel)
    }

    override func performMap(_ element: SourceElement) throws -> SourceSequence {
        try selector(element)
    }
}

private final class MergeLimitedBasicSink<
    SourceSequence: ObservableConvertibleType,
    Observer: ObserverType
>: MergeLimitedSink<SourceSequence, SourceSequence, Observer> where Observer.Element == SourceSequence.Element {
    override func performMap(_ element: SourceSequence) throws -> SourceSequence {
        element
    }
}

private class MergeLimitedSink<SourceElement, SourceSequence: ObservableConvertibleType, Observer: ObserverType>:
    Sink,
    ObserverType where Observer.Element == SourceSequence.Element {
    typealias QueueType = Queue<SourceSequence>
    
    typealias Element = SourceElement

    let maxConcurrent: Int

    let lock: RecursiveLock

    // state
    var stopped = false
    var activeCount = 0
    var queue = QueueType(capacity: 2)

    let sourceSubscription: SingleAssignmentDisposable
    let group: CompositeDisposable

    init(maxConcurrent: Int, observer: Observer, cancel: Cancelable) async {
        lock = await RecursiveLock()
        sourceSubscription = await SingleAssignmentDisposable()
        group = await CompositeDisposable()
        self.maxConcurrent = maxConcurrent
        self.baseSink = await BaseSink(observer: observer, cancel: cancel)
    }

    func run(_ source: Observable<SourceElement>, _ c: C) async -> Disposable {
        _ = await group.insert(sourceSubscription)

        let disposable = await source.subscribe(c.call(), self)
        await sourceSubscription.setDisposable(disposable)
        return group
    }

    func subscribe(_ innerSource: SourceSequence, group: CompositeDisposable, _ c: C) async {
        let subscription = await SingleAssignmentDisposable()

        let key = await group.insert(subscription)

        if let key {
            let observer = MergeLimitedSinkIter(parent: self, disposeKey: key)

            let disposable = await innerSource.asObservable().subscribe(c.call(), observer)
            await subscription.setDisposable(disposable)
        }
    }

    func performMap(_ element: SourceElement) throws -> SourceSequence {
        rxAbstractMethod()
    }

    @inline(__always)
    private final func nextElementArrived(element: SourceElement, _ c: C) async -> SourceSequence? {
        await lock.performLocked {
            let subscribe: Bool
            if self.activeCount < self.maxConcurrent {
                self.activeCount += 1
                subscribe = true
            } else {
                do {
                    let value = try self.performMap(element)
                    self.queue.enqueue(value)
                } catch {
                    await self.forwardOn(.error(error), c.call())
                    await self.dispose()
                }
                subscribe = false
            }

            if subscribe {
                do {
                    return try self.performMap(element)
                } catch {
                    await self.forwardOn(.error(error), c.call())
                    await self.dispose()
                }
            }

            return nil
        }
    }

    func on(_ event: Event<SourceElement>, _ c: C) async {
        switch event {
        case .next(let element):
            if let sequence = await nextElementArrived(element: element, c.call()) {
                await subscribe(sequence, group: group, c.call())
            }
        case .error(let error):
            await lock.performLocked {
                await self.forwardOn(.error(error), c.call())
                await self.dispose()
            }
        case .completed:
            await lock.performLocked {
                if self.activeCount == 0 {
                    await self.forwardOn(.completed, c.call())
                    await self.dispose()
                } else {
                    await self.sourceSubscription.dispose()
                }

                self.stopped = true
            }
        }
    }
}

private final class MergeLimited<SourceSequence: ObservableConvertibleType>: Producer<SourceSequence.Element> {
    private let source: Observable<SourceSequence>
    private let maxConcurrent: Int

    init(source: Observable<SourceSequence>, maxConcurrent: Int) async {
        self.source = source
        self.maxConcurrent = maxConcurrent
        await super.init()
    }

    override func run<Observer: ObserverType>(
        _ c: C,
        _ observer: Observer,
        cancel: Cancelable
    )
        async -> (sink: Disposable, subscription: Disposable)
        where Observer.Element == SourceSequence.Element {
        let sink = await MergeLimitedBasicSink<SourceSequence, Observer>(
            maxConcurrent: maxConcurrent,
            observer: observer,
            cancel: cancel
        )
        let subscription = await sink.run(source, c.call())
        return (sink: sink, subscription: subscription)
    }
}

// MARK: Merge

private final class MergeBasicSink<Source: ObservableConvertibleType, Observer: ObserverType>: MergeSink<
    Source,
    Source,
    Observer
> where Observer.Element == Source.Element {
    override func performMap(_ element: Source) async throws -> Source {
        element
    }
}

// MARK: flatMap

private final class FlatMapSink<
    SourceElement,
    SourceSequence: ObservableConvertibleType,
    Observer: ObserverType
>: MergeSink<SourceElement, SourceSequence, Observer> where Observer.Element == SourceSequence.Element {
    typealias Selector = (SourceElement) async throws -> SourceSequence

    private let selector: Selector

    init(selector: @escaping Selector, observer: Observer, cancel: Cancelable) async {
        self.selector = selector
        self.baseSink = await BaseSink(observer: observer, cancel: cancel)
    }

    override func performMap(_ element: SourceElement) async throws -> SourceSequence {
        try await selector(element)
    }
}

// MARK: FlatMapFirst

private final class FlatMapFirstSink<
    SourceElement,
    SourceSequence: ObservableConvertibleType,
    Observer: ObserverType
>: MergeSink<SourceElement, SourceSequence, Observer> where Observer.Element == SourceSequence.Element {
    typealias Selector = (SourceElement) async throws -> SourceSequence

    private let selector: Selector

    override var subscribeNext: Bool {
        activeCount == 0
    }

    init(selector: @escaping Selector, observer: Observer, cancel: Cancelable) async {
        self.selector = selector
        self.baseSink = await BaseSink(observer: observer, cancel: cancel)
    }

    override func performMap(_ element: SourceElement) async throws -> SourceSequence {
        try await selector(element)
    }
}

private final class MergeSinkIter<
    SourceElement,
    SourceSequence: ObservableConvertibleType,
    Observer: ObserverType
>: ObserverType where Observer.Element == SourceSequence.Element {
    typealias Parent = MergeSink<SourceElement, SourceSequence, Observer>
    typealias DisposeKey = CompositeDisposable.DisposeKey
    typealias Element = Observer.Element

    private let parent: Parent
    private let disposeKey: DisposeKey

    init(parent: Parent, disposeKey: DisposeKey) {
        self.parent = parent
        self.disposeKey = disposeKey
    }

    func on(_ event: Event<Element>, _ c: C) async {
        await parent.lock.performLocked {
            switch event {
            case .next(let value):
                await self.parent.forwardOn(.next(value), c.call())
            case .error(let error):
                await self.parent.forwardOn(.error(error), c.call())
                await self.parent.dispose()
            case .completed:
                await self.parent.group.remove(for: self.disposeKey)
                self.parent.activeCount -= 1
                await self.parent.checkCompleted(c.call())
            }
        }
    }
}

private class MergeSink<SourceElement, SourceSequence: ObservableConvertibleType, Observer: ObserverType>:
    Sink,
    ObserverType where Observer.Element == SourceSequence.Element {
    typealias ResultType = Observer.Element
    typealias Element = SourceElement

    let lock: RecursiveLock

    var subscribeNext: Bool {
        true
    }

    // state
    let group: CompositeDisposable
    let sourceSubscription: SingleAssignmentDisposable

    var activeCount = 0
    var stopped = false

    override init(observer: Observer, cancel: Cancelable) async {
        lock = await RecursiveLock()
        group = await CompositeDisposable()
        sourceSubscription = await SingleAssignmentDisposable()
        self.baseSink = await BaseSink(observer: observer, cancel: cancel)
    }

    func performMap(_ element: SourceElement) async throws -> SourceSequence {
        rxAbstractMethod()
    }

    @inline(__always)
    private final func nextElementArrived(element: SourceElement, _ c: C) async -> SourceSequence? {
        await lock.performLocked {
            if !self.subscribeNext {
                return nil
            }

            do {
                let value = try await self.performMap(element)
                self.activeCount += 1
                return value
            } catch let e {
                await self.forwardOn(.error(e), c.call())
                await self.dispose()
                return nil
            }
        }
    }

    func on(_ event: Event<SourceElement>, _ c: C) async {
        switch event {
        case .next(let element):
            if let value = await nextElementArrived(element: element, c.call()) {
                await subscribeInner(value.asObservable(), c.call())
            }
        case .error(let error):
            await lock.performLocked {
                await self.forwardOn(.error(error), c.call())
                await self.dispose()
            }
        case .completed:
            await lock.performLocked {
                self.stopped = true
                await self.sourceSubscription.dispose()
                await self.checkCompleted(c.call())
            }
        }
    }

    func subscribeInner(_ source: Observable<Observer.Element>, _ c: C) async {
        let iterDisposable = await SingleAssignmentDisposable()
        if let disposeKey = await group.insert(iterDisposable) {
            let iter = MergeSinkIter(parent: self, disposeKey: disposeKey)
            let subscription = await source.subscribe(c.call(), iter)
            await iterDisposable.setDisposable(subscription)
        }
    }

    func run(_ sources: [Observable<Observer.Element>], _ c: C) async -> Disposable {
        activeCount += sources.count

        for source in sources {
            await subscribeInner(source, c.call())
        }

        stopped = true

        await checkCompleted(c.call())

        return group
    }

    @inline(__always)
    func checkCompleted(_ c: C) async {
        if stopped, activeCount == 0 {
            await forwardOn(.completed, c.call())
            await dispose()
        }
    }

    func run(_ source: Observable<SourceElement>, _ c: C) async -> Disposable {
        _ = await group.insert(sourceSubscription)

        let subscription = await source.subscribe(c.call(), self)
        await sourceSubscription.setDisposable(subscription)

        return group
    }
}

// MARK: Producers

private final class FlatMap<
    SourceElement,
    SourceSequence: ObservableConvertibleType
>: Producer<SourceSequence.Element> {
    typealias Selector = (SourceElement) async throws -> SourceSequence

    private let source: Observable<SourceElement>

    private let selector: Selector

    init(source: Observable<SourceElement>, selector: @escaping Selector) async {
        self.source = source
        self.selector = selector
        await super.init()
    }

    override func run<Observer: ObserverType>(
        _ c: C,
        _ observer: Observer,
        cancel: Cancelable
    )
        async -> (sink: Disposable, subscription: Disposable)
        where Observer.Element == SourceSequence.Element {
        let sink = await FlatMapSink(selector: selector, observer: observer, cancel: cancel)
        let subscription = await sink.run(source, c.call())
        return (sink: sink, subscription: subscription)
    }
}

private final class FlatMapFirst<
    SourceElement,
    SourceSequence: ObservableConvertibleType
>: Producer<SourceSequence.Element> {
    typealias Selector = (SourceElement) async throws -> SourceSequence

    private let source: Observable<SourceElement>

    private let selector: Selector

    init(source: Observable<SourceElement>, selector: @escaping Selector) async {
        self.source = source
        self.selector = selector
        await super.init()
    }

    override func run<Observer: ObserverType>(
        _ c: C,
        _ observer: Observer,
        cancel: Cancelable
    )
        async -> (sink: Disposable, subscription: Disposable)
        where Observer.Element == SourceSequence.Element {
        let sink = await FlatMapFirstSink<SourceElement, SourceSequence, Observer>(
            selector: selector,
            observer: observer,
            cancel: cancel
        )
        let subscription = await sink.run(source, c.call())
        return (sink: sink, subscription: subscription)
    }
}

final class ConcatMap<SourceElement, SourceSequence: ObservableConvertibleType>: Producer<SourceSequence.Element> {
    typealias Selector = (SourceElement) throws -> SourceSequence

    private let source: Observable<SourceElement>
    private let selector: Selector

    init(source: Observable<SourceElement>, selector: @escaping Selector) async {
        self.source = source
        self.selector = selector
        await super.init()
    }

    override func run<Observer: ObserverType>(
        _ c: C,
        _ observer: Observer,
        cancel: Cancelable
    )
        async -> (sink: Disposable, subscription: Disposable)
        where Observer.Element == SourceSequence.Element {
        let sink = await ConcatMapSink<SourceElement, SourceSequence, Observer>(
            selector: selector,
            observer: observer,
            cancel: cancel
        )
        let subscription = await sink.run(source, c.call())
        return (sink: sink, subscription: subscription)
    }
}

final class Merge<SourceSequence: ObservableConvertibleType>: Producer<SourceSequence.Element> {
    private let source: Observable<SourceSequence>

    init(source: Observable<SourceSequence>) async {
        self.source = source
        await super.init()
    }

    override func run<Observer: ObserverType>(
        _ c: C,
        _ observer: Observer,
        cancel: Cancelable
    )
        async -> (sink: Disposable, subscription: Disposable)
        where Observer.Element == SourceSequence.Element {
        let sink = await MergeBasicSink<SourceSequence, Observer>(observer: observer, cancel: cancel)
        let subscription = await sink.run(source, c.call())
        return (sink: sink, subscription: subscription)
    }
}

private final class MergeArray<Element>: Producer<Element> {
    private let sources: [Observable<Element>]

    init(sources: [Observable<Element>]) async {
        self.sources = sources
        await super.init()
    }

    override func run<Observer: ObserverType>(
        _ c: C,
        _ observer: Observer,
        cancel: Cancelable
    )
        async -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        let sink = await MergeBasicSink<Observable<Element>, Observer>(observer: observer, cancel: cancel)
        let subscription = await sink.run(sources, c.call())
        return (sink: sink, subscription: subscription)
    }
}
