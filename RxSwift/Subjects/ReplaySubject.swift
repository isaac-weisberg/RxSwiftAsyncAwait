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
public actor ReplaySubject<Element: Sendable>:
    ObservableType,
    SubjectType,
    ObserverType,
    Disposable,
    AsynchronousUnsubscribeType {
    public typealias SubjectObserverType = ReplaySubject<Element>

    typealias Observers = AnyObserver<Element>.s
    typealias DisposeKey = Observers.KeyType

    // state
    private var isDisposed = false
    private var stoppedEvent = nil as Event<Element>?
    private var observers = Observers()
    private var queue: Queue<Element>
    private let bufferSizeLimit: Int?

    init(bufferSizeLimit: Int?) {
        self.bufferSizeLimit = bufferSizeLimit
        queue = Queue(capacity: bufferSizeLimit ?? 0)
        ObservableInit()
    }

    final var stopped: Bool {
        stoppedEvent != nil
    }

    /// Notifies all subscribed observers about next event.
    ///
    /// - parameter event: Event to send to the observers.
    ///
    ///
    /// on
    public func on(_ event: Event<Element>, _ c: C) async {
        if isDisposed {
            return
        }

        if stopped {
            return
        }

        switch event {
        case .next(let element):
            if let bufferSizeLimit {
                let newBufferLength = queue.count + 1

                if newBufferLength > bufferSizeLimit {
                    _ = queue.dequeue()
                }

                queue.enqueue(element)
            } else {
                queue.enqueue(element)
            }
            await dispatch(observers, event, c.call())
        case .error, .completed:
            stoppedEvent = event
            let observersToNotify = observers

            observers.removeAll()

            await dispatch(observersToNotify, event, c.call())
        }
    }

    public func subscribe<Observer>(_ c: C, _ observer: Observer) async -> any AsynchronousDisposable
        where Observer: ObserverType, Element == Observer.Element {
        if isDisposed {
            await observer.on(.error(RxError.disposed(object: self)), c.call())
            return Disposables.create()
        }

        let anyObserver = observer.asObserver()

        let stoppedEvent = stoppedEvent
        for item in queue {
            await observer.on(.next(item), c.call())
        }
        if let stoppedEvent {
            await observer.on(stoppedEvent, c.call())
            return Disposables.create()
        } else {
            let key = observers.insert(observer.on)
            return SubscriptionDisposable(owner: self, key: key)
        }
    }

    func AsynchronousUnsubscribe(_ disposeKey: Observers.KeyType) async {
        if isDisposed {
            return
        }

        _ = observers.removeKey(disposeKey)
    }

    /// Returns observer interface for subject.
    public nonisolated func asObserver() -> ReplaySubject<Element> {
        self
    }

    /// Unsubscribe all observers and release resources.
    public func dispose() {
        isDisposed = true
        observers.removeAll()
        queue.removeAll()
    }

    /// Creates new instance of `ReplaySubject` that replays at most `bufferSize` last elements of sequence.
    ///
    /// - parameter bufferSize: Maximal number of elements to replay to observer after subscription.
    /// - returns: New instance of replay subject.
    public static func create(bufferSize: Int) -> ReplaySubject<Element> {
        ReplaySubject(bufferSizeLimit: bufferSize)
    }

    /// Creates a new instance of `ReplaySubject` that buffers all the elements of a sequence.
    /// To avoid filling up memory, developer needs to make sure that the use case will only ever store a 'reasonable'
    /// number of elements.
    public static func createUnbounded() -> ReplaySubject<Element> {
        ReplaySubject(bufferSizeLimit: nil)
    }

    deinit {
        ObservableDeinit()
    }
}
