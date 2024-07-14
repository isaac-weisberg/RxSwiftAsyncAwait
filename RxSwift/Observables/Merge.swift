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
        -> Observable<Source.Element>
    {
        return await FlatMap(source: self.asObservable(), selector: selector)
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
    func flatMapFirst<Source: ObservableConvertibleType>(_ selector: @escaping (Element) throws -> Source) async
        -> Observable<Source.Element>
    {
        return await FlatMapFirst(source: self.asObservable(), selector: selector)
    }
}

public extension ObservableType where Element: ObservableConvertibleType {
    /**
     Merges elements from all observable sequences in the given enumerable sequence into a single observable sequence.

     - seealso: [merge operator on reactivex.io](http://reactivex.io/documentation/operators/merge.html)

     - returns: The observable sequence that merges the elements of the observable sequences.
     */
    func merge() async -> Observable<Element.Element> {
        await Merge(source: self.asObservable())
    }

    /**
     Merges elements from all inner observable sequences into a single observable sequence, limiting the number of concurrent subscriptions to inner sequences.

     - seealso: [merge operator on reactivex.io](http://reactivex.io/documentation/operators/merge.html)

     - parameter maxConcurrent: Maximum number of inner observable sequences being subscribed to concurrently.
     - returns: The observable sequence that merges the elements of the inner sequences.
     */
    func merge(maxConcurrent: Int) async
        -> Observable<Element.Element>
    {
        await MergeLimited(source: self.asObservable(), maxConcurrent: maxConcurrent)
    }
}

public extension ObservableType where Element: ObservableConvertibleType {
    /**
     Concatenates all inner observable sequences, as long as the previous observable sequence terminated successfully.

     - seealso: [concat operator on reactivex.io](http://reactivex.io/documentation/operators/concat.html)

     - returns: An observable sequence that contains the elements of each observed inner sequence, in sequential order.
     */
    func concat() async -> Observable<Element.Element> {
        await self.merge(maxConcurrent: 1)
    }
}

public extension ObservableType {
    /**
     Merges elements from all observable sequences from collection into a single observable sequence.

     - seealso: [merge operator on reactivex.io](http://reactivex.io/documentation/operators/merge.html)

     - parameter sources: Collection of observable sequences to merge.
     - returns: The observable sequence that merges the elements of the observable sequences.
     */
    static func merge<Collection: Swift.Collection>(_ sources: Collection) async -> Observable<Element> where Collection.Element == Observable<Element> {
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
        -> Observable<Source.Element>
    {
        return await ConcatMap(source: self.asObservable(), selector: selector)
    }
}

private final class MergeLimitedSinkIter<SourceElement, SourceSequence: ObservableConvertibleType, Observer: ObserverType>:
    ObserverType,
    LockOwnerType,
    SynchronizedOnType where SourceSequence.Element == Observer.Element
{
    typealias Element = Observer.Element
    typealias DisposeKey = CompositeDisposable.DisposeKey
    typealias Parent = MergeLimitedSink<SourceElement, SourceSequence, Observer>

    private let parent: Parent
    private let disposeKey: DisposeKey

    var lock: RecursiveLock {
        self.parent.lock
    }

    init(parent: Parent, disposeKey: DisposeKey) {
        self.parent = parent
        self.disposeKey = disposeKey
    }

    func on(_ event: Event<Element>) async {
        await self.synchronizedOn(event)
    }

    func synchronized_on(_ event: Event<Element>) async {
        switch event {
        case .next:
            await self.parent.forwardOn(event)
        case .error:
            await self.parent.forwardOn(event)
            await self.parent.dispose()
        case .completed:
            await self.parent.group.remove(for: self.disposeKey)
            if let next = self.parent.queue.dequeue() {
                await self.parent.subscribe(next, group: self.parent.group)
            }
            else {
                self.parent.activeCount -= 1

                if self.parent.stopped && self.parent.activeCount == 0 {
                    await self.parent.forwardOn(.completed)
                    await self.parent.dispose()
                }
            }
        }
    }
}

private final class ConcatMapSink<SourceElement, SourceSequence: ObservableConvertibleType, Observer: ObserverType>: MergeLimitedSink<SourceElement, SourceSequence, Observer> where Observer.Element == SourceSequence.Element {
    typealias Selector = (SourceElement) throws -> SourceSequence

    private let selector: Selector

    init(selector: @escaping Selector, observer: Observer, cancel: Cancelable) async {
        self.selector = selector
        await super.init(maxConcurrent: 1, observer: observer, cancel: cancel)
    }

    override func performMap(_ element: SourceElement) throws -> SourceSequence {
        try self.selector(element)
    }
}

private final class MergeLimitedBasicSink<SourceSequence: ObservableConvertibleType, Observer: ObserverType>: MergeLimitedSink<SourceSequence, SourceSequence, Observer> where Observer.Element == SourceSequence.Element {
    override func performMap(_ element: SourceSequence) throws -> SourceSequence {
        element
    }
}

private class MergeLimitedSink<SourceElement, SourceSequence: ObservableConvertibleType, Observer: ObserverType>:
    Sink<Observer>,
    ObserverType where Observer.Element == SourceSequence.Element
{
    typealias QueueType = Queue<SourceSequence>

    let maxConcurrent: Int

    let lock: RecursiveLock

    // state
    var stopped = false
    var activeCount = 0
    var queue = QueueType(capacity: 2)

    let sourceSubscription: SingleAssignmentDisposable
    let group: CompositeDisposable

    init(maxConcurrent: Int, observer: Observer, cancel: Cancelable) async {
        self.lock = await RecursiveLock()
        self.sourceSubscription = await SingleAssignmentDisposable()
        self.group = await CompositeDisposable()
        self.maxConcurrent = maxConcurrent
        await super.init(observer: observer, cancel: cancel)
    }

    func run(_ source: Observable<SourceElement>) async -> Disposable {
        _ = await self.group.insert(self.sourceSubscription)

        let disposable = await source.subscribe(self)
        await self.sourceSubscription.setDisposable(disposable)
        return self.group
    }

    func subscribe(_ innerSource: SourceSequence, group: CompositeDisposable) async {
        let subscription = await SingleAssignmentDisposable()

        let key = await group.insert(subscription)

        if let key = key {
            let observer = MergeLimitedSinkIter(parent: self, disposeKey: key)

            let disposable = await innerSource.asObservable().subscribe(observer)
            await subscription.setDisposable(disposable)
        }
    }

    func performMap(_ element: SourceElement) throws -> SourceSequence {
        rxAbstractMethod()
    }

    @inline(__always)
    private final func nextElementArrived(element: SourceElement) async -> SourceSequence? {
        await self.lock.performLocked {
            let subscribe: Bool
            if self.activeCount < self.maxConcurrent {
                self.activeCount += 1
                subscribe = true
            }
            else {
                do {
                    let value = try self.performMap(element)
                    self.queue.enqueue(value)
                }
                catch {
                    await self.forwardOn(.error(error))
                    await self.dispose()
                }
                subscribe = false
            }

            if subscribe {
                do {
                    return try self.performMap(element)
                }
                catch {
                    await self.forwardOn(.error(error))
                    await self.dispose()
                }
            }

            return nil
        }
    }

    func on(_ event: Event<SourceElement>) async {
        switch event {
        case .next(let element):
            if let sequence = await self.nextElementArrived(element: element) {
                await self.subscribe(sequence, group: self.group)
            }
        case .error(let error):
            await self.lock.performLocked {
                await self.forwardOn(.error(error))
                await self.dispose()
            }
        case .completed:
            await self.lock.performLocked {
                if self.activeCount == 0 {
                    await self.forwardOn(.completed)
                    await self.dispose()
                }
                else {
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

    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) async -> (sink: Disposable, subscription: Disposable) where Observer.Element == SourceSequence.Element {
        let sink = await MergeLimitedBasicSink<SourceSequence, Observer>(maxConcurrent: self.maxConcurrent, observer: observer, cancel: cancel)
        let subscription = await sink.run(self.source)
        return (sink: sink, subscription: subscription)
    }
}

// MARK: Merge

private final class MergeBasicSink<Source: ObservableConvertibleType, Observer: ObserverType>: MergeSink<Source, Source, Observer> where Observer.Element == Source.Element {
    override func performMap(_ element: Source) async throws -> Source {
        element
    }
}

// MARK: flatMap

private final class FlatMapSink<SourceElement, SourceSequence: ObservableConvertibleType, Observer: ObserverType>: MergeSink<SourceElement, SourceSequence, Observer> where Observer.Element == SourceSequence.Element {
    typealias Selector = (SourceElement) async throws -> SourceSequence

    private let selector: Selector

    init(selector: @escaping Selector, observer: Observer, cancel: Cancelable) async {
        self.selector = selector
        await super.init(observer: observer, cancel: cancel)
    }

    override func performMap(_ element: SourceElement) async throws -> SourceSequence {
        try await self.selector(element)
    }
}

// MARK: FlatMapFirst

private final class FlatMapFirstSink<SourceElement, SourceSequence: ObservableConvertibleType, Observer: ObserverType>: MergeSink<SourceElement, SourceSequence, Observer> where Observer.Element == SourceSequence.Element {
    typealias Selector = (SourceElement) throws -> SourceSequence

    private let selector: Selector

    override var subscribeNext: Bool {
        self.activeCount == 0
    }

    init(selector: @escaping Selector, observer: Observer, cancel: Cancelable) async {
        self.selector = selector
        await super.init(observer: observer, cancel: cancel)
    }

    override func performMap(_ element: SourceElement) async throws -> SourceSequence {
        try self.selector(element)
    }
}

private final class MergeSinkIter<SourceElement, SourceSequence: ObservableConvertibleType, Observer: ObserverType>: ObserverType where Observer.Element == SourceSequence.Element {
    typealias Parent = MergeSink<SourceElement, SourceSequence, Observer>
    typealias DisposeKey = CompositeDisposable.DisposeKey
    typealias Element = Observer.Element

    private let parent: Parent
    private let disposeKey: DisposeKey

    init(parent: Parent, disposeKey: DisposeKey) {
        self.parent = parent
        self.disposeKey = disposeKey
    }

    func on(_ event: Event<Element>) async {
        await self.parent.lock.performLocked {
            switch event {
            case .next(let value):
                await self.parent.forwardOn(.next(value))
            case .error(let error):
                await self.parent.forwardOn(.error(error))
                await self.parent.dispose()
            case .completed:
                await self.parent.group.remove(for: self.disposeKey)
                self.parent.activeCount -= 1
                await self.parent.checkCompleted()
            }
        }
    }
}

private class MergeSink<SourceElement, SourceSequence: ObservableConvertibleType, Observer: ObserverType>:
    Sink<Observer>,
    ObserverType where Observer.Element == SourceSequence.Element
{
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
        self.lock = await RecursiveLock()
        self.group = await CompositeDisposable()
        self.sourceSubscription = await SingleAssignmentDisposable()
        await super.init(observer: observer, cancel: cancel)
    }

    func performMap(_ element: SourceElement) async throws -> SourceSequence {
        rxAbstractMethod()
    }

    @inline(__always)
    private final func nextElementArrived(element: SourceElement) async -> SourceSequence? {
        await self.lock.performLocked {
            if !self.subscribeNext {
                return nil
            }

            do {
                let value = try await self.performMap(element)
                self.activeCount += 1
                return value
            }
            catch let e {
                await self.forwardOn(.error(e))
                await self.dispose()
                return nil
            }
        }
    }

    func on(_ event: Event<SourceElement>) async {
        switch event {
        case .next(let element):
            if let value = await self.nextElementArrived(element: element) {
                await self.subscribeInner(value.asObservable())
            }
        case .error(let error):
            await self.lock.performLocked {
                await self.forwardOn(.error(error))
                await self.dispose()
            }
        case .completed:
            await self.lock.performLocked {
                self.stopped = true
                await self.sourceSubscription.dispose()
                await self.checkCompleted()
            }
        }
    }

    func subscribeInner(_ source: Observable<Observer.Element>) async {
        let iterDisposable = await SingleAssignmentDisposable()
        if let disposeKey = await self.group.insert(iterDisposable) {
            let iter = MergeSinkIter(parent: self, disposeKey: disposeKey)
            let subscription = await source.subscribe(iter)
            await iterDisposable.setDisposable(subscription)
        }
    }

    func run(_ sources: [Observable<Observer.Element>]) async -> Disposable {
        self.activeCount += sources.count

        for source in sources {
            await self.subscribeInner(source)
        }

        self.stopped = true

        await self.checkCompleted()

        return self.group
    }

    @inline(__always)
    func checkCompleted() async {
        if self.stopped && self.activeCount == 0 {
            await self.forwardOn(.completed)
            await self.dispose()
        }
    }

    func run(_ source: Observable<SourceElement>) async -> Disposable {
        _ = await self.group.insert(self.sourceSubscription)

        let subscription = await source.subscribe(self)
        await self.sourceSubscription.setDisposable(subscription)

        return self.group
    }
}

// MARK: Producers

private final class FlatMap<SourceElement, SourceSequence: ObservableConvertibleType>: Producer<SourceSequence.Element> {
    typealias Selector = (SourceElement) async throws -> SourceSequence

    private let source: Observable<SourceElement>

    private let selector: Selector

    init(source: Observable<SourceElement>, selector: @escaping Selector) async {
        self.source = source
        self.selector = selector
        await super.init()
    }

    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) async -> (sink: Disposable, subscription: Disposable) where Observer.Element == SourceSequence.Element {
        let sink = await FlatMapSink(selector: self.selector, observer: observer, cancel: cancel)
        let subscription = await sink.run(self.source)
        return (sink: sink, subscription: subscription)
    }
}

private final class FlatMapFirst<SourceElement, SourceSequence: ObservableConvertibleType>: Producer<SourceSequence.Element> {
    typealias Selector = (SourceElement) throws -> SourceSequence

    private let source: Observable<SourceElement>

    private let selector: Selector

    init(source: Observable<SourceElement>, selector: @escaping Selector) async {
        self.source = source
        self.selector = selector
        await super.init()
    }

    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) async -> (sink: Disposable, subscription: Disposable) where Observer.Element == SourceSequence.Element {
        let sink = await FlatMapFirstSink<SourceElement, SourceSequence, Observer>(selector: self.selector, observer: observer, cancel: cancel)
        let subscription = await sink.run(self.source)
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

    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) async -> (sink: Disposable, subscription: Disposable) where Observer.Element == SourceSequence.Element {
        let sink = await ConcatMapSink<SourceElement, SourceSequence, Observer>(selector: self.selector, observer: observer, cancel: cancel)
        let subscription = await sink.run(self.source)
        return (sink: sink, subscription: subscription)
    }
}

final class Merge<SourceSequence: ObservableConvertibleType>: Producer<SourceSequence.Element> {
    private let source: Observable<SourceSequence>

    init(source: Observable<SourceSequence>) async {
        self.source = source
        await super.init()
    }

    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) async -> (sink: Disposable, subscription: Disposable) where Observer.Element == SourceSequence.Element {
        let sink = await MergeBasicSink<SourceSequence, Observer>(observer: observer, cancel: cancel)
        let subscription = await sink.run(self.source)
        return (sink: sink, subscription: subscription)
    }
}

private final class MergeArray<Element>: Producer<Element> {
    private let sources: [Observable<Element>]

    init(sources: [Observable<Element>]) async {
        self.sources = sources
        await super.init()
    }

    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) async -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        let sink = await MergeBasicSink<Observable<Element>, Observer>(observer: observer, cancel: cancel)
        let subscription = await sink.run(self.sources)
        return (sink: sink, subscription: subscription)
    }
}
