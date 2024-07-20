//
//  ReplaySubject.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 4/14/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/// Represents an object that is both an observable sequence as well as an observer.
///
/// Each notification is broadcasted to all subscribed and future observers, subject to buffer trimming policies.
public class ReplaySubject<Element>:
    Observable<Element>,
    SubjectType,
    ObserverType,
    Disposable {
    public typealias SubjectObserverType = ReplaySubject<Element>

    typealias Observers = AnyObserver<Element>.s
    typealias DisposeKey = Observers.KeyType

    /// Indicates whether the subject has any observers
    public func hasObservers() async -> Bool {
        await lock.performLocked { self.observers.count > 0 }
    }

    fileprivate let lock: RecursiveLock

    // state
    fileprivate var isDisposed = false
    fileprivate var stopped = false
    fileprivate var stoppedEvent = nil as Event<Element>? {
        didSet {
            stopped = stoppedEvent != nil
        }
    }

    fileprivate var observers = Observers()

    #if DEBUG
        fileprivate let synchronizationTracker: SynchronizationTracker
    #endif

    final var isStopped: Bool {
        stopped
    }

    /// Notifies all subscribed observers about next event.
    ///
    /// - parameter event: Event to send to the observers.
    public func on(_ event: Event<Element>, _ c: C) async {
        rxAbstractMethod()
    }

    /// Returns observer interface for subject.
    public func asObserver() -> ReplaySubject<Element> {
        self
    }

    /// Unsubscribe all observers and release resources.
    public func dispose() async {}

    /// Creates new instance of `ReplaySubject` that replays at most `bufferSize` last elements of sequence.
    ///
    /// - parameter bufferSize: Maximal number of elements to replay to observer after subscription.
    /// - returns: New instance of replay subject.
    public static func create(bufferSize: Int) async -> ReplaySubject<Element> {
        if bufferSize == 1 {
            return await ReplayOne()
        } else {
            return await ReplayMany(bufferSize: bufferSize)
        }
    }

    /// Creates a new instance of `ReplaySubject` that buffers all the elements of a sequence.
    /// To avoid filling up memory, developer needs to make sure that the use case will only ever store a 'reasonable'
    /// number of elements.
    public static func createUnbounded() async -> ReplaySubject<Element> {
        await ReplayAll()
    }

    override init() async {
        #if DEBUG
            synchronizationTracker = await SynchronizationTracker()
        #endif
        lock = await RecursiveLock()

        #if TRACE_RESOURCES
            _ = await Resources.incrementTotal()
        #endif
        await super.init()
    }

    #if TRACE_RESOURCES
        deinit {
            Task {
                _ = await Resources.decrementTotal()
            }
        }
    #endif
}

private class ReplayBufferBase<Element>:
    ReplaySubject<Element>,
    SynchronizedUnsubscribeType {
    func trim() {
        rxAbstractMethod()
    }

    func addValueToBuffer(_ value: Element) async {
        rxAbstractMethod()
    }

    func replayBuffer<Observer: ObserverType>(_ c: C, _ observer: Observer) async where Observer.Element == Element {
        rxAbstractMethod()
    }

    override func on(_ event: Event<Element>, _ c: C) async {
        #if DEBUG
            await synchronizationTracker.register(synchronizationErrorMessage: .default)
        #endif
        await dispatch(synchronized_on(event, c.call()), event, c.call())
        #if DEBUG
            await synchronizationTracker.unregister()
        #endif
    }

    func synchronized_on(_ event: Event<Element>, _ c: C) async -> Observers {
        await lock.performLocked(c.call()) { _ in
            if self.isDisposed {
                return Observers()
            }

            if self.isStopped {
                return Observers()
            }

            switch event {
            case .next(let element):
                await self.addValueToBuffer(element)
                self.trim()
                return self.observers
            case .error, .completed:
                self.stoppedEvent = event
                self.trim()
                let observers = self.observers
                self.observers.removeAll()
                return observers
            }
        }
    }

    override func subscribe<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> Disposable
        where Observer.Element == Element {
        await lock.performLocked {
            await self.synchronized_subscribe(c.call(), observer)
        }
    }

    func synchronized_subscribe<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> Disposable
        where Observer.Element == Element {
        if isDisposed {
            await observer.on(.error(RxError.disposed(object: self)), c.call())
            return Disposables.create()
        }

        let anyObserver = observer.asObserver()

        await replayBuffer(c.call(), anyObserver)
        if let stoppedEvent {
            await observer.on(stoppedEvent, c.call())
            return Disposables.create()
        } else {
            let key = observers.insert(observer.on)
            return SubscriptionDisposable(owner: self, key: key)
        }
    }

    func synchronizedUnsubscribe(_ disposeKey: DisposeKey) async {
        await lock.performLocked { self.synchronized_unsubscribe(disposeKey) }
    }

    func synchronized_unsubscribe(_ disposeKey: DisposeKey) {
        if isDisposed {
            return
        }

        _ = observers.removeKey(disposeKey)
    }

    override func dispose() async {
        await super.dispose()

        await synchronizedDispose()
    }

    func synchronizedDispose() async {
        await lock.performLocked { self.synchronized_dispose() }
    }

    func synchronized_dispose() {
        isDisposed = true
        observers.removeAll()
    }
}

private final class ReplayOne<Element>: ReplayBufferBase<Element> {
    private var value: Element?

    override init() async {
        await super.init()
    }

    override func trim() {}

    override func addValueToBuffer(_ value: Element) async {
        self.value = value
    }

    override func replayBuffer<Observer: ObserverType>(_ c: C, _ observer: Observer) async where Observer.Element == Element {
        if let value {
            await observer.on(.next(value), c.call())
        }
    }

    override func synchronized_dispose() {
        super.synchronized_dispose()
        value = nil
    }
}

private class ReplayManyBase<Element>: ReplayBufferBase<Element> {
    fileprivate var queue: Queue<Element>

    init(queueSize: Int) async {
        queue = Queue(capacity: queueSize + 1)
        await super.init()
    }

    override func addValueToBuffer(_ value: Element) async {
        queue.enqueue(value)
    }

    override func replayBuffer<Observer: ObserverType>(_ c: C, _ observer: Observer) async where Observer.Element == Element {
        for item in queue {
            await observer.on(.next(item), c.call())
        }
    }

    override func synchronized_dispose() {
        super.synchronized_dispose()
        queue = Queue(capacity: 0)
    }
}

private final class ReplayMany<Element>: ReplayManyBase<Element> {
    private let bufferSize: Int

    init(bufferSize: Int) async {
        self.bufferSize = bufferSize

        await super.init(queueSize: bufferSize)
    }

    override func trim() {
        while queue.count > bufferSize {
            _ = queue.dequeue()
        }
    }
}

private final class ReplayAll<Element>: ReplayManyBase<Element> {
    init() async {
        await super.init(queueSize: 0)
    }

    override func trim() {}
}
