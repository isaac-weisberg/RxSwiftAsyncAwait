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
    ConnectableObservableType
{
    /**
     Connects the observable wrapper to its source. All subscribed observers will receive values from the underlying observable sequence as long as the connection is established.

     - returns: Disposable used to disconnect the observable wrapper from its source, causing subscribed observer to stop receiving values from the underlying observable sequence.
     */
    public func connect() async -> Disposable {
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
    func multicast<Subject: SubjectType, Result>(_ subjectSelector: @escaping () throws -> Subject, selector: @escaping (Observable<Subject.Element>) throws -> Observable<Result>)
        -> Observable<Result> where Subject.Observer.Element == Element
    {
        return Multicast(
            source: self.asObservable(),
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
    func publish() async -> ConnectableObservable<Element> {
        await self.multicast { await PublishSubject() }
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
    func replay(_ bufferSize: Int) async
        -> ConnectableObservable<Element>
    {
        await self.multicast { await ReplaySubject.create(bufferSize: bufferSize) }
    }

    /**
     Returns a connectable observable sequence that shares a single subscription to the underlying sequence replaying all elements.

     This operator is a specialization of `multicast` using a `ReplaySubject`.

     - seealso: [replay operator on reactivex.io](http://reactivex.io/documentation/operators/replay.html)

     - returns: A connectable observable sequence that shares a single subscription to the underlying sequence.
     */
    func replayAll() async
        -> ConnectableObservable<Element>
    {
        await self.multicast { await ReplaySubject.createUnbounded() }
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
    func multicast<Subject: SubjectType>(_ subject: Subject) async
        -> ConnectableObservable<Subject.Element> where Subject.Observer.Element == Element
    {
        await ConnectableObservableAdapter(source: self.asObservable(), makeSubject: { subject })
    }

    /**
     Multicasts the source sequence notifications through an instantiated subject to the resulting connectable observable.

     Upon connection of the connectable observable, the subject is subscribed to the source exactly one, and messages are forwarded to the observers registered with the connectable observable.

     Subject is cleared on connection disposal or in case source sequence produces terminal event.

     - seealso: [multicast operator on reactivex.io](http://reactivex.io/documentation/operators/publish.html)

     - parameter makeSubject: Factory function used to instantiate a subject for each connection.
     - returns: A connectable observable sequence that upon connection causes the source sequence to push results into the specified subject.
     */
    func multicast<Subject: SubjectType>(makeSubject: @escaping () async -> Subject) async
        -> ConnectableObservable<Subject.Element> where Subject.Observer.Element == Element
    {
        await ConnectableObservableAdapter(source: self.asObservable(), makeSubject: makeSubject)
    }
}

private final class Connection<Subject: SubjectType>: ObserverType, Disposable {
    typealias Element = Subject.Observer.Element

    private var lock: RecursiveLock
    // state
    private var parent: ConnectableObservableAdapter<Subject>?
    private var subscription: Disposable?
    private var subjectObserver: Subject.Observer

    private let disposed: AtomicInt

    init(parent: ConnectableObservableAdapter<Subject>, subjectObserver: Subject.Observer, lock: RecursiveLock, subscription: Disposable) async {
        self.disposed = await AtomicInt(0)
        self.parent = parent
        self.subscription = subscription
        self.lock = lock
        self.subjectObserver = subjectObserver
    }

    func on(_ event: Event<Subject.Observer.Element>) async {
        if await isFlagSet(self.disposed, 1) {
            return
        }
        if event.isStopEvent {
            await self.dispose()
        }
        await self.subjectObserver.on(event)
    }

    func dispose() async {
        await self.lock.performLocked {
            await fetchOr(self.disposed, 1)
            guard let parent = self.parent else {
                return
            }

            if parent.connection === self {
                parent.connection = nil
                parent.subject = nil
            }
            self.parent = nil

            await self.subscription?.dispose()
            self.subscription = nil
        }
    }
}

private final class ConnectableObservableAdapter<Subject: SubjectType>:
    ConnectableObservable<Subject.Element>
{
    typealias ConnectionType = Connection<Subject>

    private let source: Observable<Subject.Observer.Element>
    private let makeSubject: () async -> Subject

    fileprivate let lock: RecursiveLock
    fileprivate var subject: Subject?

    // state
    fileprivate var connection: ConnectionType?

    init(source: Observable<Subject.Observer.Element>, makeSubject: @escaping () async -> Subject) async {
        self.lock = await RecursiveLock()
        self.source = source
        self.makeSubject = makeSubject
        self.subject = nil
        self.connection = nil
        await super.init()
    }

    override func connect() async -> Disposable {
        return await self.lock.performLocked {
            if let connection = self.connection {
                return connection
            }

            let singleAssignmentDisposable = await SingleAssignmentDisposable()
            let connection = await Connection(parent: self, subjectObserver: self.lazySubject().asObserver(), lock: self.lock, subscription: singleAssignmentDisposable)
            self.connection = connection
            let subscription = await self.source.subscribe(connection)
            await singleAssignmentDisposable.setDisposable(subscription)
            return connection
        }
    }

    private func lazySubject() async -> Subject {
        if let subject = self.subject {
            return subject
        }

        let subject = await self.makeSubject()
        self.subject = subject
        return subject
    }

    override func subscribe<Observer: ObserverType>(_ observer: Observer) async -> Disposable where Observer.Element == Subject.Element {
        await self.lazySubject().subscribe(observer)
    }
}

private final class RefCountSink<ConnectableSource: ConnectableObservableType, Observer: ObserverType>:
    Sink<Observer>,
    ObserverType where ConnectableSource.Element == Observer.Element
{
    typealias Element = Observer.Element
    typealias Parent = RefCount<ConnectableSource>

    private let parent: Parent

    private var connectionIdSnapshot: Int64 = -1

    init(parent: Parent, observer: Observer, cancel: Cancelable) async {
        self.parent = parent
        await super.init(observer: observer, cancel: cancel)
    }

    func run() async -> Disposable {
        let subscription = await self.parent.source.subscribe(self)
        return await self.parent.lock.performLocked {
            self.connectionIdSnapshot = self.parent.connectionId

            if await self.isDisposed() {
                return Disposables.create()
            }

            if self.parent.count == 0 {
                self.parent.count = 1
                self.parent.connectableSubscription = await self.parent.source.connect()
            }
            else {
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
                    }
                    else if self.parent.count > 1 {
                        self.parent.count -= 1
                    }
                    else {
                        rxFatalError("Something went wrong with RefCount disposing mechanism")
                    }
                }
            }
        }
    }

    func on(_ event: Event<Element>) async {
        var connectionToDisposeOf: (any Disposable)?
        switch event {
        case .next:
            await self.forwardOn(event)
        case .error, .completed:
            await self.parent.lock.performLocked {
                if self.parent.connectionId == self.connectionIdSnapshot {
                    let connection = self.parent.connectableSubscription
                    connectionToDisposeOf = connection
                    self.parent.count = 0
                    self.parent.connectionId = self.parent.connectionId &+ 1
                    self.parent.connectableSubscription = nil
                }
            }
            await self.forwardOn(event)
            await self.dispose()
        }
        await connectionToDisposeOf?.dispose()
    }
}

private final class RefCount<ConnectableSource: ConnectableObservableType>: Producer<ConnectableSource.Element> {
    fileprivate let lock: RecursiveLock

    // state
    fileprivate var count = 0
    fileprivate var connectionId: Int64 = 0
    fileprivate var connectableSubscription = nil as Disposable?

    fileprivate let source: ConnectableSource

    init(source: ConnectableSource) async {
        self.lock = await RecursiveLock()
        self.source = source
    }

    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) async -> (sink: Disposable, subscription: Disposable)
        where Observer.Element == ConnectableSource.Element
    {
        let sink = await RefCountSink(parent: self, observer: observer, cancel: cancel)
        let subscription = await sink.run()
        return (sink: sink, subscription: subscription)
    }
}

private final class MulticastSink<Subject: SubjectType, Observer: ObserverType>: Sink<Observer>, ObserverType {
    typealias Element = Observer.Element
    typealias ResultType = Element
    typealias MutlicastType = Multicast<Subject, Observer.Element>

    private let parent: MutlicastType

    init(parent: MutlicastType, observer: Observer, cancel: Cancelable) async {
        self.parent = parent
        await super.init(observer: observer, cancel: cancel)
    }

    func run() async -> Disposable {
        do {
            let subject = try self.parent.subjectSelector()
            let connectable = await ConnectableObservableAdapter(source: self.parent.source, makeSubject: { subject })

            let observable = try self.parent.selector(connectable)

            let subscription = await observable.subscribe(self)
            let connection = await connectable.connect()

            return await Disposables.create(subscription, connection)
        }
        catch let e {
            await self.forwardOn(.error(e))
            await self.dispose()
            return Disposables.create()
        }
    }

    func on(_ event: Event<ResultType>) async {
        await self.forwardOn(event)
        switch event {
        case .next: break
        case .error, .completed:
            await self.dispose()
        }
    }
}

private final class Multicast<Subject: SubjectType, Result>: Producer<Result> {
    typealias SubjectSelectorType = () throws -> Subject
    typealias SelectorType = (Observable<Subject.Element>) throws -> Observable<Result>

    fileprivate let source: Observable<Subject.Observer.Element>
    fileprivate let subjectSelector: SubjectSelectorType
    fileprivate let selector: SelectorType

    init(source: Observable<Subject.Observer.Element>, subjectSelector: @escaping SubjectSelectorType, selector: @escaping SelectorType) {
        self.source = source
        self.subjectSelector = subjectSelector
        self.selector = selector
    }

    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) async -> (sink: Disposable, subscription: Disposable) where Observer.Element == Result {
        let sink = await MulticastSink(parent: self, observer: observer, cancel: cancel)
        let subscription = await sink.run()
        return (sink: sink, subscription: subscription)
    }
}
