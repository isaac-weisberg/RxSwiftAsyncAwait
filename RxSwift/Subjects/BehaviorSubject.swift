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
public final actor BehaviorSubject<Element: Sendable>:
    ObservableType,
    SubjectType,
    ObserverType,
    AsynchronousUnsubscribeType,
    Cancelable {
    public typealias SubjectObserverType = BehaviorSubject<Element>

    typealias Observers = AnyObserver<Element>.s
    typealias DisposeKey = Observers.KeyType

    /// Indicates whether the subject has any observers
    public func hasObservers() -> Bool {
        observers.count > 0
    }

    // state
    private var disposed = false
    private var element: Element
    private var observers = Observers()
    private var stoppedEvent: Event<Element>?

    /// Indicates whether the subject has been disposed.
    public func isDisposed() -> Bool {
        disposed
    }

    /// Initializes a new instance of the subject that caches its last value and starts with the specified value.
    ///
    /// - parameter value: Initial value sent to observers when no other value has been received by the subject yet.
    public init(value: Element) {
        ObservableInit()
        element = value
    }

    /// Gets the current value or throws an error.
    ///
    /// - returns: Latest value.
    public var value: Element {
        get throws {
            if isDisposed() {
                throw RxError.disposed(object: self)
            }

            if let error = stoppedEvent?.error {
                // intentionally throw exception
                throw error
            } else {
                return element
            }
        }
    }

    /// Notifies all subscribed observers about next event.
    ///
    /// - parameter event: Event to send to the observers.
    public func on(_ event: Event<Element>, _ c: C) async {
        let observers = Asynchronous_on(event, c.call())

        for observer in observers {
            await observer(event, c.call())
        }
    }

    func Asynchronous_on(_ event: Event<Element>, _ c: C) -> Observers {
        if stoppedEvent != nil {
            return Observers()
        }

        if isDisposed() {
            return Observers()
        }

        switch event {
        case .next(let element):
            self.element = element
        case .error, .completed:
            stoppedEvent = event
        }

        return observers
    }

    /// Subscribes an observer to the subject.
    ///
    /// - parameter observer: Observer to subscribe to the subject.
    /// - returns: Disposable object that can be used to unsubscribe the observer from the subject.
    public func subscribe<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> AsynchronousDisposable
        where Observer.Element == Element {
        if isDisposed() {
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

    func AsynchronousUnsubscribe(_ disposeKey: DisposeKey) {
        Asynchronous_unsubscribe(disposeKey)
    }

    func Asynchronous_unsubscribe(_ disposeKey: DisposeKey) {
        if isDisposed() {
            return
        }

        _ = observers.removeKey(disposeKey)
    }

    /// Returns observer interface for subject.
    public nonisolated func asObserver() -> BehaviorSubject<Element> {
        self
    }

    /// Unsubscribe all observers and release resources.
    public func dispose() {
        disposed = true
        observers.removeAll()
        stoppedEvent = nil
    }

    deinit {
        ObservableDeinit()
    }
}
