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
public class ConnectableObservable<Element>:
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
    func multicast<Subject: SubjectType, Result>(
        _ subjectSelector: @escaping () throws -> Subject,
        selector: @escaping (Observable<Subject.Element>) throws -> Observable<Result>
    )
        -> Observable<Result> where Subject.Observer.Element == Element {
        Multicast(
            source: asObservable(),
            subjectSelector: subjectSelector,
            selector: selector
        )
    }
}

public extension ObservableType {
    /**
     Returns a connectable observable sequence that shares a single subscription to the underlying sequence.

     This operator is a specialization of `multicast` using a `PublishSubject`.

     - seealso: [publish operator on reactivex.io](http://reactivex.io/documentation/operators/publish.html)

     - returns: A connectable observable sequence that shares a single subscription to the underlying sequence.
     */
    func publish() -> ConnectableObservable<Element> {
        multicast { PublishSubject() }
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
        multicast { ReplaySubject.create(bufferSize: bufferSize) }
    }

    /**
     Returns a connectable observable sequence that shares a single subscription to the underlying sequence replaying all elements.

     This operator is a specialization of `multicast` using a `ReplaySubject`.

     - seealso: [replay operator on reactivex.io](http://reactivex.io/documentation/operators/replay.html)

     - returns: A connectable observable sequence that shares a single subscription to the underlying sequence.
     */
    func replayAll()
        -> ConnectableObservable<Element> {
        multicast { ReplaySubject.createUnbounded() }
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
    /**
     Multicasts the source sequence notifications through the specified subject to the resulting connectable observable.

     Upon connection of the connectable observable, the subject is subscribed to the source exactly one, and messages are forwarded to the observers registered with the connectable observable.

     For specializations with fixed subject types, see `publish` and `replay`.

     - seealso: [multicast operator on reactivex.io](http://reactivex.io/documentation/operators/publish.html)

     - parameter subject: Subject to push source elements into.
     - returns: A connectable observable sequence that upon connection causes the source sequence to push results into the specified subject.
     */
    func multicast<Subject: SubjectType>(_ subject: Subject)
        -> ConnectableObservable<Subject.Element> where Subject.Observer.Element == Element {
        ConnectableObservableAdapter(source: asObservable(), makeSubject: { subject })
    }

    /**
     Multicasts the source sequence notifications through an instantiated subject to the resulting connectable observable.

     Upon connection of the connectable observable, the subject is subscribed to the source exactly one, and messages are forwarded to the observers registered with the connectable observable.

     Subject is cleared on connection disposal or in case source sequence produces terminal event.

     - seealso: [multicast operator on reactivex.io](http://reactivex.io/documentation/operators/publish.html)

     - parameter makeSubject: Factory function used to instantiate a subject for each connection.
     - returns: A connectable observable sequence that upon connection causes the source sequence to push results into the specified subject.
     */
    func multicast<Subject: SubjectType>(makeSubject: @escaping () -> Subject)
        -> ConnectableObservable<Subject.Element> where Subject.Observer.Element == Element {
        ConnectableObservableAdapter(source: asObservable(), makeSubject: makeSubject)
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

    private var connected = false
    private var replayModel: ReplayModel
    private var observers = Observers()

    private var connectionId: UInt = 0

    init(
        source: Observable<Element>,
        replayModel: ReplayModel
    ) {
        self.source = source
        self.replayModel = replayModel
    }

    func on(_ event: Event<Element>, _ c: C) async {
        if !connected {
            return // okay, maybe not finished disposing source
        }

        switch event {
        case .next(let element):
            replayModel.add(element: element)
            await dispatch(observers, event, c.call())
        case .completed, .error:
            let sourceDisposeable = sourceSubscription.dispose()
            connected = false
            await dispatch(observers, event, c.call())

            await sourceDisposeable?.dispose()
        }
    }

    struct ConnectionDisposable: Disposable {
        let sink: ConnectionSink<ReplayModel>
        let id: UInt

        init(sink: ConnectionSink<ReplayModel>, id: UInt) {
            self.sink = sink
            self.id = id
        }

        func dispose() async {
            await sink.dispose(id: id)
        }
    }

    func connect(_ c: C) async -> ConnectionDisposable {
        if connected {
            fatalError()
        }

        await sourceSubscription.replace(source.subscribe(c.call(), self))?.dispose()

        connectionId = connectionId + 1

        let disposable = ConnectionDisposable(sink: self, id: connectionId)

        return disposable
    }

    func subscribe<Observer>(_ c: C, _ observer: Observer) async -> any AsynchronousDisposable
        where Observer: ObserverType, Observer.Element == Element {
        let anyObserver = observer.asObserver()

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
        if connected {
            connected = false
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
        if id == connectionId {
            await dispose()
        }
    }
}

private final actor ConnectableObservableAdapter<ReplayModel: SubjectReplayModel>: ConnectableObservableType {
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

    func connect(_ c: C) async -> Disposable {
        await connectionSink.connect(c.call())
    }

    func subscribe<Observer>(_ c: C, _ observer: Observer) async -> any AsynchronousDisposable
        where Observer: ObserverType, ReplayModel.Element == Observer.Element {
        await connectionSink.subscribe(c.call(), observer)
    }
}

private final actor RefCountSink<ConnectableSource: ConnectableObservableType, Observer: ObserverType>:
    Sink,
    ObserverType where ConnectableSource.Element == Observer.Element {
    typealias Element = Observer.Element
    typealias Parent = RefCount<ConnectableSource>

    private let parent: Parent

    private var connectionIdSnapshot: Int64 = -1
    let baseSink: BaseSink<Observer>

    init(parent: Parent, observer: Observer) async {
        self.parent = parent
        baseSink = BaseSink(observer: observer)
    }

    func run(_ c: C) async -> Disposable {
        let subscription = await parent.source.subscribe(c.call(), self)
        return await parent.lock.performLocked {
            self.connectionIdSnapshot = self.parent.connectionId

            if self.baseSink.isDisposed() {
                return Disposables.create()
            }

            if self.parent.count == 0 {
                self.parent.count = 1
                self.parent.connectableSubscription = await self.parent.source.connect()
            } else {
                self.parent.count += 1
            }

            return await Disposables.create {
                await subscription.dispose()
                await self.parent.lock.performLocked {
                    if self.parent.connectionId != self.connectionIdSnapshot {
                        return
                    }
                    if self.parent.count == 1 {
                        self.parent.count = 0
                        guard let connectableSubscription = self.parent.connectableSubscription else {
                            return
                        }

                        await connectableSubscription.dispose()
                        self.parent.connectableSubscription = nil
                    } else if self.parent.count > 1 {
                        self.parent.count -= 1
                    } else {
                        rxFatalError("Something went wrong with RefCount disposing mechanism")
                    }
                }
            }
        }
    }

    func on(_ event: Event<Element>, _ c: C) async {
        var connectionToDisposeOf: (any Disposable)?
        switch event {
        case .next:
            await forwardOn(event, c.call())
        case .error, .completed:
            await parent.lock.performLocked {
                if self.parent.connectionId == self.connectionIdSnapshot {
                    let connection = self.parent.connectableSubscription
                    connectionToDisposeOf = connection
                    self.parent.count = 0
                    self.parent.connectionId = self.parent.connectionId &+ 1
                    self.parent.connectableSubscription = nil
                }
            }
            await forwardOn(event, c.call())
            await dispose()
        }
        await connectionToDisposeOf?.dispose()
    }
}

private final class RefCount<ConnectableSource: ConnectableObservableType>: Producer<ConnectableSource.Element> {

    // state
    fileprivate var count = 0
    fileprivate var connectionId: Int64 = 0
    fileprivate var connectableSubscription = nil as Disposable?

    fileprivate let source: ConnectableSource

    init(source: ConnectableSource) {
        self.source = source
        super.init()
    }

    override func run<Observer: ObserverType>(
        _ c: C,
        _ observer: Observer
    )
        async -> AsynchronousDisposable
        where Observer.Element == ConnectableSource.Element {
        let sink = await RefCountSink(parent: self, observer: observer)
        let subscription = await sink.run(c.call())
        return sink
    }
}

private final actor MulticastSink<Subject: SubjectType, Observer: ObserverType>: Sink, ObserverType {
    typealias Element = Observer.Element
    typealias ResultType = Element
    typealias MutlicastType = Multicast<Subject, Observer.Element>

    private let parent: MutlicastType
    let baseSink: BaseSink<Observer>

    init(parent: MutlicastType, observer: Observer) async {
        self.parent = parent
        baseSink = BaseSink(observer: observer)
    }

    func run(_ c: C) async -> Disposable {
        do {
            let subject = try parent.subjectSelector()
            let connectable = await ConnectableObservableAdapter(source: parent.source, makeSubject: { subject })

            let observable = try parent.selector(connectable)

            let subscription = await observable.subscribe(c.call(), self)
            let connection = await connectable.connect()

            return await Disposables.create(subscription, connection)
        } catch let e {
            await self.forwardOn(.error(e), c.call())
            await self.dispose()
            return Disposables.create()
        }
    }

    func on(_ event: Event<ResultType>, _ c: C) async {
        await forwardOn(event, c.call())
        switch event {
        case .next: break
        case .error, .completed:
            await dispose()
        }
    }
}

private final class Multicast<Subject: SubjectType, Result>: Producer<Result> {
    typealias SubjectSelectorType = () throws -> Subject
    typealias SelectorType = (Observable<Subject.Element>) throws -> Observable<Result>

    fileprivate let source: Observable<Subject.Observer.Element>
    fileprivate let subjectSelector: SubjectSelectorType
    fileprivate let selector: SelectorType

    init(
        source: Observable<Subject.Observer.Element>,
        subjectSelector: @escaping SubjectSelectorType,
        selector: @escaping SelectorType
    ) {
        self.source = source
        self.subjectSelector = subjectSelector
        self.selector = selector
        super.init()
    }

    override func run<Observer: ObserverType>(
        _ c: C,
        _ observer: Observer
    )
        async -> AsynchronousDisposable where Observer.Element == Result {
        let sink = await MulticastSink(parent: self, observer: observer)
        let subscription = await sink.run(c.call())
        return sink
    }
}
