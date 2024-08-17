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
            fatalError()
//            switch replay {
//            case 0: return await multicast(PublishSubject()).refCount()
//            default: return await multicast(ReplaySubject.create(bufferSize: replay)).refCount()
//            }
        case .whileConnected:
            switch replay {
            case 0: return ShareWhileConnected(source: asObservable())
            case 1: return ShareReplay1WhileConnected(source: asObservable()).asObservable()
            default: _ = fatalError() // await multicast(makeSubject: { await ReplaySubject.create(bufferSize:
                // replay) }).refCount()
            }
        }
    }
}

private final actor ShareReplay1WhileConnectedConnection<Element: Sendable>:
    ObserverType,
    AsynchronousUnsubscribeType {
    typealias Observers = AnyObserver<Element>.s
    typealias DisposeKey = Observers.KeyType
    private let subscription: SerialPerpetualDisposable<Disposable>

    private var connected = false
    private var observers = Observers()
    private var element: Element?
    private let source: Observable<Element>

    init(source: Observable<Element>) {
        self.source = source
        subscription = SerialPerpetualDisposable()
    }

    func on(_ event: Event<Element>, _ c: C) async {
        if !connected {
            // happens, must've not disposed yet
            return
        }

        switch event {
        case .next(let element):
            self.element = element
            await dispatch(observers, event, c.call())
        case .error, .completed:
            let observersThatWillReceiveTheEvent = observers
            connected = false // source has completed
            let sourceDisposable = subscription.dispose()
            observers.removeAll()
            await dispatch(observersThatWillReceiveTheEvent, event, c.call())
            await sourceDisposable?.dispose()
        }
    }

    func run<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> Disposable
        where Observer.Element == Element {
        let observersCount = observers.count

        let disposeKey = observers.insert(observer.on)

        let observerDisposable = SubscriptionDisposable(owner: self, key: disposeKey)

        if let element {
            await observer.on(.next(element), c.call())
        }

        if observersCount == 0 {
            await subscription.replace(source.subscribe(c.call(), self))?.dispose()
            #if TRACE_RESOURCES
                _ = await Resources.incrementTotal()
            #endif
        }

        return observerDisposable
    }

    func AsynchronousUnsubscribe(_ disposeKey: DisposeKey) async {
        // if already unsubscribed, just return
        // PS: again, apparently, in RxSwift, it's okay for the same disposable to be disposed multiple times, quite similar to how sinks sometimes get disposed twice
        if observers.removeKey(disposeKey) == nil {
            return
        }

        if observers.count == 0 {
            connected = false
            await subscription.dispose()?.dispose()
            #if TRACE_RESOURCES
                _ = await Resources.decrementTotal()
            #endif
        }
    }
}

// optimized version of share replay for most common case
private final class ShareReplay1WhileConnected<Element: Sendable>: Observable<Element> {
    fileprivate typealias Connection = ShareReplay1WhileConnectedConnection<Element>

    fileprivate let connection: Connection

    init(source: Observable<Element>) {
        connection = Connection(source: source)
        super.init()
    }

    override func subscribe<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> AsynchronousDisposable
        where Observer.Element == Element {
        await connection.run(c.call(), observer)
    }
}

private final actor ShareWhileConnectedConnection<Element: Sendable>:
    ObserverType,
    AsynchronousUnsubscribeType {
    typealias Observers = AnyObserver<Element>.s
    typealias DisposeKey = Observers.KeyType

    let source: Observable<Element>
    private let subscription: SerialPerpetualDisposable<Disposable>

    var connected = false
    var observers = Observers()

    init(_ source: Observable<Element>) {
        self.source = source
        subscription = SerialPerpetualDisposable()
    }

    func on(_ event: Event<Element>, _ c: C) async {
        if !connected {
            // happens, must've not disposed yet
            return
        }

        switch event {
        case .next:
            await dispatch(observers, event, c.call())
        case .error, .completed:
            let observersThatWillReceiveTheEvent = observers
            connected = false // source has completed
            let sourceDisposable = subscription.dispose()
            observers.removeAll()
            await dispatch(observersThatWillReceiveTheEvent, event, c.call())
            await sourceDisposable?.dispose()
        }
    }

    func run<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> Disposable
        where Observer.Element == Element {
        let oldObserverCount = observers.count

        let disposeKey = observers.insert(observer.on)

        let observerDisposable = SubscriptionDisposable(owner: self, key: disposeKey)

        if oldObserverCount == 0 {
            connected = true
            let sourceDisposable = await source.subscribe(c.call(), self)
            await subscription.replace(sourceDisposable)?.dispose()
            #if TRACE_RESOURCES
                _ = await Resources.incrementTotal()
            #endif
        }

        return observerDisposable
    }

    func AsynchronousUnsubscribe(_ disposeKey: DisposeKey) async {
        // if already unsubscribed, just return
        // PS: again, apparently, in RxSwift, it's okay for the same disposable to be disposed multiple times, quite similar to how sinks sometimes get disposed twice
        if observers.removeKey(disposeKey) == nil {
            return
        }

        if observers.count == 0 {
            connected = false
            await subscription.dispose()?.dispose()
            #if TRACE_RESOURCES
                _ = await Resources.decrementTotal()
            #endif
        }
    }
}

// optimized version of share replay for most common case
private final class ShareWhileConnected<Element: Sendable>:
    Observable<Element> {
    fileprivate typealias Connection = ShareWhileConnectedConnection<Element>

    fileprivate let connection: Connection

    init(source: Observable<Element>) {
        connection = ShareWhileConnectedConnection(source)
    }

    override func subscribe<Observer>(_ c: C, _ observer: Observer) async -> any AsynchronousDisposable
        where Observer: ObserverType, Element == Observer.Element {
        await connection.run(c.call(), observer)
    }
}
