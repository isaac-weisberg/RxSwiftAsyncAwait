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
public final actor AsyncSubject<Element>:
    ObservableType,
    SubjectType,
    ObserverType,
    AsynchronousUnsubscribeType {
    public typealias SubjectObserverType = AsyncSubject<Element>

    typealias Observers = AnyObserver<Element>.s
    typealias DisposeKey = Observers.KeyType

    /// Indicates whether the subject has any observers
    public func hasObservers() async -> Bool {
        observers.count > 0
    }

    // state
    private var observers = Observers()
    private var isStopped = false
    private var stoppedEvent = nil as Event<Element>? {
        didSet {
            isStopped = stoppedEvent != nil
        }
    }

    private var lastElement: Element?

    #if DEBUG
        private let synchronizationTracker: SynchronizationTracker
    #endif

    /// Creates a subject.
    public init() async {
        #if TRACE_RESOURCES
            _ = await Resources.incrementTotal()
        #endif
        #if DEBUG
            synchronizationTracker = await SynchronizationTracker()
        #endif
        await ObservableInit()
    }

    /// Notifies all subscribed observers about next event.
    ///
    /// - parameter event: Event to send to the observers.
    public func on(_ event: Event<Element>, _ c: C) async {
        #if DEBUG
            await synchronizationTracker.register(synchronizationErrorMessage: .default)
        #endif
        await scope {
            let (observers, event) = await self.Asynchronous_on(event, c.call())
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
            await synchronizationTracker.unregister()
        #endif
    }

    func Asynchronous_on(_ event: Event<Element>, _ c: C) async -> (Observers, Event<Element>) {
        if isStopped {
            return (Observers(), .completed)
        }

        switch event {
        case .next(let element):
            lastElement = element
            return (Observers(), .completed)
        case .error:
            stoppedEvent = event

            let observers = observers
            self.observers.removeAll()

            return (observers, event)
        case .completed:

            let observers = observers
            self.observers.removeAll()

            if let lastElement {
                stoppedEvent = .next(lastElement)
                return (observers, .next(lastElement))
            } else {
                stoppedEvent = event
                return (observers, .completed)
            }
        }
    }

    /// Subscribes an observer to the subject.
    ///
    /// - parameter observer: Observer to subscribe to the subject.
    /// - returns: Disposable object that can be used to unsubscribe the observer from the subject.
    public func subscribe<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> AsynchronousDisposable
        where Observer.Element == Element {
        await Asynchronous_subscribe(c.call(), observer)
    }

    func Asynchronous_subscribe<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> Disposable
        where Observer.Element == Element {
        if let stoppedEvent {
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

        let key = observers.insert(observer.on)

        return SubscriptionDisposable(owner: self, key: key)
    }

    func AsynchronousUnsubscribe(_ disposeKey: DisposeKey) async {
        Asynchronous_unsubscribe(disposeKey)
    }

    func Asynchronous_unsubscribe(_ disposeKey: DisposeKey) {
        _ = observers.removeKey(disposeKey)
    }

    /// Returns observer interface for subject.
    nonisolated public func asObserver() -> AsyncSubject<Element> {
        self
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
