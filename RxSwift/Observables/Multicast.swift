//
//  Multicast.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/27/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/**
 Represents an observable wrapper that can be connected and disconnected from its underlying observable sequence.
 */
public class ConnectableObservable<Element: Sendable>:
    Observable<Element>,
    ConnectableObservableType {
    /**
     Connects the observable wrapper to its source. All subscribed observers will receive values from the underlying observable sequence as long as the connection is established.

     - returns: Disposable used to disconnect the observable wrapper from its source, causing subscribed observer to stop receiving values from the underlying observable sequence.
     */
    public func connect(_ c: C) async -> Disposable {
        rxAbstractMethod()
    }
}

// hopefully no one fucking uses this operator
public extension ObservableType {
    /**
     Multicasts the source sequence notifications through an instantiated subject into all uses of the sequence within a selector function.

     Each subscription to the resulting sequence causes a separate multicast invocation, exposing the sequence resulting from the selector function's invocation.

     For specializations with fixed subject types, see `publish` and `replay`.

     - seealso: [multicast operator on reactivex.io](http://reactivex.io/documentation/operators/publish.html)

     - parameter subjectSelector: Factory function to create an intermediate subject through which the source sequence's elements will be multicast to the selector function.
     - parameter selector: Selector function which can use the multicasted source sequence subject to the policies enforced by the created subject.
     - returns: An observable sequence that contains the elements of a sequence produced by multicasting the source sequence within a selector function.
     */
//    func multicast<Subject: SubjectType, Result>(
//        _ subjectSelector: @escaping () throws -> Subject,
//        selector: @escaping (Observable<Subject.Element>) throws -> Observable<Result>
//    )
//        -> Observable<Result> where Subject.Observer.Element == Element {
//        Multicast(
//            source: asObservable(),
//            subjectSelector: subjectSelector,
//            selector: selector
//        )
//    }
}

public extension ObservableType {
    /**
     Returns a connectable observable sequence that shares a single subscription to the underlying sequence.

     This operator is a specialization of `multicast` using a `PublishSubject`.

     - seealso: [publish operator on reactivex.io](http://reactivex.io/documentation/operators/publish.html)

     - returns: A connectable observable sequence that shares a single subscription to the underlying sequence.
     */
    func publish() -> ConnectableObservable<Element> {
        multicast(replayModel: EmptyReplayModel())
    }
}

public extension ObservableType {
    /**
     Returns a connectable observable sequence that shares a single subscription to the underlying sequence replaying bufferSize elements.

     This operator is a specialization of `multicast` using a `ReplaySubject`.

     - seealso: [replay operator on reactivex.io](http://reactivex.io/documentation/operators/replay.html)

     - parameter bufferSize: Maximum element count of the replay buffer.
     - returns: A connectable observable sequence that shares a single subscription to the underlying sequence.
     */
    func replay(_ bufferSize: Int)
        -> ConnectableObservable<Element> {
        multicast(replayModel: ReplayBufferModel(bufferSizeLimit: bufferSize))
    }

    /**
     Returns a connectable observable sequence that shares a single subscription to the underlying sequence replaying all elements.

     This operator is a specialization of `multicast` using a `ReplaySubject`.

     - seealso: [replay operator on reactivex.io](http://reactivex.io/documentation/operators/replay.html)

     - returns: A connectable observable sequence that shares a single subscription to the underlying sequence.
     */
    func replayAll()
        -> ConnectableObservable<Element> {
        multicast(replayModel: ReplayBufferModel(bufferSizeLimit: nil))
    }
}

public extension ConnectableObservableType {
    /**
     Returns an observable sequence that stays connected to the source as long as there is at least one subscription to the observable sequence.

     - seealso: [refCount operator on reactivex.io](http://reactivex.io/documentation/operators/refcount.html)

     - returns: An observable sequence that stays connected to the source as long as there is at least one subscription to the observable sequence.
     */
    func refCount() -> Observable<Element> {
        RefCount(source: self)
    }
}

public extension ObservableType {
    func multicast<ReplayModel: SubjectReplayModel>(replayModel: ReplayModel)
        -> ConnectableObservable<ReplayModel.Element> where ReplayModel.Element == Element {
        ConnectableObservableViaReplayModel(source: asObservable(), replayModel: replayModel)
    }
}

private final actor ConnectionSink<ReplayModel: SubjectReplayModel>: ObserverType, ObservableType, Disposable,
    AsynchronousUnsubscribeType {
    typealias Element = ReplayModel.Element
    typealias Observers = AnyObserver<Element>.s
    typealias DisposeKey = Observers.KeyType
    // state
    private let sourceSubscription = SerialPerpetualDisposable<Disposable>()
    private let source: Observable<ReplayModel.Element>

    private var connection: ConnectionDisposable?
    private var replayModel: ReplayModel
    private var observers = Observers()
    private var lastConnectionId: UInt = 0

    init(
        source: Observable<Element>,
        replayModel: ReplayModel
    ) {
        self.source = source
        self.replayModel = replayModel
    }

    func on(_ event: Event<Element>, _ c: C) async {
        if connection == nil {
            return // okay, maybe not finished disposing source
        }

        switch event {
        case .next(let element):
            replayModel.add(element: element)
            await dispatch(observers, event, c.call())
        case .completed, .error:
            await dispatch(observers, event, c.call())
            await disconnect()
        }
    }

    struct ConnectionDisposable: Disposable {
        weak var sink: ConnectionSink<ReplayModel>?
        let id: UInt

        init(sink: ConnectionSink<ReplayModel>, id: UInt) {
            self.sink = sink
            self.id = id
        }

        func dispose() async {
            await sink?.dispose(id: id)
        }
    }

    func connect(_ c: C) async -> ConnectionDisposable {
        if let connection {
            return connection
        }

        await sourceSubscription.replace(source.subscribe(c.call(), self))?.dispose()

        let connectionId = lastConnectionId + 1
        lastConnectionId = connectionId

        let disposable = ConnectionDisposable(sink: self, id: connectionId)

        return disposable
    }

    func subscribe<Observer>(_ c: C, _ observer: Observer) async -> any AsynchronousDisposable
        where Observer: ObserverType, Observer.Element == Element {

        for item in replayModel.getElementsForReplay() {
            await observer.on(.next(item), c.call())
        }
        let key = observers.insert(observer.on)
        return SubscriptionDisposable(owner: self, key: key)
    }

    func AsynchronousUnsubscribe(_ disposeKey: DisposeKey) async {
        _ = observers.removeKey(disposeKey)
    }

    func disconnect() async {
        if connection != nil {
            connection = nil
            let sourceDisposable = sourceSubscription.dispose()
            replayModel.removeAll()
            observers.removeAll()

            await sourceDisposable?.dispose()
        }
    }

    func dispose() async {
        await disconnect()
    }

    func dispose(id: UInt) async {
        if id == connection?.id {
            await dispose()
        }
    }
}

private final class ConnectableObservableViaReplayModel<ReplayModel: SubjectReplayModel>: ConnectableObservable<
    ReplayModel
        .Element
> {
    typealias Element = ReplayModel.Element

    // state
    fileprivate let connectionSink: ConnectionSink<ReplayModel>

    init(source: Observable<ReplayModel.Element>, replayModel: ReplayModel) {
        connectionSink = ConnectionSink(source: source, replayModel: replayModel)
        ObservableInit()
    }

    deinit {
        ObservableDeinit()
    }

    override func connect(_ c: C) async -> Disposable {
        await connectionSink.connect(c.call())
    }

    override func subscribe<Observer>(_ c: C, _ observer: Observer) async -> any AsynchronousDisposable
        where Observer: ObserverType, ReplayModel.Element == Observer.Element {
        await connectionSink.subscribe(c.call(), observer)
    }
}

private final actor RefCountSink<ConnectableSource: ConnectableObservableType>: Disposable {
    typealias Element = ConnectableSource.Element

    private var count = 0
    private let connectableSubscription: SerialPerpetualDisposable<Disposable>
    private let source: ConnectableSource

    init(source: ConnectableSource) {
        self.source = source
        connectableSubscription = SerialPerpetualDisposable()
    }

    func handleDisposal(_ subscription: Disposable) async {
        let newCount = count - 1
        count = newCount

        let connectDisposable: Disposable?
        if newCount == 0 {
            connectDisposable = connectableSubscription.dispose()
        } else {
            connectDisposable = nil
        }
        await subscription.dispose()
        await connectDisposable?.dispose()
    }

    func run<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> Disposable
        where Observer.Element == Element {
        count += 1

        let subscription = await source.subscribe(c.call(), observer)

        if count == 1 {
            await connectableSubscription.replace(source.connect(c.call()))?.dispose()
        }

        return Disposables.create {
            await self.handleDisposal(subscription)
        }
    }

    func dispose() async {
        await connectableSubscription.dispose()?.dispose()
    }
}

private final class RefCount<ConnectableSource: ConnectableObservableType>: Producer<ConnectableSource.Element> {

    let sink: RefCountSink<ConnectableSource>

    init(source: ConnectableSource) {
        sink = RefCountSink(source: source)
        super.init()
    }

    override func run<Observer: ObserverType>(
        _ c: C,
        _ observer: Observer
    )
        async -> AsynchronousDisposable
        where Observer.Element == ConnectableSource.Element {
        let disposable = await sink.run(c.call(), observer)
        return disposable
    }
}

// private final actor MulticastSink<Subject: SubjectType, Observer: ObserverType>: Sink, ObserverType {
//    typealias Element = Observer.Element
//    typealias ResultType = Element
//    typealias MutlicastType = Multicast<Subject, Observer.Element>
//
//    private let parent: MutlicastType
//    let baseSink: BaseSink<Observer>
//
//    init(parent: MutlicastType, observer: Observer) async {
//        self.parent = parent
//        baseSink = BaseSink(observer: observer)
//    }
//
//    func run(_ c: C) async -> Disposable {
//        do {
//            let subject = try parent.subjectSelector()
//            let connectable = await ConnectableObservableAdapter(source: parent.source, makeSubject: { subject })
//
//            let observable = try parent.selector(connectable)
//
//            let subscription = await observable.subscribe(c.call(), self)
//            let connection = await connectable.connect()
//
//            return await Disposables.create(subscription, connection)
//        } catch let e {
//            await self.forwardOn(.error(e), c.call())
//            await self.dispose()
//            return Disposables.create()
//        }
//    }
//
//    func on(_ event: Event<ResultType>, _ c: C) async {
//        await forwardOn(event, c.call())
//        switch event {
//        case .next: break
//        case .error, .completed:
//            await dispose()
//        }
//    }
// }
//
// private final class Multicast<Subject: SubjectType, Result: Sendable>: Producer<Result> {
//    typealias SubjectSelectorType = () throws -> Subject
//    typealias SelectorType = (Observable<Subject.Element>) throws -> Observable<Result>
//
//    fileprivate let source: Observable<Subject.Observer.Element>
//    fileprivate let subjectSelector: SubjectSelectorType
//    fileprivate let selector: SelectorType
//
//    init(
//        source: Observable<Subject.Observer.Element>,
//        subjectSelector: @escaping SubjectSelectorType,
//        selector: @escaping SelectorType
//    ) {
//        self.source = source
//        self.subjectSelector = subjectSelector
//        self.selector = selector
//        super.init()
//    }
//
//    override func run<Observer: ObserverType>(
//        _ c: C,
//        _ observer: Observer
//    )
//        async -> AsynchronousDisposable where Observer.Element == Result {
//        let sink = await MulticastSink(parent: self, observer: observer)
//        let subscription = await sink.run(c.call())
//        return sink
//    }
// }
