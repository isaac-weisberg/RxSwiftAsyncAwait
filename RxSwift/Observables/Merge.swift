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

public extension ObservableType where Element: ObservableConvertibleType {
    /**
     Merges elements from all observable sequences in the given enumerable sequence into a single observable sequence.

     - seealso: [merge operator on reactivex.io](http://reactivex.io/documentation/operators/merge.html)

     - returns: The observable sequence that merges the elements of the observable sequences.
     */
    func merge() -> Observable<Element.Element> {
        Merge(source: asObservable())
    }

    /**
     Merges elements from all inner observable sequences into a single observable sequence, limiting the number of
     concurrent subscriptions to inner sequences.

     - seealso: [merge operator on reactivex.io](http://reactivex.io/documentation/operators/merge.html)

     - parameter maxConcurrent: Maximum number of inner observable sequences being subscribed to concurrently.
     - returns: The observable sequence that merges the elements of the inner sequences.
     */
    func merge(maxConcurrent: Int)
        -> Observable<Element.Element> {
        MergeLimited<Element, Element>(
            source: asObservable(),
            selector: { $0 },
            maxConcurrent: maxConcurrent
        )
    }
}

public extension ObservableType where Element: ObservableConvertibleType {
    /**
     Concatenates all inner observable sequences, as long as the previous observable sequence terminated successfully.

     - seealso: [concat operator on reactivex.io](http://reactivex.io/documentation/operators/concat.html)

     - returns: An observable sequence that contains the elements of each observed inner sequence, in sequential
     order.
     */
    func concat() -> Observable<Element.Element> {
        merge(maxConcurrent: 1)
    }
}

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

// MARK: concatMap

public extension ObservableType {
    /**
     Projects each element of an observable sequence to an observable sequence and concatenates the resulting
     observable sequences into one observable sequence.

     - seealso: [concat operator on reactivex.io](http://reactivex.io/documentation/operators/concat.html)

     - returns: An observable sequence that contains the elements of each observed inner sequence, in sequential
     order.
     */

    func concatMap<Source: ObservableConvertibleType>(_ selector: @Sendable @escaping (Element) throws -> Source)
        -> Observable<Source.Element> {
        ConcatMap(source: asObservable(), selector: selector)
    }
}

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

final actor TotalFlatMapSink<
    Source: Sendable,
    DerivedSequence: ObservableConvertibleType,
    Observer: ObserverType
>: Disposable
    where Observer.Element == DerivedSequence.Element {

    typealias FlatMapSelector = @Sendable (Source) throws -> DerivedSequence

    enum Mode: Sendable {
        struct FlatMap {
            let source: Observable<Source>
            let selector: FlatMapSelector
        }

        struct FlatMapLimited {
            let source: Observable<Source>
            let maxConcurrent: Int
            let selector: FlatMapSelector
        }

        case flatMap(FlatMap)
        case flatMapFirst(FlatMap)
        case flatMapLatest(FlatMap)
        case mergeArray([DerivedSequence])
        case flatMapLimited(FlatMapLimited)
    }

    let mode: Mode
    let observer: Observer

    init(mode: Mode, observer: Observer) {
        self.mode = mode
        self.observer = observer
    }

    private enum Input {
        enum Run {
            case singleSource(Observable<Source>)
            case multipleDerives([DerivedSequence])
        }

        case run(Run)
        case sourceEvent(Event<Source>)
        case derivedEvent(Event<DerivedSequence.Element>, SingleAssignmentDisposable)
        case dispose
    }

    private enum Action: @unchecked Sendable {
        case subscribeToSource(Observable<Source>, SingleAssignmentDisposable)
        case subscribeToDerived(DerivedSequence, SingleAssignmentDisposable)
        case forwardEvent(Event<DerivedSequence.Element>)
        case dispose(Disposable)
    }

    private struct ActionWithC: Sendable {
        let c: C
        let action: Action
    }

    private typealias DerivedSubscription = IdentityHashable<SingleAssignmentDisposable>
    private typealias DerivedSubscriptions = Set<DerivedSubscription>
    private typealias DerivedSequenceQueue = Queue<DerivedSequence>

    private struct State {
        init(
            stage: Stage,
            sourceSubscription: SourceSubscription,
            derivedSubscriptions: DerivedSubscriptions,
            queuedDerivedSubscriptions: DerivedSequenceQueue?
        ) {
            self.stage = stage
            self.sourceSubscription = sourceSubscription
            self.derivedSubscriptions = derivedSubscriptions
            self.queuedDerivedSubscriptions = queuedDerivedSubscriptions
        }

        enum Stage {
            case neverRun
            case running
            case disposed
        }

        enum SourceSubscription {
            case neverUsed
            case active(SingleAssignmentDisposable)
            case released

            func isRunning() -> Bool {

                let sourceIsDone: Bool

                switch self {
                case .neverUsed:
                    sourceIsDone = true
                case .active(let disposableBox):
                    rxAssert(!disposableBox.isDisposed) // when I dispose, I release the box
                    sourceIsDone = false
                case .released:
                    sourceIsDone = true
                }
                return sourceIsDone
            }
        }

        var stage: Stage = .neverRun
        var sourceSubscription: SourceSubscription = .neverUsed
        var derivedSubscriptions: DerivedSubscriptions
        var queuedDerivedSubscriptions: DerivedSequenceQueue?
    }

    func run(_ c: C) async {
        switch mode {
        case .flatMap(let flatMap), .flatMapFirst(let flatMap), .flatMapLatest(let flatMap):
            await acceptInput(c.call(), .run(.singleSource(flatMap.source)))

        case .flatMapLimited(let mergeLimited):
            await acceptInput(c.call(), .run(.singleSource(mergeLimited.source)))

        case .mergeArray(let derivedSequences):
            await acceptInput(c.call(), .run(.multipleDerives(derivedSequences)))
        }
    }

    func acceptSourceEvent(_ c: C, _ event: Event<Source>) async {
        await acceptInput(c.call(), .sourceEvent(event))
    }

    func acceptDerivedEvent(
        _ c: C,
        _ event: Event<DerivedSequence.Element>,
        _ subscription: SingleAssignmentDisposable
    )
        async {
        await acceptInput(c.call(), .derivedEvent(event, subscription))
    }

    func dispose() async {
        await acceptInput(C(), .dispose)
    }

    private var state = State(
        stage: .neverRun,
        sourceSubscription: .neverUsed,
        derivedSubscriptions: Set(),
        queuedDerivedSubscriptions: nil
    )

    private func acceptInput(_ c: C, _ input: Input) async {
        let (state, actions) = reduce(c.call(), state, input)

        self.state = state

        if actions.isEmpty {
            return
        }
        await performActions(actions)
    }

    private func reduce(_ c: C, _ state: State, _ input: Input) -> (State, [ActionWithC]) {
        if state.stage == .disposed {
            return (state, [])
        }

        switch input {
        case .run(let run):
            rxAssert(state.stage == .neverRun)
            rxAssert(state.derivedSubscriptions.isEmpty)

            switch run {
            case .singleSource(let source):
                let queuedDerivedSubscriptions: DerivedSequenceQueue?

                switch mode {
                case .flatMap, .flatMapFirst, .mergeArray, .flatMapLatest:
                    queuedDerivedSubscriptions = nil
                case .flatMapLimited:
                    queuedDerivedSubscriptions = DerivedSequenceQueue(capacity: 2)
                }

                let disposable = SingleAssignmentDisposable()
                let state = State(
                    stage: .running,
                    sourceSubscription: .active(disposable),
                    derivedSubscriptions: state.derivedSubscriptions,
                    queuedDerivedSubscriptions: queuedDerivedSubscriptions
                )
                let actions = [
                    ActionWithC(c: c.call(), action: Action.subscribeToSource(source, disposable)),
                ]

                return (state, actions)
            case .multipleDerives(let derives):
                var actions: [ActionWithC] = []
                actions.reserveCapacity(derives.count)
                var derivedSubscriptions = DerivedSubscriptions()
                derivedSubscriptions.reserveCapacity(derives.count)

                for derive in derives {
                    let disposable = SingleAssignmentDisposable()
                    actions.append(ActionWithC(c: c.call(), action: .subscribeToDerived(derive, disposable)))
                    derivedSubscriptions.insert(DerivedSubscription(inner: disposable))
                }

                let state = State(
                    stage: .running,
                    sourceSubscription: .neverUsed,
                    derivedSubscriptions: derivedSubscriptions,
                    queuedDerivedSubscriptions: nil
                )

                return (state, actions)
            }

        case .sourceEvent(let event):

            return stateAndActionForSourceEvent(c.call(), event)

        case .derivedEvent(let event, let disposableBox):

            return stateAndActionForDerivedEvent(c.call(), event, disposableBox: disposableBox)

        case .dispose:

            // MARK: dispose

            let sourceSubscriptionsActions: [ActionWithC]
            let sourceSubscription = state.sourceSubscription
            switch sourceSubscription {
            case .active(let sourceSubscription):
                rxAssert(!sourceSubscription.isDisposed) // should've been released already

                let sourceDisposable = sourceSubscription.dispose()
                if let sourceDisposable {
                    // nice, it was running, but time to dispose
                    sourceSubscriptionsActions = [
                        ActionWithC(
                            c: c.call(),
                            action: .dispose(sourceDisposable)
                        ),
                    ]
                } else {
                    // will be assigned when source's subscribe will return
                    sourceSubscriptionsActions = []
                }
            case .neverUsed, .released:
                sourceSubscriptionsActions = []
            }

            var derivedSubscriptionsActions: [ActionWithC] = []
            derivedSubscriptionsActions.reserveCapacity(state.derivedSubscriptions.count)
            for derivedSubscription in state.derivedSubscriptions {
                rxAssert(
                    !derivedSubscription.inner.isDisposed
                ) // when I made it disposed, I removed it from the set, so...

                if let disposable = derivedSubscription.inner.dispose() {
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

            let totalActions = sourceSubscriptionsActions + derivedSubscriptionsActions

            let state = State(
                stage: .disposed,
                sourceSubscription: .released,
                derivedSubscriptions: Set(),
                queuedDerivedSubscriptions: nil
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
            await disposableBox.setDisposable(disposable)?.dispose()
        case .subscribeToDerived(let derivedSequence, let disposableBox):
            let observer = TotalMergeSinkDerivedObserver(sink: self, disposable: disposableBox)
            let disposable = await derivedSequence.asObservable().subscribe(c.call(), observer)
            await disposableBox.setDisposable(disposable)?.dispose()
        case .dispose(let disposable):
            await disposable.dispose()
        case .forwardEvent(let event):
            await observer.on(event, c.call())
        }
    }

    private func stateAndActionForSourceEvent(_ c: C, _ event: Event<Source>) -> (State, [ActionWithC]) {
        rxAssert(state.stage == .running)

        switch event {
        case .next(let element):
            let newState: State
            let actions: [ActionWithC]

            switch mode {

            case .flatMap(let flatMap):
                let derivedSequenceToSubscribeTo: DerivedSequence
                do {
                    derivedSequenceToSubscribeTo = try flatMap.selector(element)
                } catch {
                    return stateAndActionForEveryErrorCase(c.call(), error)
                }
                let disposable = SingleAssignmentDisposable()
                actions = [
                    ActionWithC(c: c.call(), action: .subscribeToDerived(derivedSequenceToSubscribeTo, disposable)),
                ]
                newState = State(
                    stage: .running,
                    sourceSubscription: state.sourceSubscription,
                    derivedSubscriptions: state.derivedSubscriptions.inserting(DerivedSubscription(inner: disposable)),
                    queuedDerivedSubscriptions: state.queuedDerivedSubscriptions
                )

            case .flatMapLatest(let flatMap):
                let derivedSequenceToSubscribeTo: DerivedSequence
                do {
                    derivedSequenceToSubscribeTo = try flatMap.selector(element)
                } catch {
                    return stateAndActionForEveryErrorCase(c.call(), error)
                }

                rxAssert(state.derivedSubscriptions.count <= 1)

                let derivedSubscriptionsAfterDisposal: DerivedSubscriptions
                let disposeActions: [ActionWithC]
                if let firstDerivedSubscription = state.derivedSubscriptions.first {
                    derivedSubscriptionsAfterDisposal = state.derivedSubscriptions
                        .removing(firstDerivedSubscription)
                    if let disposable = firstDerivedSubscription.inner.dispose() {
                        disposeActions = [
                            ActionWithC(c: c.call(), action: .dispose(disposable)),
                        ]
                    } else {
                        disposeActions = []
                    }
                } else {
                    derivedSubscriptionsAfterDisposal = state.derivedSubscriptions
                    disposeActions = []
                }

                let disposable = SingleAssignmentDisposable()
                let subscribeAction = [
                    ActionWithC(c: c.call(), action: .subscribeToDerived(derivedSequenceToSubscribeTo, disposable)),
                ]
                let derivedSubscriptions = derivedSubscriptionsAfterDisposal
                    .inserting(DerivedSubscription(inner: disposable))

                actions = disposeActions + subscribeAction
                newState = State(
                    stage: .running,
                    sourceSubscription: state.sourceSubscription,
                    derivedSubscriptions: derivedSubscriptions,
                    queuedDerivedSubscriptions: state.queuedDerivedSubscriptions
                )

            case .flatMapFirst(let flatMap):
                let thereAreNoDerivedSubscriptionsRunning: Bool
                rxAssert(state.derivedSubscriptions.count <= 1)
                if let firstDerivedSubscription = state.derivedSubscriptions.first {
                    rxAssert(!firstDerivedSubscription.inner.isDisposed)
                    thereAreNoDerivedSubscriptionsRunning = false
                } else {
                    thereAreNoDerivedSubscriptionsRunning = true
                }

                let shouldSubscribe = thereAreNoDerivedSubscriptionsRunning

                if shouldSubscribe {
                    let derivedSequenceToSubscribeTo: DerivedSequence
                    do {
                        derivedSequenceToSubscribeTo = try flatMap.selector(element)
                    } catch {
                        return stateAndActionForEveryErrorCase(c.call(), error)
                    }

                    let disposable = SingleAssignmentDisposable()

                    actions = [
                        ActionWithC(c: c.call(), action: .subscribeToDerived(derivedSequenceToSubscribeTo, disposable)),
                    ]

                    newState = State(
                        stage: .running,
                        sourceSubscription: state.sourceSubscription,
                        derivedSubscriptions: state.derivedSubscriptions
                            .inserting(DerivedSubscription(inner: disposable)),
                        queuedDerivedSubscriptions: state.queuedDerivedSubscriptions
                    )

                } else {
                    actions = []
                    newState = state
                }

            case .flatMapLimited(let mergeLimited):
                rxAssert(state.queuedDerivedSubscriptions != nil)
                let derivedSequence: DerivedSequence
                do {
                    derivedSequence = try mergeLimited.selector(element)
                } catch {
                    return stateAndActionForEveryErrorCase(c.call(), error)
                }

                let numberOfActiveSubscriptions = state.derivedSubscriptions.count

                let shouldSubscribe = numberOfActiveSubscriptions < mergeLimited.maxConcurrent

                if shouldSubscribe {
                    let disposable = SingleAssignmentDisposable()

                    actions = [
                        ActionWithC(c: c.call(), action: .subscribeToDerived(derivedSequence, disposable)),
                    ]
                    newState = State(
                        stage: .running,
                        sourceSubscription: state.sourceSubscription,
                        derivedSubscriptions: state.derivedSubscriptions
                            .inserting(DerivedSubscription(inner: disposable)),
                        queuedDerivedSubscriptions: state.queuedDerivedSubscriptions
                    )
                } else {
                    actions = []
                    newState = State(
                        stage: .running,
                        sourceSubscription: state.sourceSubscription,
                        derivedSubscriptions: state.derivedSubscriptions,
                        queuedDerivedSubscriptions: state.queuedDerivedSubscriptions!.enqueing(derivedSequence)
                    )
                }

            case .mergeArray:
                fatalError() // source can't emit in merge mode
            }

            return (newState, actions)

        case .error(let error):
            return stateAndActionForEveryErrorCase(c.call(), error)

        case .completed:
            let sourceSubscription: SingleAssignmentDisposable
            switch state.sourceSubscription {
            case .neverUsed, .released:
                fatalError() // Source completed, yet there is no source? lole
            case .active(let singleAssignmentDisposable):
                sourceSubscription = singleAssignmentDisposable
            }

            let sourceDisposalActions: [ActionWithC]
            if let existingSourceDisposable = sourceSubscription.dispose() {
                sourceDisposalActions = [
                    ActionWithC(c: c.call(), action: .dispose(existingSourceDisposable)),
                ]
            } else {
                // subscribe must've not returned yet
                sourceDisposalActions = []
            }

            let theWholeProcessIsDone = state.derivedSubscriptions.isEmpty

            if theWholeProcessIsDone {
                let emitCompletedAction = ActionWithC(c: c.call(), action: .forwardEvent(.completed))
                let state = State(
                    stage: .disposed,
                    sourceSubscription: .released,
                    derivedSubscriptions: Set(),
                    queuedDerivedSubscriptions: nil
                )

                let actions = [emitCompletedAction] + sourceDisposalActions

                return (state, actions)
            } else {
                let state = State(
                    stage: .running,
                    sourceSubscription: .released,
                    derivedSubscriptions: state.derivedSubscriptions,
                    queuedDerivedSubscriptions: state.queuedDerivedSubscriptions
                )

                return (state, sourceDisposalActions)
            }
        }
    }

    private func stateAndActionForDerivedEvent(
        _ c: C,
        _ event: Event<DerivedSequence.Element>,
        disposableBox: SingleAssignmentDisposable
    ) -> (State, [ActionWithC]) {

        switch event {
        case .next(let element):
            let forwardOnAction = ActionWithC(c: c.call(), action: .forwardEvent(.next(element)))

            let state = State(
                stage: .running,
                sourceSubscription: state.sourceSubscription,
                derivedSubscriptions: state.derivedSubscriptions,
                queuedDerivedSubscriptions: state.queuedDerivedSubscriptions
            )
            return (state, [forwardOnAction])

        case .error(let error):
            return stateAndActionForEveryErrorCase(c.call(), error)

        case .completed:
            let derivedSubsAfterRemovingCurrent = state.derivedSubscriptions
                .removing(IdentityHashable(inner: disposableBox))

            let disposeActions: [ActionWithC]
            if let disposable = disposableBox.dispose() {
                disposeActions = [
                    ActionWithC(
                        c: c.call(),
                        action: .dispose(disposable)
                    ),
                ]

            } else {
                disposeActions = []
                // subscribe must ve not returned yet, it's okay
            }

            let queuedDerivedSubscriptions: DerivedSequenceQueue?
            let newSubscribeActions: [ActionWithC]
            let derivedSubscriptionsAfterPotentialDequeue: DerivedSubscriptions

            switch mode {
            case .flatMapFirst, .mergeArray, .flatMap, .flatMapLatest:
                queuedDerivedSubscriptions = nil
                newSubscribeActions = []
                derivedSubscriptionsAfterPotentialDequeue = derivedSubsAfterRemovingCurrent
            case .flatMapLimited(let mergeLimited):
                var newQueue = state.queuedDerivedSubscriptions
                if let dequeuedDerviedSubscription = newQueue?.dequeue() {
                    let disposable = SingleAssignmentDisposable()
                    derivedSubscriptionsAfterPotentialDequeue = derivedSubsAfterRemovingCurrent
                        .inserting(DerivedSubscription(inner: disposable))
                    newSubscribeActions = [
                        ActionWithC(
                            c: c.call(),
                            action: .subscribeToDerived(dequeuedDerviedSubscription, disposable)
                        ),
                    ]
                } else {
                    derivedSubscriptionsAfterPotentialDequeue = derivedSubsAfterRemovingCurrent
                    newSubscribeActions = []
                }
                queuedDerivedSubscriptions = newQueue
            }

            let newDerivedSubscriptions = derivedSubscriptionsAfterPotentialDequeue

            let sourceIsDone = !state.sourceSubscription.isRunning()
            let theWholeSinkIsDone = sourceIsDone && newDerivedSubscriptions.isEmpty

            if theWholeSinkIsDone {
                let emitCompletedAction = ActionWithC(c: c.call(), action: .forwardEvent(.completed))
                let actions = [emitCompletedAction] + disposeActions

                let state = State(
                    stage: .disposed,
                    sourceSubscription: state.sourceSubscription,
                    derivedSubscriptions: newDerivedSubscriptions,
                    queuedDerivedSubscriptions: nil
                )

                return (state, actions)

            } else {
                let totalActions = disposeActions + newSubscribeActions
                let state = State(
                    stage: .running,
                    sourceSubscription: state.sourceSubscription,
                    derivedSubscriptions: newDerivedSubscriptions,
                    queuedDerivedSubscriptions: queuedDerivedSubscriptions
                )

                return (state, totalActions)
            }
        }
    }

    private func stateAndActionForEveryErrorCase(_ c: C, _ error: Error) -> (State, [ActionWithC]) {
        let errorEventAction = ActionWithC(c: c.call(), action: .forwardEvent(.error(error)))

        let sourceDisposeActions: [ActionWithC]
        switch state.sourceSubscription {
        case .neverUsed, .released:
            sourceDisposeActions = []
        case .active(let singleAssignmentDisposable):
            if let disposable = singleAssignmentDisposable.dispose() {
                sourceDisposeActions = [
                    ActionWithC(c: c.call(), action: .dispose(disposable)),
                ]
            } else {
                // subscribe hasn't finished yet
                sourceDisposeActions = []
            }
        }

        let derivedDisposeActions = state.derivedSubscriptions.compactMap { box in
            if let disposable = box.inner.dispose() {
                return ActionWithC(c: c.call(), action: .dispose(disposable))
            }
            return nil
        }

        let allActions = [errorEventAction] + sourceDisposeActions + derivedDisposeActions

        let state = State(
            stage: .disposed,
            sourceSubscription: .released,
            derivedSubscriptions: Set(),
            queuedDerivedSubscriptions: nil
        )
        return (state, allActions)
    }
}

private final class TotalMergeSinkSourceObserver<
    Source: Sendable,
    DerivedSequence: ObservableConvertibleType,
    Observer: ObserverType
>: ObserverType where Observer.Element == DerivedSequence.Element {
    typealias Element = Source

    fileprivate let sink: TotalFlatMapSink<Source, DerivedSequence, Observer>

    fileprivate init(sink: TotalFlatMapSink<Source, DerivedSequence, Observer>) {
        self.sink = sink
    }

    func on(_ event: Event<Source>, _ c: C) async {
        await sink.acceptSourceEvent(c.call(), event)
    }
}

private final class TotalMergeSinkDerivedObserver<
    Source: Sendable,
    DerivedSequence: ObservableConvertibleType,
    Observer: ObserverType
>: ObserverType where Observer.Element == DerivedSequence.Element {
    typealias Element = DerivedSequence.Element

    fileprivate let sink: TotalFlatMapSink<Source, DerivedSequence, Observer>
    private let disposable: SingleAssignmentDisposable

    fileprivate init(
        sink: TotalFlatMapSink<Source, DerivedSequence, Observer>,
        disposable: SingleAssignmentDisposable
    ) {
        self.sink = sink
        self.disposable = disposable
    }

    func on(_ event: Event<Element>, _ c: C) async {
        await sink.acceptDerivedEvent(c.call(), event, disposable)
    }
}

// MARK: Producers

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
        let sink = TotalFlatMapSink(
            mode: .flatMap(
                TotalFlatMapSink.Mode.FlatMap(
                    source: source,
                    selector: selector
                )
            ),
            observer: observer
        )
        await sink.run(c.call())
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
        let sink = TotalFlatMapSink(
            mode: .flatMapFirst(
                TotalFlatMapSink.Mode.FlatMap(
                    source: source,
                    selector: selector
                )
            ),
            observer: observer
        )
        await sink.run(c.call())
        return sink
    }
}

private final class ConcatMap<
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
        let sink = TotalFlatMapSink<SourceElement, DerivedSequence, Observer>(
            mode: TotalFlatMapSink.Mode.flatMapLimited(TotalFlatMapSink.Mode.FlatMapLimited(
                source: source,
                maxConcurrent: 1,
                selector: selector
            )),
            observer: observer
        )
        await sink.run(c.call())
        return sink
    }

}

private final class Merge<DerivedSequence: ObservableConvertibleType>: Producer<DerivedSequence.Element> {
    private let source: Observable<DerivedSequence>

    init(source: Observable<DerivedSequence>) {
        self.source = source
        super.init()
    }

    override func run<Observer>(_ c: C, _ observer: Observer) async -> any AsynchronousDisposable
        where DerivedSequence.Element == Observer.Element, Observer: ObserverType {
        let sink = TotalFlatMapSink<DerivedSequence, DerivedSequence, Observer>(
            mode: .flatMap(
                TotalFlatMapSink.Mode.FlatMap(
                    source: source,
                    selector: { $0 }
                )
            ),
            observer: observer
        )
        await sink.run(c.call())
        return sink
    }

}

private final class MergeArray<Element: Sendable>: Producer<Element> {
    private let sources: [Observable<Element>]

    init(sources: [Observable<Element>]) {
        self.sources = sources
        super.init()
    }

    override func run<Observer>(_ c: C, _ observer: Observer) async -> any AsynchronousDisposable
        where Element == Observer.Element, Observer: ObserverType {
        let sink = TotalFlatMapSink<Never, Observable<Element>, Observer>(
            mode: .mergeArray(sources),
            observer: observer
        )
        await sink.run(c.call())
        return sink
    }
}

private final class MergeLimited<
    Source: Sendable,
    DerivedSequence: ObservableConvertibleType
>: Producer<DerivedSequence.Element> {
    typealias Selector = @Sendable (Source) throws -> DerivedSequence
    private let source: Observable<Source>
    private let selector: Selector
    private let maxConcurrent: Int

    init(source: Observable<Source>, selector: @escaping Selector, maxConcurrent: Int) {
        self.source = source
        self.selector = selector
        self.maxConcurrent = maxConcurrent
        super.init()
    }

    override func run<Observer>(_ c: C, _ observer: Observer) async -> any AsynchronousDisposable
        where DerivedSequence.Element == Observer.Element, Observer: ObserverType {
        let sink = TotalFlatMapSink(
            mode: .flatMapLimited(TotalFlatMapSink.Mode.FlatMapLimited(
                source: source,
                maxConcurrent: maxConcurrent,
                selector: selector
            )),
            observer: observer
        )
        await sink.run(c.call())
        return sink
    }
}

private extension Set {
    func removing(_ elem: Element) -> Set {
        var copy = self
        copy.remove(elem)
        return copy
    }

    func inserting(_ elem: Element) -> Set {
        var copy = self
        copy.insert(elem)
        return copy
    }
}
