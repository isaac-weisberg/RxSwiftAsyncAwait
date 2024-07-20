//
//  BehaviorSubject.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 5/23/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/// Represents a value that changes over time.
///
/// Observers can subscribe to the subject to receive the last (or initial) value and all subsequent notifications.
public final class BehaviorSubject<Element>:
    Observable<Element>,
    SubjectType,
    ObserverType,
    SynchronizedUnsubscribeType,
    Cancelable {
    public typealias SubjectObserverType = BehaviorSubject<Element>

    typealias Observers = AnyObserver<Element>.s
    typealias DisposeKey = Observers.KeyType

    /// Indicates whether the subject has any observers
    public func hasObservers() async -> Bool {
        await lock.performLocked { self.observers.count > 0 }
    }

    let lock: RecursiveLock

    // state
    private var disposed = false
    private var element: Element
    private var observers = Observers()
    private var stoppedEvent: Event<Element>?

    #if DEBUG
        private let synchronizationTracker: SynchronizationTracker
    #endif

    /// Indicates whether the subject has been disposed.
    public func isDisposed() async -> Bool {
        disposed
    }

    /// Initializes a new instance of the subject that caches its last value and starts with the specified value.
    ///
    /// - parameter value: Initial value sent to observers when no other value has been received by the subject yet.
    public init(value: Element) async {
        lock = await RecursiveLock()
        element = value

        #if TRACE_RESOURCES
            _ = await Resources.incrementTotal()
        #endif

        #if DEBUG
            synchronizationTracker = await SynchronizationTracker()
        #endif

        await super.init()
    }

    /// Gets the current value or throws an error.
    ///
    /// - returns: Latest value.
    public var value: Element {
        get async throws {
            try await lock.performLockedThrowing {
                if await self.isDisposed() {
                    throw RxError.disposed(object: self)
                }

                if let error = self.stoppedEvent?.error {
                    // intentionally throw exception
                    throw error
                } else {
                    return self.element
                }
            }
        }
    }

    /// Notifies all subscribed observers about next event.
    ///
    /// - parameter event: Event to send to the observers.
    public func on(_ event: Event<Element>, _ c: C) async {
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
            if self.stoppedEvent != nil {
                return Observers()
            }

            if await self.isDisposed() {
                return Observers()
            }

            switch event {
            case .next(let element):
                self.element = element
            case .error, .completed:
                self.stoppedEvent = event
            }

            return self.observers
        }
    }

    /// Subscribes an observer to the subject.
    ///
    /// - parameter observer: Observer to subscribe to the subject.
    /// - returns: Disposable object that can be used to unsubscribe the observer from the subject.
    override public func subscribe<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> Disposable
        where Observer.Element == Element {
        await lock.performLocked(c.call()) { c in await self.synchronized_subscribe(c.call(), observer) }
    }

    func synchronized_subscribe<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> Disposable
        where Observer.Element == Element {
        if await isDisposed() {
            await observer.on(.error(RxError.disposed(object: self)), c.call())
            return Disposables.create()
        }

        if let stoppedEvent {
            await observer.on(stoppedEvent, c.call())
            return Disposables.create()
        }

        let key = observers.insert(observer.on)
        await observer.on(.next(element), c.call())

        return SubscriptionDisposable(owner: self, key: key)
    }

    func synchronizedUnsubscribe(_ disposeKey: DisposeKey) async {
        await lock.performLocked { await self.synchronized_unsubscribe(disposeKey) }
    }

    func synchronized_unsubscribe(_ disposeKey: DisposeKey) async {
        if await isDisposed() {
            return
        }

        _ = observers.removeKey(disposeKey)
    }

    /// Returns observer interface for subject.
    public func asObserver() -> BehaviorSubject<Element> {
        self
    }

    /// Unsubscribe all observers and release resources.
    public func dispose() async {
        await lock.performLocked {
            self.disposed = true
            self.observers.removeAll()
            self.stoppedEvent = nil
        }
    }

    #if TRACE_RESOURCES
        deinit {
            Task {
                _ = await Resources.decrementTotal()
            }
        }
    #endif
}
