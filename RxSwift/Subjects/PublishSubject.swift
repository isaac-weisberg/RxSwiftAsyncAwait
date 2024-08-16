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
public final actor PublishSubject<Element: Sendable>:
    ObservableType,
    SubjectType,
    AsynchronousCancelable,
    ObserverType,
    AsynchronousUnsubscribeType {
    public typealias SubjectObserverType = PublishSubject<Element>

    typealias Observers = AnyObserver<Element>.s
    typealias DisposeKey = Observers.KeyType

    /// Indicates whether the subject has any observers
    public func hasObservers() -> Bool {
        observers.count > 0
    }

    // state
    private var disposed = false
    private var observers = Observers()
    private var stopped = false
    private var stoppedEvent = nil as Event<Element>?

    /// Indicates whether the subject has been isDisposed.
    public func isDisposed() -> Bool {
        disposed
    }

    /// Creates a subject.
    public init() {
        ObservableInit()
    }

    /// Notifies all subscribed observers about next event.
    ///
    /// - parameter event: Event to send to the observers.
    public func on(_ event: Event<Element>, _ c: C) async {
        let observers = Asynchronous_on(event)
        for observer in observers {
            await observer(event, c.call())
        }
    }

    func Asynchronous_on(_ event: Event<Element>) -> Observers {
        switch event {
        case .next:
            let isDisposed = isDisposed()
            if isDisposed || stopped {
                return Observers()
            }

            return observers
        case .completed, .error:
            if stoppedEvent == nil {
                stoppedEvent = event
                stopped = true
                let observers = observers
                self.observers.removeAll()
                return observers
            }

            return Observers()
        }
    }

    /**
     Subscribes an observer to the subject.

     - parameter observer: Observer to subscribe to the subject.
     - returns: Disposable object that can be used to unsubscribe the observer from the subject.
     */
    
    public func subscribe<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> AsynchronousDisposable
        where Observer.Element == Element {
        if let stoppedEvent {
            await observer.on(stoppedEvent, c.call())
            return Disposables.create()
        }

        if isDisposed() {
            await observer.on(.error(RxError.disposed(object: self)), c.call())
            return Disposables.create()
        }

        let key = observers.insert(observer.on)
        return SubscriptionDisposable(owner: self, key: key)
    }

    func AsynchronousUnsubscribe(_ disposeKey: DisposeKey) async {
        _ = observers.removeKey(disposeKey)
    }

    /// Returns observer interface for subject.
    public nonisolated func asObserver() -> PublishSubject<Element> {
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
