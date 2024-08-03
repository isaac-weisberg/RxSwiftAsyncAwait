//
//  ShareReplayScope.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 5/28/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

/// Subject lifetime scope
public enum SubjectLifetimeScope {
    /**
     **Each connection will have it's own subject instance to store replay events.**
     **Connections will be isolated from each another.**

     Configures the underlying implementation to behave equivalent to.

     ```
     source.multicast(makeSubject: { MySubject() }).refCount()
     ```

     **This is the recommended default.**

     This has the following consequences:
     * `retry` or `concat` operators will function as expected because terminating the sequence will clear internal state.
     * Each connection to source observable sequence will use it's own subject.
     * When the number of subscribers drops from 1 to 0 and connection to source sequence is disposed, subject will be cleared.

     ```
     let xs = Observable.deferred { () -> Observable<TimeInterval> in
             print("Performing work ...")
             return Observable.just(Date().timeIntervalSince1970)
         }
         .share(replay: 1, scope: .whileConnected)

     _ = xs.subscribe(onNext: { print("next \($0)") }, onCompleted: { print("completed\n") })
     _ = xs.subscribe(onNext: { print("next \($0)") }, onCompleted: { print("completed\n") })
     _ = xs.subscribe(onNext: { print("next \($0)") }, onCompleted: { print("completed\n") })

     ```

     Notice how time interval is different and `Performing work ...` is printed each time)

     ```
     Performing work ...
     next 1495998900.82141
     completed

     Performing work ...
     next 1495998900.82359
     completed

     Performing work ...
     next 1495998900.82444
     completed

     ```

     */
    case whileConnected

    /**
      **One subject will store replay events for all connections to source.**
      **Connections won't be isolated from each another.**

      Configures the underlying implementation behave equivalent to.

      ```
      source.multicast(MySubject()).refCount()
      ```

      This has the following consequences:
      * Using `retry` or `concat` operators after this operator usually isn't advised.
      * Each connection to source observable sequence will share the same subject.
      * After number of subscribers drops from 1 to 0 and connection to source observable sequence is dispose, this operator will
        continue holding a reference to the same subject.
        If at some later moment a new observer initiates a new connection to source it can potentially receive
        some of the stale events received during previous connection.
      * After source sequence terminates any new observer will always immediately receive replayed elements and terminal event.
        No new subscriptions to source observable sequence will be attempted.

      ```
      let xs = Observable.deferred { () -> Observable<TimeInterval> in
              print("Performing work ...")
              return Observable.just(Date().timeIntervalSince1970)
          }
          .share(replay: 1, scope: .forever)

      _ = xs.subscribe(onNext: { print("next \($0)") }, onCompleted: { print("completed\n") })
      _ = xs.subscribe(onNext: { print("next \($0)") }, onCompleted: { print("completed\n") })
      _ = xs.subscribe(onNext: { print("next \($0)") }, onCompleted: { print("completed\n") })
      ```

      Notice how time interval is the same, replayed, and `Performing work ...` is printed only once

      ```
      Performing work ...
      next 1495999013.76356
      completed

      next 1495999013.76356
      completed

      next 1495999013.76356
      completed
      ```

     */
    case forever
}

public extension ObservableType {
    /**
     Returns an observable sequence that **shares a single subscription to the underlying sequence**, and immediately upon subscription replays  elements in buffer.

     This operator is equivalent to:
     * `.whileConnected`
     ```
     // Each connection will have it's own subject instance to store replay events.
     // Connections will be isolated from each another.
     source.multicast(makeSubject: { Replay.create(bufferSize: replay) }).refCount()
     ```
     * `.forever`
     ```
     // One subject will store replay events for all connections to source.
     // Connections won't be isolated from each another.
     source.multicast(Replay.create(bufferSize: replay)).refCount()
     ```

     It uses optimized versions of the operators for most common operations.

     - parameter replay: Maximum element count of the replay buffer.
     - parameter scope: Lifetime scope of sharing subject. For more information see `SubjectLifetimeScope` enum.

     - seealso: [shareReplay operator on reactivex.io](http://reactivex.io/documentation/operators/replay.html)

     - returns: An observable sequence that contains the elements of a sequence produced by multicasting the source sequence.
     */
    func share(replay: Int = 0, scope: SubjectLifetimeScope = .whileConnected) async
        -> Observable<Element> {
        switch scope {
        case .forever:
            switch replay {
            case 0: return await multicast(PublishSubject()).refCount()
            default: return await multicast(ReplaySubject.create(bufferSize: replay)).refCount()
            }
        case .whileConnected:
            switch replay {
            case 0: return await ShareWhileConnected(source: asObservable())
            case 1: return await ShareReplay1WhileConnected(source: asObservable()).asObservable()
            default: return await multicast(makeSubject: { await ReplaySubject.create(bufferSize: replay) }).refCount()
            }
        }
    }
}

private final actor ShareReplay1WhileConnectedConnection<Element>:
    ObserverType,
    SynchronizedUnsubscribeType {
    typealias Observers = AnyObserver<Element>.s
    typealias DisposeKey = Observers.KeyType

    typealias Parent = ShareReplay1WhileConnected<Element>
    private let parent: Parent
    private let subscription: SingleAssignmentDisposable

    private var disposed = false
    fileprivate var observers = Observers()
    private var element: Element?

    init(parent: Parent) async {
        self.parent = parent
        subscription = await SingleAssignmentDisposable()

        #if TRACE_RESOURCES
            _ = await Resources.incrementTotal()
        #endif
    }

    final func on(_ event: Event<Element>, _ c: C) async {
        let observers = await synchronized_on(event)
        await dispatch(observers, event, c.call())
    }

    private final func synchronized_on(_ event: Event<Element>) async -> Observers {
        if disposed {
            return Observers()
        }

        switch event {
        case .next(let element):
            self.element = element
            return observers
        case .error, .completed:
            let observers = observers
            await synchronized_dispose()
            return observers
        }
    }

    final func connect() async {
        await subscription.setDisposable(parent.source.subscribe(C(), self))
    }

    final func synchronized_subscribe<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> SynchronizedDisposable
        where Observer.Element == Element {
        if let element {
            await observer.on(.next(element), c.call())
        }

        let disposeKey = observers.insert(observer.on)

        return SubscriptionDisposable(owner: self, key: disposeKey)
    }

    private final func synchronized_dispose() async {
        disposed = true
        if await parent.connection === self {
            await parent.setConnection(nil)
        }
        observers = Observers()
    }

    final func synchronizedUnsubscribe(_ disposeKey: DisposeKey) async {
        if await synchronized_unsubscribe(disposeKey) {
            await subscription.dispose()
        }
    }

    @inline(__always)
    private final func synchronized_unsubscribe(_ disposeKey: DisposeKey) async -> Bool {
        // if already unsubscribed, just return
        if observers.removeKey(disposeKey) == nil {
            return false
        }

        if observers.count == 0 {
            await synchronized_dispose()
            return true
        }

        return false
    }

    #if TRACE_RESOURCES
        deinit {
            Task {
                _ = await Resources.decrementTotal()
            }
        }
    #endif
}

// optimized version of share replay for most common case
private final actor ShareReplay1WhileConnected<Element>:
    ObservableType {
    fileprivate typealias Connection = ShareReplay1WhileConnectedConnection<Element>

    fileprivate let source: Observable<Element>

    fileprivate var connection: Connection?
    fileprivate func setConnection(_ newValue: Connection?) {
        connection = newValue
    }

    init(source: Observable<Element>) async {
        await ObservableInit()
        self.source = source
    }

    func subscribe<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> SynchronizedDisposable
        where Observer.Element == Element {
        let connection = await self.synchronized_subscribe(observer)
        let count = await connection.observers.count

        let disposable = await connection.synchronized_subscribe(c.call(), observer)

        if count == 0 {
            await connection.connect()
        }

        return disposable
    }

    @inline(__always)
    private func synchronized_subscribe<Observer: ObserverType>(_ observer: Observer) async -> Connection
        where Observer.Element == Element {
        let connection: Connection

        if let existingConnection = self.connection {
            connection = existingConnection
        } else {
            connection = await ShareReplay1WhileConnectedConnection<Element>(
                parent: self
            )
            self.connection = connection
        }

        return connection
    }

    deinit {
        ObservableDeinit()
    }
}

private final actor ShareWhileConnectedConnection<Element>:
    ObserverType,
    SynchronizedUnsubscribeType {
    typealias Observers = AnyObserver<Element>.s
    typealias DisposeKey = Observers.KeyType

    typealias Parent = ShareWhileConnected<Element>
    private let parent: Parent
    private let subscription: SingleAssignmentDisposable

    private var disposed = false
    fileprivate var observers = Observers()

    init(parent: Parent) async {
        subscription = await SingleAssignmentDisposable()
        self.parent = parent

        #if TRACE_RESOURCES
            _ = await Resources.incrementTotal()
        #endif
    }

    final func on(_ event: Event<Element>, _ c: C) async {
        let observers = synchronized_on(event)
        await dispatch(observers, event, c.call())
    }

    private final func synchronized_on(_ event: Event<Element>) -> Observers {
        if disposed {
            return Observers()
        }

        switch event {
        case .next:
            return observers
        case .error, .completed:
            let observers = observers
            synchronized_dispose()
            return observers
        }
    }

    final func connect() async {
        await subscription.setDisposable(parent.source.subscribe(C(), self))
    }

    final func synchronized_subscribe<Observer: ObserverType>(_ observer: Observer) async -> SynchronizedDisposable
        where Observer.Element == Element {
        let disposeKey = observers.insert(observer.on)

        return SubscriptionDisposable(owner: self, key: disposeKey)
    }

    private final func synchronized_dispose() {
        disposed = true
        if parent.connection === self {
            parent.connection = nil
        }
        observers = Observers()
    }

    final func synchronizedUnsubscribe(_ disposeKey: DisposeKey) async {
        if synchronized_unsubscribe(disposeKey) {
            await subscription.dispose()
        }
    }

    @inline(__always)
    private final func synchronized_unsubscribe(_ disposeKey: DisposeKey) -> Bool {
        // if already unsubscribed, just return
        if observers.removeKey(disposeKey) == nil {
            return false
        }

        if observers.count == 0 {
            synchronized_dispose()
            return true
        }

        return false
    }

    #if TRACE_RESOURCES
        deinit {
            Task {
                _ = await Resources.decrementTotal()
            }
        }
    #endif
}

// optimized version of share replay for most common case
private final class ShareWhileConnected<Element>:
    Observable<Element> {
    fileprivate typealias Connection = ShareWhileConnectedConnection<Element>

    fileprivate let source: Observable<Element>

    private let lock: RecursiveLock

    fileprivate var connection: Connection?

    init(source: Observable<Element>) async {
        lock = await RecursiveLock()
        self.source = source
        await super.init()
    }

    override func subscribe<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> SynchronizedDisposable
        where Observer.Element == Element {
        let (connection, count, disposable) = await lock.performLocked {
            let connection = await self.synchronized_subscribe(observer)
            let count = await connection.observers.count

            let disposable = await connection.synchronized_subscribe(observer)
            return (connection, count, disposable)
        }

        if count == 0 {
            await connection.connect()
        }

        return disposable
    }

    @inline(__always)
    private func synchronized_subscribe<Observer: ObserverType>(_ observer: Observer) async -> Connection
        where Observer.Element == Element {
        let connection: Connection

        if let existingConnection = self.connection {
            connection = existingConnection
        } else {
            connection = await ShareWhileConnectedConnection<Element>(
                parent: self
            )
            self.connection = connection
        }

        return connection
    }
}
