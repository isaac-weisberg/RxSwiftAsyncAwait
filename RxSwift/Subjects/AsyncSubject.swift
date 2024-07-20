//
//  AsyncSubject.swift
//  RxSwift
//
//  Created by Victor Galán on 07/01/2017.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

/// An AsyncSubject emits the last value (and only the last value) emitted by the source Observable,
/// and only after that source Observable completes.
///
/// (If the source Observable does not emit any values, the AsyncSubject also completes without emitting any values.)
public final class AsyncSubject<Element>:
    Observable<Element>,
    SubjectType,
    ObserverType,
    SynchronizedUnsubscribeType
{
    public typealias SubjectObserverType = AsyncSubject<Element>

    typealias Observers = AnyObserver<Element>.s
    typealias DisposeKey = Observers.KeyType

    /// Indicates whether the subject has any observers
    public func hasObservers() async -> Bool {
        await self.lock.performLocked(C()) { c in
            self.observers.count > 0
        }
    }

    let lock: RecursiveLock

    // state
    private var observers = Observers()
    private var isStopped = false
    private var stoppedEvent = nil as Event<Element>? {
        didSet {
            self.isStopped = self.stoppedEvent != nil
        }
    }

    private var lastElement: Element?

    #if DEBUG
        private let synchronizationTracker: SynchronizationTracker
    #endif

    /// Creates a subject.
    override public init() async {
        self.lock = await RecursiveLock()
        #if TRACE_RESOURCES
            _ = await Resources.incrementTotal()
        #endif
        #if DEBUG
            self.synchronizationTracker = await SynchronizationTracker()
        #endif
        await super.init()
    }

    /// Notifies all subscribed observers about next event.
    ///
    /// - parameter event: Event to send to the observers.
    public func on(_ event: Event<Element>, _ c: C) async {
        #if DEBUG
            await self.synchronizationTracker.register(synchronizationErrorMessage: .default)
        #endif
        await scope {
            let (observers, event) = await self.synchronized_on(event, c.call())
            switch event {
            case .next:
                await dispatch(observers, event, c.call())
                await dispatch(observers, .completed, c.call())
            case .completed:
                await dispatch(observers, event, c.call())
            case .error:
                await dispatch(observers, event, c.call())
            }
        }
        #if DEBUG
            await self.synchronizationTracker.unregister()
        #endif
    }

    func synchronized_on(_ event: Event<Element>, _ c: C) async -> (Observers, Event<Element>) {
        await self.lock.performLocked(c.call()) { c in
            if self.isStopped {
                return (Observers(), .completed)
            }

            switch event {
            case .next(let element):
                self.lastElement = element
                return (Observers(), .completed)
            case .error:
                self.stoppedEvent = event

                let observers = self.observers
                self.observers.removeAll()

                return (observers, event)
            case .completed:

                let observers = self.observers
                self.observers.removeAll()

                if let lastElement = self.lastElement {
                    self.stoppedEvent = .next(lastElement)
                    return (observers, .next(lastElement))
                }
                else {
                    self.stoppedEvent = event
                    return (observers, .completed)
                }
            }
        }
    }

    /// Subscribes an observer to the subject.
    ///
    /// - parameter observer: Observer to subscribe to the subject.
    /// - returns: Disposable object that can be used to unsubscribe the observer from the subject.
    override public func subscribe<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> Disposable where Observer.Element == Element {
        await self.lock.performLocked(c.call()) { c in await self.synchronized_subscribe(c.call(), observer) }
    }

    func synchronized_subscribe<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> Disposable where Observer.Element == Element {
        if let stoppedEvent = self.stoppedEvent {
            switch stoppedEvent {
            case .next:
                await observer.on(stoppedEvent, c.call())
                await observer.on(.completed, c.call())
            case .completed:
                await observer.on(stoppedEvent, c.call())
            case .error:
                await observer.on(stoppedEvent, c.call())
            }
            return Disposables.create()
        }

        let key = self.observers.insert(observer.on)

        return SubscriptionDisposable(owner: self, key: key)
    }

    func synchronizedUnsubscribe(_ disposeKey: DisposeKey) async {
        await self.lock.performLocked { self.synchronized_unsubscribe(disposeKey) }
    }

    func synchronized_unsubscribe(_ disposeKey: DisposeKey) {
        _ = self.observers.removeKey(disposeKey)
    }

    /// Returns observer interface for subject.
    public func asObserver() -> AsyncSubject<Element> {
        self
    }

    #if TRACE_RESOURCES
        deinit {
            Task {
                _ = await Resources.decrementTotal()
            }
        }
    #endif
}
