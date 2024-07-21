//
//  PublishSubject.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/11/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/// Represents an object that is both an observable sequence as well as an observer.
///
/// Each notification is broadcasted to all subscribed observers.
public final actor PublishSubject<Element>:
    ObservableType,
    SubjectType,
    Cancelable,
    ObserverType,
    SynchronizedUnsubscribeType {
    public typealias SubjectObserverType = PublishSubject<Element>

    typealias Observers = AnyObserver<Element>.s
    typealias DisposeKey = Observers.KeyType

    /// Indicates whether the subject has any observers
    public func hasObservers() async -> Bool {
        await lock.performLocked { self.observers.count > 0 }
    }

    private let lock: RecursiveLock

    // state
    private var disposed = false
    private var observers = Observers()
    private var stopped = false
    private var stoppedEvent = nil as Event<Element>?

    #if DEBUG
        private let synchronizationTracker: SynchronizationTracker
    #endif

    /// Indicates whether the subject has been isDisposed.
    public func isDisposed() async -> Bool {
        disposed
    }

    /// Creates a subject.
    public init() async {
        await ObservableInit()
        lock = await RecursiveLock()
        #if DEBUG
            synchronizationTracker = await SynchronizationTracker()
        #endif

        #if TRACE_RESOURCES
            _ = await Resources.incrementTotal()
        #endif
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
            switch event {
            case .next:
                let isDisposed = await self.isDisposed()
                if isDisposed || self.stopped {
                    return Observers()
                }

                return self.observers
            case .completed, .error:
                if self.stoppedEvent == nil {
                    self.stoppedEvent = event
                    self.stopped = true
                    let observers = self.observers
                    self.observers.removeAll()
                    return observers
                }

                return Observers()
            }
        }
    }

    /**
     Subscribes an observer to the subject.

     - parameter observer: Observer to subscribe to the subject.
     - returns: Disposable object that can be used to unsubscribe the observer from the subject.
     */
    public func subscribe<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> Disposable
        where Observer.Element == Element {
        await synchronized_subscribe(c.call(), observer)
    }

    func synchronized_subscribe<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> Disposable
        where Observer.Element == Element {
        if let stoppedEvent {
            await observer.on(stoppedEvent, c.call())
            return Disposables.create()
        }

        if await isDisposed() {
            await observer.on(.error(RxError.disposed(object: self)), c.call())
            return Disposables.create()
        }

        let key = observers.insert(observer.on)
        return SubscriptionDisposable(owner: self, key: key)
    }

    func synchronizedUnsubscribe(_ disposeKey: DisposeKey) async {
        await lock.performLocked(C()) { _ in
            self.synchronized_unsubscribe(disposeKey)
        }
    }

    func synchronized_unsubscribe(_ disposeKey: DisposeKey) {
        _ = observers.removeKey(disposeKey)
    }

    /// Returns observer interface for subject.
    nonisolated public func asObserver() -> PublishSubject<Element> {
        self
    }

    /// Unsubscribe all observers and release resources.
    public func dispose() async {
        await lock.performLocked { self.synchronized_dispose() }
    }

    final func synchronized_dispose() {
        disposed = true
        observers.removeAll()
        stoppedEvent = nil
    }

    deinit {
        ObservableDeinit()
        #if TRACE_RESOURCES
            Task {
                _ = await Resources.decrementTotal()
            }
        #endif
    }
}
