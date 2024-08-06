public extension SynchronousObservableType {
    func observe(on scheduler: ActorScheduler) -> SynchronousObservable<Element> {
        ObserveOnUnsync(self, scheduler)
    }
}

public extension ObservableType {
    func deAsynchronous() -> SynchronousObservable<Element> {
        DeAsynchronous(source: self)
    }
}

private final class DeAsynchronous<Source: ObservableType>: SynchronousObservable<Source.Element> {
    let source: Source

    init(source: Source) {
        self.source = source
    }

    override func subscribe<Observer>(_ c: C, _ observer: Observer) -> any SynchronousDisposable
        where Source.Element == Observer.Element, Observer: ObserverType {
        let sink = DeAsynchronousSink<AnySyncObserver<Source.Element>>()

        Task {
            await sink.run(c.call(), source, AnySyncObserver(eventHandler: { e, c in
                switch observer.on {
                case .sync(let syncObserverEventHandler):
                    syncObserverEventHandler(e, c.call())
                case .async(let asyncObserverEventHandler):
                    #if DEBUG
                        assertionFailure(
                            "We are desynchronizing an observable, yet you have provided a Asynchronous observer? That's weird... This is supposed to be internal code, so it's my mistake... right?"
                        )
                    #endif
                    Task {
                        await asyncObserverEventHandler(e, c.call())
                    }
                }
            }))
        }

        return sink
    }

}

final actor DeAsynchronousSink<Observer: SyncObserverType>: ObserverType, AsynchronousDisposable,
    SynchronousDisposable {
    typealias Element = Observer.Element

    var observer: Observer?
    var disposed = false
    var sourceSubscription: AsynchronousDisposable?

    init() {}

    nonisolated var on: ObserverEventHandler<Observer.Element> {
        .async { [self] e, c in
            await self.on(e, c.call())
        }
    }

    func on(_ event: Event<Element>, _ c: C) async {
        if disposed {
            return
        }

        observer!.on(event, c.call())
    }

    nonisolated func dispose() {
        Task {
            await self.dispose()
        }
    }

    func dispose() async {
        if !disposed {
            disposed = true
            observer = nil
            let sourceSubscription = sourceSubscription
            self.sourceSubscription = nil
            await sourceSubscription?.dispose()
        }
    }

    func run<Observable: ObservableType>(_ c: C, _ source: Observable, _ observer: Observer) async
        where Observable.Element == Element {
        self.observer = observer
        sourceSubscription = await source.subscribe(c.call(), self)
    }
}

final class ObserveOnUnsync<Source: SynchronousObservableType>: SynchronousObservable<Source.Element> {
    let source: Source
    let scheduler: ActorScheduler

    init(_ source: Source, _ scheduler: ActorScheduler) {
        self.source = source
        self.scheduler = scheduler
    }

    override func subscribe<Observer>(_ c: C, _ observer: Observer) -> any SynchronousDisposable
        where Element == Observer.Element, Observer: ObserverType {

        let sink = ObserveOnSink(scheduler: scheduler, observer: AnySyncObserver(eventHandler: { e, c in
            switch observer.on {
            case .sync(let syncObserverEventHandler):
                syncObserverEventHandler(e, c.call())
            case .async(let asyncObserverEventHandler):
                #if DEBUG
                    assertionFailure(
                        "Why did you bother subscribing an async observer to an observe(on:)? ObserverOn doesn't take effect if the observer needs to be notified asynchronously"
                    )
                #endif
                Task {
                    await asyncObserverEventHandler(e, c.call())
                }
            }
        }))

        sink.run(c.call(), source: source)
        return sink
    }
}

final class ObserveOnSink<Observer: SyncObserverType>: ObserverType,
    AsynchronousDisposable, SynchronousDisposable {
    typealias Element = Observer.Element

    let scheduler: ActorScheduler
    let observer: Observer
    var innerSyncDisposable: AsynchronousDisposable?
    var innerUnsyncDisposable: SynchronousDisposable?
    var disposed = false

    init(scheduler: ActorScheduler, observer: Observer) {
        self.scheduler = scheduler
        self.observer = observer
    }

    func isDisposed() async -> Bool {
        await scheduler.perform(C()) { [self] _ in
            disposed
        }
    }

    func dispose() async {
        await scheduler.perform(C()) { [self] _ in
            if !disposed {
                disposed = true

                let innerSyncDisposable = innerSyncDisposable
                self.innerSyncDisposable = nil
                Task {
                    await innerSyncDisposable?.dispose()
                }
                innerUnsyncDisposable?.dispose()
                innerUnsyncDisposable = nil
            }
        }
    }

    var on: ObserverEventHandler<Observer.Element> {
        .async { [self] e, c in
            self.on(e, c.call())
        }
    }

    func on(_ event: Event<Element>, _ c: C) async {
        if disposed {
            return
        }

        await scheduler.perform(c.call()) { [self] c in
            if disposed {
                return
            }

            observer.on(event, c.call())
        }
    }

    func run<Observable: SynchronousObservableType>(_ c: C, source: Observable)
        where Observable.Element == Observer.Element {
        innerUnsyncDisposable = source.subscribe(c.call(), self)
    }

    nonisolated func on(_ event: Event<Element>, _ c: C) {
        Task {
            await self.on(event, c)
        }
    }

    nonisolated func dispose() {
        Task {
            await self.dispose()
        }
    }

}

////
////  ObserveOn.swift
////  RxSwift
////
////  Created by Krunoslav Zaher on 7/25/15.
////  Copyright © 2015 Krunoslav Zaher. All rights reserved.
////
//
// public extension ObservableType {
//    /**
//     Wraps the source sequence in order to run its observer callbacks on the specified scheduler.
//
//     This only invokes observer callbacks on a `scheduler`. In case the subscription and/or unsubscription
//     actions have side-effects that require to be run on a scheduler, use `subscribeOn`.
//
//     - seealso: [observeOn operator on reactivex.io](http://reactivex.io/documentation/operators/observeon.html)
//
//     - parameter scheduler: Scheduler to notify observers on.
//     - returns: The source sequence whose observations happen on the specified scheduler.
//     */
//    func observe(on scheduler: ImmediateSchedulerType) async
//        -> Observable<Element>
//    {
//        guard let serialScheduler = scheduler as? SerialDispatchQueueScheduler else {
//            return await ObserveOn(source: self.asObservable(), scheduler: scheduler)
//        }
//
//        return await ObserveOnSerialDispatchQueue(source: self.asObservable(),
//                                                  scheduler: serialScheduler)
//    }
//
//    /**
//     Wraps the source sequence in order to run its observer callbacks on the specified scheduler.
//
//     This only invokes observer callbacks on a `scheduler`. In case the subscription and/or unsubscription
//     actions have side-effects that require to be run on a scheduler, use `subscribeOn`.
//
//     - seealso: [observeOn operator on reactivex.io](http://reactivex.io/documentation/operators/observeon.html)
//
//     - parameter scheduler: Scheduler to notify observers on.
//     - returns: The source sequence whose observations happen on the specified scheduler.
//     */
//    @available(*, deprecated, renamed: "observe(on:)")
//    func observeOn(_ scheduler: ImmediateSchedulerType) async
//        -> Observable<Element>
//    {
//        await self.observe(on: scheduler)
//    }
// }
//
//
//
// private final class ObserveOn<Element>: Producer<Element> {
//    let scheduler: ImmediateSchedulerType
//    let source: Observable<Element>
//
//    init(source: Observable<Element>, scheduler: ImmediateSchedulerType) async {
//        self.scheduler = scheduler
//        self.source = source
//
//
//        #if TRACE_RESOURCES
//            _ = await Resources.incrementTotal()
//        #endif
//        await super.init()
//    }
//
//    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer) async ->
//    AsynchronousDisposable where Observer.Element == Element {
//        let sink = await ObserveOnSink(scheduler: self.scheduler, observer: observer)
//        let subscription = await self.source9.subscribe(c.call(), sink)
//        return sink
//    }
//
//    #if TRACE_RESOURCES
//        deinit {
//            Task {
//                _ = await Resources.decrementTotal()
//            }
//        }
//    #endif
// }
//
// enum ObserveOnState: Int32 {
//    // pump is not running
//    case stopped = 0
//    // pump is running
//    case running = 1
// }
//
// private final class ObserveOnSink<Observer: ObserverType>: ObserverBase<Observer.Element> {
//    typealias Element = Observer.Element
//
//    let scheduler: ImmediateSchedulerType
//
//    let lock: SpinLock
//    let observer: Observer
//
//    // state
//    var state = ObserveOnState.stopped
//    var queue = Queue<Event<Element>>(capacity: 10)
//
//    let scheduleDisposable: SerialDisposable
//    let cancel: Cancelable
//
//    init(scheduler: ImmediateSchedulerType, observer: Observer) async {
//        self.scheduleDisposable = await SerialDisposable()
//        self.lock = await SpinLock()
//        self.scheduler = scheduler
//        self.observer = observer
//        self.cancel = cancel
//        await super.init()
//    }
//
//    override func onCore(_ event: Event<Element>, _ c: C) async {
//        let shouldStart = await self.lock.performLocked { () -> Bool in
//            self.queue.enqueue(event)
//
//            switch self.state {
//            case .stopped:
//                self.state = .running
//                return true
//            case .running:
//                return false
//            }
//        }
//
//        if shouldStart {
//            await self.scheduleDisposable.setDisposable(self.scheduler.scheduleRecursive((), c.call(), action:
//            self.run))
//        }
//    }
//
//    func run(_ state: (), _ c: C, _ recurse: (()) async -> Void) async {
//        let (nextEvent, observer) = await self.lock.performLocked { () -> (Event<Element>?, Observer) in
//            if !self.queue.isEmpty {
//                return (self.queue.dequeue(), self.observer)
//            }
//            else {
//                self.state = .stopped
//                return (nil, self.observer)
//            }
//        }
//
//        if let nextEvent = nextEvent, await !self.cancel.isDisposed() {
//            await observer.on(nextEvent, c.call())
//            if nextEvent.isStopEvent {
//                await self.dispose()
//            }
//        }
//        else {
//            return
//        }
//
//        let shouldContinue = await self.shouldContinue_Asynchronous()
//
//        if shouldContinue {
//            await recurse(())
//        }
//    }
//
//    func shouldContinue_Asynchronous() async -> Bool {
//        await self.lock.performLocked {
//            let isEmpty = self.queue.isEmpty
//            if isEmpty { self.state = .stopped }
//            return !isEmpty
//        }
//    }
//
//    override func dispose() async {
//        await super.dispose()
//
//        await self.cancel.dispose()
//        await self.scheduleDisposable.dispose()
//    }
// }
//
#if TRACE_RESOURCES
    var numberOfSerialDispatchObservables: ActualAtomicInt!

    public extension Resources {
        /**
         Counts number of `SerialDispatchQueueObservables`.

         Purposed for unit tests.
         */
        static func numberOfSerialDispatchQueueObservables() async -> Int32 {
            await load(numberOfSerialDispatchObservables)
        }
    }
#endif
//
// private final class ObserveOnSerialDispatchQueueSink<Observer: ObserverType>: ObserverBase<Observer.Element> {
//    let scheduler: SerialDispatchQueueScheduler
//    let observer: Observer
//
//    let cancel: Cancelable
//
//    var cachedScheduleLambda: ((C, (sink: ObserveOnSerialDispatchQueueSink<Observer>, event: Event<Element>)) async ->
//    Disposable)!
//
//    init(scheduler: SerialDispatchQueueScheduler, observer: Observer) async {
//        self.scheduler = scheduler
//        self.observer = observer
//        self.cancel = cancel
//        await super.init()
//
//        self.cachedScheduleLambda = { c, pair in
//            guard await !cancel.isDisposed() else { return Disposables.create() }
//
//            await pair.sink.observer.on(pair.event, c.call())
//
//            if pair.event.isStopEvent {
//                await pair.sink.dispose()
//            }
//
//            return Disposables.create()
//        }
//    }
//
//    override func onCore(_ event: Event<Element>, _ c: C) async {
//        _ = await self.scheduler.schedule((self, event), c.call(), action: self.cachedScheduleLambda!)
//    }
//
//    override func dispose() async {
//        await super.dispose()
//
//        await self.cancel.dispose()
//    }
// }
//
// private final class ObserveOnSerialDispatchQueue<Element>: Producer<Element> {
//    let scheduler: SerialDispatchQueueScheduler
//    let source: Observable<Element>
//
//    init(source: Observable<Element>, scheduler: SerialDispatchQueueScheduler) async {
//        self.scheduler = scheduler
//        self.source = source
//
//        #if TRACE_RESOURCES
//            _ = await Resources.incrementTotal()
//            _ = await increment(numberOfSerialDispatchObservables)
//        #endif
//        await super.init()
//    }
//
//    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> AsynchronousDisposable where
//    Observer.Element == Element {
//        let sink = await ObserveOnSerialDispatchQueueSink(scheduler: self.scheduler, observer: observer)
//        let subscription = await self.source.subscribe(c.call(), sink)
//        return sink
//    }
//
//    #if TRACE_RESOURCES
//        deinit {
//            Task {
//                _ = await Resources.decrementTotal()
//                _ = await decrement(numberOfSerialDispatchObservables)
//            }
//        }
//    #endif
// }
