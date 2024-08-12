//
//  Merge.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 3/28/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

public extension ObservableConvertibleType {
    /**
     Projects each element of an observable sequence to an observable sequence and merges the resulting observable
     sequences into one observable sequence.

     - seealso: [flatMap operator on reactivex.io](http://reactivex.io/documentation/operators/flatmap.html)

     - parameter selector: A transform function to apply to each element.
     - returns: An observable sequence whose elements are the result of invoking the one-to-many transform function on
     each element of the input sequence.
     */
    func flatMap<Source: ObservableConvertibleType>(_ selector: @Sendable @escaping (Element) throws -> Source)
        -> Observable<Source.Element> {
        FlatMap(source: asObservable(), selector: selector)
    }
}

public extension ObservableType {
    /**
     Projects each element of an observable sequence to an observable sequence and merges the resulting observable
     sequences into one observable sequence.
     If element is received while there is some projected observable sequence being merged it will simply be ignored.

     - seealso: [flatMapFirst operator on reactivex.io](http://reactivex.io/documentation/operators/flatmap.html)

     - parameter selector: A transform function to apply to element that was observed while no observable is executing
     in parallel.
     - returns: An observable sequence whose elements are the result of invoking the one-to-many transform function on
     each element of the input sequence that was received while no other sequence was being calculated.
     */
    func flatMapFirst<Source: ObservableConvertibleType>(_ selector: @Sendable @escaping (Element) throws -> Source)
        -> Observable<Source.Element> {
        FlatMapFirst(source: asObservable(), selector: selector)
    }
}

//
// public extension ObservableType where Element: ObservableConvertibleType {
//    /**
//     Merges elements from all observable sequences in the given enumerable sequence into a single observable sequence.
//
//     - seealso: [merge operator on reactivex.io](http://reactivex.io/documentation/operators/merge.html)
//
//     - returns: The observable sequence that merges the elements of the observable sequences.
//     */
//    func merge() async -> Observable<Element.Element> {
//        await Merge(source: asObservable())
//    }
//
//    /**
//     Merges elements from all inner observable sequences into a single observable sequence, limiting the number of
//     concurrent subscriptions to inner sequences.
//
//     - seealso: [merge operator on reactivex.io](http://reactivex.io/documentation/operators/merge.html)
//
//     - parameter maxConcurrent: Maximum number of inner observable sequences being subscribed to concurrently.
//     - returns: The observable sequence that merges the elements of the inner sequences.
//     */
//    func merge(maxConcurrent: Int) async
//        -> Observable<Element.Element> {
//        await MergeLimited(source: asObservable(), maxConcurrent: maxConcurrent)
//    }
// }
//
// public extension ObservableType where Element: ObservableConvertibleType {
//    /**
//     Concatenates all inner observable sequences, as long as the previous observable sequence terminated successfully.
//
//     - seealso: [concat operator on reactivex.io](http://reactivex.io/documentation/operators/concat.html)
//
//     - returns: An observable sequence that contains the elements of each observed inner sequence, in sequential
//     order.
//     */
//    func concat() async -> Observable<Element.Element> {
//        await merge(maxConcurrent: 1)
//    }
// }

public extension ObservableType {
    /**
     Merges elements from all observable sequences from collection into a single observable sequence.

     - seealso: [merge operator on reactivex.io](http://reactivex.io/documentation/operators/merge.html)

     - parameter sources: Collection of observable sequences to merge.
     - returns: The observable sequence that merges the elements of the observable sequences.
     */
    static func merge<Collection: Swift.Collection>(_ sources: Collection) -> Observable<Element>
        where Collection.Element == Observable<Element> {
        MergeArray(sources: Array(sources))
    }

    /**
     Merges elements from all observable sequences from array into a single observable sequence.

     - seealso: [merge operator on reactivex.io](http://reactivex.io/documentation/operators/merge.html)

     - parameter sources: Array of observable sequences to merge.
     - returns: The observable sequence that merges the elements of the observable sequences.
     */
    static func merge(_ sources: [Observable<Element>]) -> Observable<Element> {
        MergeArray(sources: sources)
    }

    /**
     Merges elements from all observable sequences into a single observable sequence.

     - seealso: [merge operator on reactivex.io](http://reactivex.io/documentation/operators/merge.html)

     - parameter sources: Collection of observable sequences to merge.
     - returns: The observable sequence that merges the elements of the observable sequences.
     */
    static func merge(_ sources: Observable<Element>...) -> Observable<Element> {
        MergeArray(sources: sources)
    }
}

//// MARK: concatMap
//
// public extension ObservableType {
//    /**
//     Projects each element of an observable sequence to an observable sequence and concatenates the resulting
//     observable sequences into one observable sequence.
//
//     - seealso: [concat operator on reactivex.io](http://reactivex.io/documentation/operators/concat.html)
//
//     - returns: An observable sequence that contains the elements of each observed inner sequence, in sequential
//     order.
//     */
//
//    func concatMap<Source: ObservableConvertibleType>(_ selector: @escaping (Element) throws -> Source) async
//        -> Observable<Source.Element> {
//        await ConcatMap(source: asObservable(), selector: selector)
//    }
// }
//
// private final actor MergeLimitedSinkIter<
//    SourceElement,
//    DerivedSequence: ObservableConvertibleType,
//    Observer: ObserverType
// >:
//    ObserverType,
//    AsynchronousOnType where DerivedSequence.Element == Observer.Element {
//    typealias Element = Observer.Element
//    typealias DisposeKey = CompositeDisposable.DisposeKey
//    typealias Parent = MergeLimitedSink<SourceElement, DerivedSequence, Observer>
//
//    private let parent: Parent
//    private let disposeKey: DisposeKey
//
//    init(parent: Parent, disposeKey: DisposeKey) {
//        self.parent = parent
//        self.disposeKey = disposeKey
//    }
//
//    func on(_ event: Event<Element>, _ c: C) async {
//        await AsynchronousOn(event, c.call())
//    }
//
//    func Asynchronous_on(_ event: Event<Element>, _ c: C) async {
//        switch event {
//        case .next:
//            await parent.forwardOn(event, c.call())
//        case .error:
//            await parent.forwardOn(event, c.call())
//            await parent.dispose()
//        case .completed:
//            await parent.group.remove(for: disposeKey)
//            if let next = await parent.dequeueFromQueue() {
//                await parent.subscribe(next, group: parent.group, c.call())
//            } else {
//                await parent.setActiveCount(await parent.activeCount - 1)
//
//                if await parent.sourceHasStopped, await parent.activeCount == 0 {
//                    await parent.forwardOn(.completed, c.call())
//                    await parent.dispose()
//                }
//            }
//        }
//    }
// }
////
////private final class ConcatMapSink<
////    SourceElement,
////    DerivedSequence: ObservableConvertibleType,
////    Observer: ObserverType
////>: MergeLimitedSink<SourceElement, DerivedSequence, Observer> where Observer.Element == DerivedSequence.Element {
////    typealias Selector = (SourceElement) throws -> DerivedSequence
////
////    private let selector: Selector
////
////    init(selector: @escaping Selector, observer: Observer) async {
////        self.selector = selector
////        await super.init(maxConcurrent: 1, observer: observer)
////    }
////
////    override func performMap(_ element: SourceElement) throws -> DerivedSequence {
////        try selector(element)
////    }
////}
////
////private final class MergeLimitedBasicSink<
////    DerivedSequence: ObservableConvertibleType,
////    Observer: ObserverType
////>: MergeLimitedSink<DerivedSequence, DerivedSequence, Observer> where Observer.Element == DerivedSequence.Element {
////    override func performMap(_ element: DerivedSequence) throws -> DerivedSequence {
////        element
////    }
////}
//
// private actor MergeLimitedSink<SourceElement, DerivedSequence: ObservableConvertibleType, Observer: ObserverType>:
//    Sink,
//    ObserverType where Observer.Element == DerivedSequence.Element {
//    typealias QueueType = Queue<DerivedSequence>
//
//    typealias Element = SourceElement
//
//    let maxConcurrent: Int
//
//    // state
//    var sourceHasStopped = false
//    var activeCount = 0
//    func setActiveCount(_ activeCount: Int) {
//        self.activeCount = activeCount
//    }
//    var queue = QueueType(capacity: 2)
//    fileprivate func dequeueFromQueue() -> DerivedSequence? {
//        queue.dequeue()
//    }
//
//    let sourceSubscription: SingleAssignmentDisposable
//    let group: CompositeDisposable
//    let baseSink: BaseSink<Observer>
//
//    init(maxConcurrent: Int, observer: Observer) async {
//        sourceSubscription = await SingleAssignmentDisposable()
//        group = await CompositeDisposable()
//        self.maxConcurrent = maxConcurrent
//        baseSink = BaseSink(observer: observer)
//    }
//
//    func run(_ source: Observable<SourceElement>, _ c: C) async -> Disposable {
//        _ = await group.insert(sourceSubscription)
//
//        let disposable = await source.subscribe(c.call(), self)
//        await sourceSubscription.setDisposable(disposable)
//        return group
//    }
//
//    func subscribe(_ innerSource: DerivedSequence, group: CompositeDisposable, _ c: C) async {
//        let subscription = await SingleAssignmentDisposable()
//
//        let key = await group.insert(subscription)
//
//        if let key {
//            let observer = MergeLimitedSinkIter(parent: self, disposeKey: key)
//
//            let disposable = await innerSource.asObservable().subscribe(c.call(), observer)
//            await subscription.setDisposable(disposable)
//        }
//    }
//
//    func performMap(_ element: SourceElement) throws -> DerivedSequence {
//        rxAbstractMethod()
//    }
//
//    @inline(__always)
//    private final func nextElementArrived(element: SourceElement, _ c: C) async -> DerivedSequence? {
//        let subscribe: Bool
//        if activeCount < maxConcurrent {
//            activeCount += 1
//            subscribe = true
//        } else {
//            do {
//                let value = try performMap(element)
//                queue.enqueue(value)
//            } catch {
//                await forwardOn(.error(error), c.call())
//                await dispose()
//            }
//            subscribe = false
//        }
//
//        if subscribe {
//            do {
//                return try performMap(element)
//            } catch {
//                await forwardOn(.error(error), c.call())
//                await dispose()
//            }
//        }
//
//        return nil
//    }
//
//    func on(_ event: Event<SourceElement>, _ c: C) async {
//        switch event {
//        case .next(let element):
//            if let sequence = await nextElementArrived(element: element, c.call()) {
//                await subscribe(sequence, group: group, c.call())
//            }
//        case .error(let error):
//            await forwardOn(.error(error), c.call())
//            await dispose()
//        case .completed:
//            if activeCount == 0 {
//                await forwardOn(.completed, c.call())
//                await dispose()
//            } else {
//                await sourceSubscription.dispose()
//            }
//
//            sourceHasStopped = true
//        }
//    }
// }
//
////private final class MergeLimited<DerivedSequence: ObservableConvertibleType>: Producer<DerivedSequence.Element> {
////    private let source: Observable<DerivedSequence>
////    private let maxConcurrent: Int
////
////    init(source: Observable<DerivedSequence>, maxConcurrent: Int) async {
////        self.source = source
////        self.maxConcurrent = maxConcurrent
////        await super.init()
////    }
////
////    override func run<Observer: ObserverType>(
////        _ c: C,
////        _ observer: Observer,
////        cancel: Cancelable
////    )
////        async -> (sink: Disposable, subscription: Disposable)
////        where Observer.Element == DerivedSequence.Element {
////        let sink = await MergeLimitedBasicSink<DerivedSequence, Observer>(
////            maxConcurrent: maxConcurrent,
////            observer: observer,
////            cancel: cancel
////        )
////        let subscription = await sink.run(source, c.call())
////        return sink
////    }
////}

// MARK: Merge

struct IdentityHashable<T: AnyObject>: Hashable {
    let inner: T

    static func == (lhs: IdentityHashable<T>, rhs: IdentityHashable<T>) -> Bool {
        ObjectIdentifier(lhs.inner) == ObjectIdentifier(rhs.inner)
    }

    func hash(into hasher: inout Hasher) {
        ObjectIdentifier(inner).hash(into: &hasher)
    }
}

private final actor TotalMergeSink<
    Source: Sendable,
    DerivedSequence: ObservableConvertibleType,
    Observer: ObserverType
>: Disposable
    where Observer.Element == DerivedSequence.Element {

    let observer: Observer
    init(observer: Observer) {
        self.observer = observer
    }

    private enum Input {
        enum Run {
            case singleSource(Observable<Source>)
            case multipleDerives([DerivedSequence])
        }

        case run(Run)
        case sourceEvent(Event<Source>)
        case derivedEvent(Event<DerivedSequence.Element>)
        case dispose
    }

    private enum Action: @unchecked Sendable {
        case subscribeToSource(Observable<Source>, SimpleDisposableBox)
        case subscribeToDerived(DerivedSequence, SimpleDisposableBox)
        case forwardEvent(Event<DerivedSequence.Element>)
        case dispose(Disposable)
    }

    private struct ActionWithC: Sendable {
        let c: C
        let action: Action
    }

    private typealias SourceSubscription = SimpleDisposableBox
    private typealias DerivedSubscription = IdentityHashable<SimpleDisposableBox>
    private typealias DerivedSubscriptions = Set<DerivedSubscription>

    private struct State {
        init(
            stage: Stage?,
            sourceSubscription: SourceSubscription?,
            derivedSubscriptions: DerivedSubscriptions?
        ) {
            self.stage = stage
            self.sourceSubscription = sourceSubscription
            self.derivedSubscriptions = derivedSubscriptions
        }

        enum Stage {
            case running
            case disposed
        }

        var stage: Stage?
        var sourceSubscription: SourceSubscription?
        var derivedSubscriptions: DerivedSubscriptions?
    }

    func runOnImmediateDerived(_ c: C, _ derivedSequences: [DerivedSequence]) async {
        await acceptInput(c.call(), .run(.multipleDerives(derivedSequences)))
    }

    func run(_ c: C, _ source: Observable<Source>) async {
        await acceptInput(c.call(), .run(.singleSource(source)))
    }

    func acceptSourceEvent(_ c: C, _ event: Event<Source>) async {
        await acceptInput(c.call(), .sourceEvent(event))
    }

    func acceptDerivedEvent(_ c: C, _ event: Event<DerivedSequence.Element>) async {
        await acceptInput(c.call(), .derivedEvent(event))
    }

    func dispose() async {
        await acceptInput(C(), .dispose)
    }

    private var state = State(stage: nil, sourceSubscription: nil, derivedSubscriptions: nil)

    private func acceptInput(_ c: C, _ input: Input) async {
        let (state, actions) = reduce(c.call(), state, input)

        self.state = state

        if actions.isEmpty {
            return
        }
        await performActions(actions)
    }

    private func reduce(_ c: C, _ state: State, _ input: Input) -> (State, [ActionWithC]) {
        switch input {
        case .run(let run):
            rxAssert(state.stage == nil)
            rxAssert(state.derivedSubscriptions == nil)

            switch run {
            case .singleSource(let source):
                let disposable = SimpleDisposableBox()
                let state = State(stage: .running, sourceSubscription: disposable, derivedSubscriptions: nil)
                let actions = [
                    ActionWithC(c: c.call(), action: Action.subscribeToSource(source, disposable)),
                ]

                return (state, actions)
            case .multipleDerives(let derives):
                var actions: [ActionWithC]
                actions.reserveCapacity(derives.count)
                var derivedSubscriptions = DerivedSubscriptions()
                derivedSubscriptions.reserveCapacity(derives.count)

                for derive in derives {
                    let disposable = SimpleDisposableBox()
                    actions.append(ActionWithC(c: c.call(), action: .subscribeToDerived(derive, disposable)))
                    derivedSubscriptions.insert(DerivedSubscription(inner: disposable))
                }

                let state = State(
                    stage: .running,
                    sourceSubscription: nil,
                    derivedSubscriptions: derivedSubscriptions
                )

                return (state, actions)
            }

        case .sourceEvent(let event):
            rxAssert(state.stage == .running)

            switch event {
            case .next(let element):

            case .error(let error):

            case .completed:
            }

        case .derivedEvent(let event):

        case .dispose:
            let sourceSubscriptionsActions: [ActionWithC]
            let sourceSubscription = state.sourceSubscription
            if let sourceSubscription {
                if sourceSubscription.disposed {
                    // already disposed because it has completed
                    sourceSubscriptionsActions = []
                } else {
                    sourceSubscription.disposed = true
                    if let disposable = sourceSubscription.disposable {
                        sourceSubscription.disposable = nil
                        // nice, it was running, but time to dispose
                        sourceSubscriptionsActions = [
                            ActionWithC(
                                c: c.call(),
                                action: .dispose(disposable)
                            ),
                        ]
                    } else {
                        // will be assigned when source's subscribe will return
                        sourceSubscriptionsActions = []
                    }
                }
            }

            var derivedSubscriptionsActions: [ActionWithC]
            if let derivedSubscriptions = state.derivedSubscriptions {
                derivedSubscriptionsActions = []
                derivedSubscriptionsActions.reserveCapacity(derivedSubscriptions.count)
                for derivedSubscription in derivedSubscriptions {
                    rxAssert(
                        !derivedSubscription.inner
                            .disposed
                    ) // when I made it disposed, I removed it from the set, so...

                    derivedSubscription.inner.disposed = true
                    if let disposable = derivedSubscription.inner.disposable {
                        derivedSubscription.inner.disposable = nil
                        derivedSubscriptionsActions.append(
                            ActionWithC(
                                c: c.call(),
                                action: .dispose(disposable)
                            )
                        )
                    } else {
                        // this means that the subscribe hasn't returned yet, so it will disposed after that
                    }
                }
            } else {
                derivedSubscriptionsActions = []
            }

            let totalActions = sourceSubscriptionsActions + derivedSubscriptionsActions

            let state = State(
                stage: .disposed,
                sourceSubscription: nil,
                derivedSubscriptions: nil
            )

            return (state, totalActions)
        }
    }

    private func performActions(_ actions: [ActionWithC]) async {
        if actions.count == 1 {
            await performAction(actions[0])
        } else {
            await withTaskGroup(of: Void.self, body: { taskGroup in
                for action in actions {
                    taskGroup.addTask {
                        await self.performAction(action)
                    }
                }
            })
        }
    }

    private func performAction(_ action: ActionWithC) async {
        let c = action.c
        let action = action.action

        switch action {
        case .subscribeToSource(let sourceSequence, let disposableBox):
            let observer = TotalMergeSinkSourceObserver(sink: self)
            let disposable = await sourceSequence.subscribe(c.call(), observer)
            if disposableBox.disposed {
                await disposable.dispose()
            } else {
                disposableBox.disposable = disposable
            }
        case .subscribeToDerived(let derivedSequence, let disposableBox):
            let observer = TotalMergeSinkDerivedObserver(sink: self)
            let disposable = await derivedSequence.asObservable().subscribe(c.call(), observer)
            if disposableBox.disposed {
                await disposable.dispose()
            } else {
                disposableBox.disposable = disposable
            }
        case .dispose(let disposable):
            await disposable.dispose()
        case .forwardEvent(let event):
            await observer.on(event, c.call())
        }
    }
}

final class TotalMergeSinkSourceObserver<
    Source: Sendable,
    DerivedSequence: ObservableConvertibleType,
    Observer: ObserverType
>: ObserverType where Observer.Element == DerivedSequence.Element {
    typealias Element = Source

    fileprivate let sink: TotalMergeSink<Source, DerivedSequence, Observer>

    fileprivate init(sink: TotalMergeSink<Source, DerivedSequence, Observer>) {
        self.sink = sink
    }

    func on(_ event: Event<Source>, _ c: C) async {
        await sink.acceptSourceEvent(c.call(), event)
    }
}

final class TotalMergeSinkDerivedObserver<
    Source: Sendable,
    DerivedSequence: ObservableConvertibleType,
    Observer: ObserverType
>: ObserverType where Observer.Element == DerivedSequence.Element {
    typealias Element = DerivedSequence.Element

    fileprivate let sink: TotalMergeSink<Source, DerivedSequence, Observer>

    fileprivate init(sink: TotalMergeSink<Source, DerivedSequence, Observer>) {
        self.sink = sink
    }

    func on(_ event: Event<Element>, _ c: C) async {
        await sink.acceptDerivedEvent(c.call(), event)
    }
}

// MARK: FlatMap

// MergeSink<SourceElement, DerivedSequence, Observer>
private final actor FlatMapSink<
    SourceElement: Sendable,
    DerivedSequence: ObservableConvertibleType,
    Observer: ObserverType
>: MergeSink, ObserverType where DerivedSequence.Element == Observer.Element {

    typealias Element = SourceElement

    typealias Selector = (Element) throws -> DerivedSequence

    private let selector: Selector
    let baseSink: MergeSinkBase<SourceElement, DerivedSequence, Observer>

    init(selector: @escaping Selector, observer: Observer) {
        self.selector = selector
        baseSink = MergeSinkBase(observer: observer)
    }

    var activeCount = 0
    var sourceHasStopped = false

    func on(_ event: Event<SourceElement>, _ c: C) async {
        if baseSink.disposed {
            rxAssertExpectedNoEventsAfterDisposal()
            return
        }
        switch event {
        case .next(let element):
            let derivedSequence: DerivedSequence
            do {
                let value = try selector(element)
                activeCount += 1
                derivedSequence = value
            } catch let e {
                await self.baseSink.observer.on(.error(e), c.call())
                await self.dispose()
                return
            }

            await subscribeInner(derivedSequence.asObservable(), c.call())
        case .error(let error):
            await baseSink.observer.on(.error(error), c.call())
            await dispose()
        case .completed:
            sourceHasStopped = true
            await baseSink.sourceSubscription.dispose()
            await checkCompleted(c.call())
        }
    }

    func subscribeInner(_ source: Observable<Observer.Element>, _ c: C) async {
        let iterDisposable = SingleAssignmentDisposable()
        if let disposeKey = await baseSink.derivedSubscriptions.insert(iterDisposable) {
            let iter = MergeSinkIter(parent: self, disposeKey: disposeKey)
            let subscription = await source.subscribe(c.call(), iter)
            await iterDisposable.setDisposable(subscription)
        }
    }

    func derivedEventArrived(
        _ disposeKey: CompositeDisposable.DisposeKey,
        _ event: Event<Observer.Element>,
        _ c: C
    )
        async {
        if baseSink.disposed {
            rxAssertExpectedNoEventsAfterDisposal()
            return
        }

        switch event {
        case .next(let value):
            await baseSink.observer.on(.next(value), c.call())
        case .error(let error):
            await baseSink.observer.on(.error(error), c.call())
            await dispose()
        case .completed:
            activeCount -= 1
            await baseSink.derivedSubscriptions.removeReturning(for: disposeKey)?.dispose()

            await checkCompleted(c.call())
        }
    }

    func run(_ source: Observable<Element>, _ c: C) async {
        await baseSink.run(self, source, c.call())
    }

    func checkCompleted(_ c: C) async {
        if sourceHasStopped, activeCount == 0 {
            await baseSink.observer.on(.completed, c.call())
            await dispose()
        }
    }

    func dispose() async {
        setDisposed()
        await baseSink.disposeAfterSettingDisposed()
    }
}

// MARK: FlatMapFirst

private final actor FlatMapFirstSink<
    SourceElement: Sendable,
    DerivedSequence: ObservableConvertibleType,
    Observer: ObserverType
>: MergeSink, ObserverType where Observer.Element == DerivedSequence.Element {
    typealias Selector = (SourceElement) throws -> DerivedSequence

    typealias Element = SourceElement

    private let selector: Selector

    private var waitingOnADerivedSequence = false
    private var sourceStopped = false
    let baseSink: MergeSinkBase<SourceElement, DerivedSequence, Observer>

    init(selector: @escaping Selector, observer: Observer) {
        self.selector = selector
        baseSink = MergeSinkBase(observer: observer)
    }

    func run(_ c: C, _ source: Observable<SourceElement>) async {
        await baseSink.run(self, source, c.call())
    }

    func on(_ event: Event<Element>, _ c: C) async {
        if baseSink.disposed {
            return
        }

        switch event {
        case .next(let element):
            if waitingOnADerivedSequence {
                // nothing
                return
            }

            let derivedSequence: DerivedSequence
            do {
                derivedSequence = try selector(element)
            } catch {
                setDisposed()
                await baseSink.observer.onError(error, c.call())
                await baseSink.disposeAfterSettingDisposed()
                return
            }
            let disp = SingleAssignmentDisposable()
            let key = baseSink.derivedSubscriptions.insertUnchecked(disp)
            let observer = MergeSinkIter(parent: self, disposeKey: key)
            let derivedDisposable = await derivedSequence.asObservable().subscribe(c.call(), observer)

            _ = await disp.setDisposableUnchecked(derivedDisposable)
        case .error(let error):
            setDisposed()
            await baseSink.observer.onError(error, c.call())
            await baseSink.disposeAfterSettingDisposed()
        case .completed:
            if waitingOnADerivedSequence {
                return
            }

            sourceStopped = true
            await baseSink.observer.on(.completed, c.call())
            await baseSink.disposeAfterSettingDisposed()
        }
    }

    func derivedEventArrived(
        _ disposeKey: CompositeDisposable.DisposeKey,
        _ event: Event<Observer.Element>,
        _ c: C
    )
        async {
        if baseSink.disposed {
            return
        }

        rxAssert(waitingOnADerivedSequence)

        switch event {
        case .next(let element):
            await baseSink.observer.onNext(element, c.call())
        case .error(let error):
            waitingOnADerivedSequence = false

            setDisposed()
            await baseSink.observer.onError(error, c.call())
            await baseSink.disposeAfterSettingDisposed()
        case .completed:
            waitingOnADerivedSequence = false

            if sourceStopped {
                setDisposed()

                await baseSink.observer.onCompleted(c.call())
                await baseSink.disposeAfterSettingDisposed()
            } else {
                let derivedSubscription = baseSink.derivedSubscriptions.removeReturning(for: disposeKey)
                rxAssert(derivedSubscription != nil)
                await derivedSubscription?.dispose()
            }
        }
    }

    func dispose() async {
        baseSink.setDisposed()
        await baseSink.disposeAfterSettingDisposed()
    }
}

private final class MergeSinkIter<
    TheSink: MergeSink
>: ObserverType {
    typealias Parent = TheSink
    typealias DisposeKey = CompositeDisposable.DisposeKey
    typealias Element = TheSink.DerivedSequence.Element

    private let parent: Parent
    private let disposeKey: DisposeKey

    init(parent: Parent, disposeKey: DisposeKey) {
        self.parent = parent
        self.disposeKey = disposeKey
    }

    func on(_ event: Event<Element>, _ c: C) async {
        await parent.derivedEventArrived(disposeKey, event, c.call())
    }
}

protocol MergeSink: Sink, Actor {
    associatedtype SourceElement
    associatedtype DerivedSequence: ObservableConvertibleType where DerivedSequence.Element == Observer.Element

    var baseSink: MergeSinkBase<SourceElement, DerivedSequence, Observer> { get }

    func derivedEventArrived(
        _ disposeKey: CompositeDisposable.DisposeKey,
        _ event: Event<Observer.Element>,
        _ c: C
    ) async
}

final class MergeSinkBase<
    SourceElement,
    ResultingSequence: ObservableConvertibleType,
    Observer: ObserverType
>: BaseSinkProtocol, @unchecked Sendable {
    // Base Sink Protocol
    let baseSink: BaseSink<Observer>

    init(observer: Observer) {
        derivedSubscriptions = UnsynchronizedCompositeDisposable(disposables: [])
        sourceSubscription = SingleAssignmentDisposable()
        baseSink = BaseSink(observer: observer)
    }

    func setDisposed() {
        baseSink.setDisposed()
    }

    var observer: Observer {
        baseSink.observer
    }

    // MARK: - Actual merge sink

    typealias ResultType = Observer.Element
    typealias Element = SourceElement

    // state
    let derivedSubscriptions: UnsynchronizedCompositeDisposable
    let sourceSubscription: SingleAssignmentDisposable

    func run<SourceObserver: ObserverType>(
        _ observer: SourceObserver,
        _ source: Observable<SourceElement>,
        _ c: C
    )
        async where SourceObserver.Element == SourceElement {
        let subscription = await source.subscribe(c.call(), observer)
        await sourceSubscription.setDisposable(subscription)
    }

    var disposed: Bool {
        baseSink.disposed
    }

    func disposeAfterSettingDisposed() async {
        assert(baseSink.disposed)
        await derivedSubscriptions.dispose()
        await sourceSubscription.dispose()
    }
}

// private class MergeSink<SourceElement, DerivedSequence: ObservableConvertibleType, Observer: ObserverType>:
//    ObserverType where Observer.Element == DerivedSequence.Element {
//    typealias ResultType = Observer.Element
//    typealias Element = SourceElement
//
//    let lock: RecursiveLock
//
//    var subscribeNext: Bool {
//        true
//    }
//
//    let baseSink: BaseSink<Observer>
//
//    // state
//    let group: CompositeDisposable
//    let sourceSubscription: SingleAssignmentDisposable
//
//    var activeCount = 0
//    var sourceHasStopped = false
//
//    override init(observer: Observer) async {
//        lock = await RecursiveLock()
//        group = await CompositeDisposable()
//        sourceSubscription = await SingleAssignmentDisposable()
//        baseSink = BaseSink(observer: observer)
//    }
//
//    func performMap(_ element: SourceElement) async throws -> DerivedSequence {
//        rxAbstractMethod()
//    }
//
//    @inline(__always)
//    private final func nextElementArrived(element: SourceElement, _ c: C) async -> DerivedSequence? {
//        await lock.performLocked {
//            if !self.subscribeNext {
//                return nil
//            }
//
//            do {
//                let value = try await self.performMap(element)
//                self.activeCount += 1
//                return value
//            } catch let e {
//                await self.forwardOn(.error(e), c.call())
//                await self.dispose()
//                return nil
//            }
//        }
//    }
//
//    func on(_ event: Event<SourceElement>, _ c: C) async {
//        switch event {
//        case .next(let element):
//            if let value = await nextElementArrived(element: element, c.call()) {
//                await subscribeInner(value.asObservable(), c.call())
//            }
//        case .error(let error):
//            await lock.performLocked {
//                await self.forwardOn(.error(error), c.call())
//                await self.dispose()
//            }
//        case .completed:
//            await lock.performLocked {
//                self.sourceHasStopped = true
//                await self.sourceSubscription.dispose()
//                await self.checkCompleted(c.call())
//            }
//        }
//    }
//
//    func subscribeInner(_ source: Observable<Observer.Element>, _ c: C) async {
//        let iterDisposable = await SingleAssignmentDisposable()
//        if let disposeKey = await group.insert(iterDisposable) {
//            let iter = MergeSinkIter(parent: self, disposeKey: disposeKey)
//            let subscription = await source.subscribe(c.call(), iter)
//            await iterDisposable.setDisposable(subscription)
//        }
//    }
//
//    func run(_ sources: [Observable<Observer.Element>], _ c: C) async -> Disposable {
//        activeCount += sources.count
//
//        for source in sources {
//            await subscribeInner(source, c.call())
//        }
//
//        sourceHasStopped = true
//
//        await checkCompleted(c.call())
//
//        return group
//    }
//
//    @inline(__always)
//    func checkCompleted(_ c: C) async {
//        if sourceHasStopped, activeCount == 0 {
//            await forwardOn(.completed, c.call())
//            await dispose()
//        }
//    }
//
//    func run(_ source: Observable<SourceElement>, _ c: C) async -> Disposable {
//        _ = await group.insert(sourceSubscription)
//
//        let subscription = await source.subscribe(c.call(), self)
//        await sourceSubscription.setDisposable(subscription)
//
//        return group
//    }
// }

//// MARK: Producers
//
private final class FlatMap<
    Element: Sendable,
    DerivedSequence: ObservableConvertibleType
>: Producer<DerivedSequence.Element> {
    typealias Selector = @Sendable (Element) throws -> DerivedSequence

    private let source: Observable<Element>

    private let selector: Selector

    init(source: Observable<Element>, selector: @escaping Selector) {
        self.source = source
        self.selector = selector
        super.init()
    }

    override func run<Observer: ObserverType>(
        _ c: C,
        _ observer: Observer
    )
        async -> AsynchronousDisposable
        where Observer.Element == DerivedSequence.Element {
        let sink = FlatMapSink(selector: selector, observer: observer)
        await sink.run(source, c.call())
        return sink
    }
}

private final class FlatMapFirst<
    SourceElement: Sendable,
    DerivedSequence: ObservableConvertibleType
>: Producer<DerivedSequence.Element> {
    typealias Selector = @Sendable (SourceElement) throws -> DerivedSequence

    private let source: Observable<SourceElement>

    private let selector: Selector

    init(source: Observable<SourceElement>, selector: @escaping Selector) {
        self.source = source
        self.selector = selector
        super.init()
    }

    override func run<Observer>(_ c: C, _ observer: Observer) async -> any AsynchronousDisposable
        where DerivedSequence.Element == Observer.Element, Observer: ObserverType {
        let sink = FlatMapFirstSink<SourceElement, DerivedSequence, Observer>(
            selector: selector,
            observer: observer
        )
        await sink.run(c.call(), source)
        return sink
    }
}

//
// final class ConcatMap<SourceElement, DerivedSequence: ObservableConvertibleType>: Producer<DerivedSequence.Element> {
//    typealias Selector = (SourceElement) throws -> DerivedSequence
//
//    private let source: Observable<SourceElement>
//    private let selector: Selector
//
//    init(source: Observable<SourceElement>, selector: @escaping Selector) async {
//        self.source = source
//        self.selector = selector
//        await super.init()
//    }
//
//    override func run<Observer: ObserverType>(
//        _ c: C,
//        _ observer: Observer,
//        cancel: Cancelable
//    )
//        async -> (sink: Disposable, subscription: Disposable)
//        where Observer.Element == DerivedSequence.Element {
//        let sink = await ConcatMapSink<SourceElement, DerivedSequence, Observer>(
//            selector: selector,
//            observer: observer,
//            cancel: cancel
//        )
//        let subscription = await sink.run(source, c.call())
//        return sink
//    }
// }
//
// final class Merge<DerivedSequence: ObservableConvertibleType>: Producer<DerivedSequence.Element> {
//    private let source: Observable<DerivedSequence>
//
//    init(source: Observable<DerivedSequence>) async {
//        self.source = source
//        await super.init()
//    }
//
//    override func run<Observer: ObserverType>(
//        _ c: C,
//        _ observer: Observer,
//        cancel: Cancelable
//    )
//        async -> (sink: Disposable, subscription: Disposable)
//        where Observer.Element == DerivedSequence.Element {
//        let sink = await MergeBasicSink<DerivedSequence, Observer>(observer: observer)
//        let subscription = await sink.run(source, c.call())
//        return sink
//    }
// }

private final class MergeArray<Element: Sendable>: Producer<Element> {
    private let sources: [Observable<Element>]

    init(sources: [Observable<Element>]) {
        self.sources = sources
        super.init()
    }

    override func run<Observer>(_ c: C, _ observer: Observer) async -> any AsynchronousDisposable
        where Element == Observer.Element, Observer: ObserverType {
        let sink = MergeBasicSink<Observable<Element>, Observer>(observer: observer)
        let subscription = await sink.run(sources, c.call())
        return sink
    }
}
