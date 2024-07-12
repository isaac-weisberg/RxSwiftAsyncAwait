//
//  ObserveOn.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 7/25/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

public extension ObservableType {
    /**
     Wraps the source sequence in order to run its observer callbacks on the specified scheduler.

     This only invokes observer callbacks on a `scheduler`. In case the subscription and/or unsubscription
     actions have side-effects that require to be run on a scheduler, use `subscribeOn`.

     - seealso: [observeOn operator on reactivex.io](http://reactivex.io/documentation/operators/observeon.html)

     - parameter scheduler: Scheduler to notify observers on.
     - returns: The source sequence whose observations happen on the specified scheduler.
     */
    func observe(on scheduler: ImmediateSchedulerType) async
        -> Observable<Element>
    {
        guard let serialScheduler = scheduler as? SerialDispatchQueueScheduler else {
            return await ObserveOn(source: self.asObservable(), scheduler: scheduler)
        }

        return await ObserveOnSerialDispatchQueue(source: self.asObservable(),
                                                  scheduler: serialScheduler)
    }

    /**
     Wraps the source sequence in order to run its observer callbacks on the specified scheduler.

     This only invokes observer callbacks on a `scheduler`. In case the subscription and/or unsubscription
     actions have side-effects that require to be run on a scheduler, use `subscribeOn`.

     - seealso: [observeOn operator on reactivex.io](http://reactivex.io/documentation/operators/observeon.html)

     - parameter scheduler: Scheduler to notify observers on.
     - returns: The source sequence whose observations happen on the specified scheduler.
     */
    @available(*, deprecated, renamed: "observe(on:)")
    func observeOn(_ scheduler: ImmediateSchedulerType) async
        -> Observable<Element>
    {
        await self.observe(on: scheduler)
    }
}

private final class ObserveOn<Element>: Producer<Element> {
    let scheduler: ImmediateSchedulerType
    let source: Observable<Element>

    init(source: Observable<Element>, scheduler: ImmediateSchedulerType) async {
        self.scheduler = scheduler
        self.source = source

        #if TRACE_RESOURCES
            _ = await Resources.incrementTotal()
        #endif
    }

    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) async -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        let sink = await ObserveOnSink(scheduler: self.scheduler, observer: observer, cancel: cancel)
        let subscription = await self.source.subscribe(sink)
        return (sink: sink, subscription: subscription)
    }

    #if TRACE_RESOURCES
        deinit {
            Task {
                _ = await Resources.decrementTotal()
            }
        }
    #endif
}

enum ObserveOnState: Int32 {
    // pump is not running
    case stopped = 0
    // pump is running
    case running = 1
}

private final class ObserveOnSink<Observer: ObserverType>: ObserverBase<Observer.Element> {
    typealias Element = Observer.Element

    let scheduler: ImmediateSchedulerType

    let lock: SpinLock
    let observer: Observer

    // state
    var state = ObserveOnState.stopped
    var queue = Queue<Event<Element>>(capacity: 10)

    let scheduleDisposable: SerialDisposable
    let cancel: Cancelable

    init(scheduler: ImmediateSchedulerType, observer: Observer, cancel: Cancelable) async {
        self.scheduleDisposable = await SerialDisposable()
        self.lock = await SpinLock()
        self.scheduler = scheduler
        self.observer = observer
        self.cancel = cancel
        await super.init()
    }

    override func onCore(_ event: Event<Element>) async {
        let shouldStart = await self.lock.performLocked { () -> Bool in
            self.queue.enqueue(event)

            switch self.state {
            case .stopped:
                self.state = .running
                return true
            case .running:
                return false
            }
        }

        if shouldStart {
            await self.scheduleDisposable.setDisposable(self.scheduler.scheduleRecursive((), action: self.run))
        }
    }

    func run(_ state: (), _ recurse: (()) async -> Void) async {
        let (nextEvent, observer) = await self.lock.performLocked { () -> (Event<Element>?, Observer) in
            if !self.queue.isEmpty {
                return (self.queue.dequeue(), self.observer)
            }
            else {
                self.state = .stopped
                return (nil, self.observer)
            }
        }

        if let nextEvent = nextEvent, await !self.cancel.isDisposed() {
            await observer.on(nextEvent)
            if nextEvent.isStopEvent {
                await self.dispose()
            }
        }
        else {
            return
        }

        let shouldContinue = await self.shouldContinue_synchronized()

        if shouldContinue {
            await recurse(())
        }
    }

    func shouldContinue_synchronized() async -> Bool {
        await self.lock.performLocked {
            let isEmpty = self.queue.isEmpty
            if isEmpty { self.state = .stopped }
            return !isEmpty
        }
    }

    override func dispose() async {
        await super.dispose()

        await self.cancel.dispose()
        await self.scheduleDisposable.dispose()
    }
}

#if TRACE_RESOURCES
    var numberOfSerialDispatchObservables: AtomicInt!

    public extension Resources {
        /**
         Counts number of `SerialDispatchQueueObservables`.

         Purposed for unit tests.
         */
        static func numberOfSerialDispatchQueueObservables() async -> Int32 {
            return await load(numberOfSerialDispatchObservables)
        }
    }
#endif

private final class ObserveOnSerialDispatchQueueSink<Observer: ObserverType>: ObserverBase<Observer.Element> {
    let scheduler: SerialDispatchQueueScheduler
    let observer: Observer

    let cancel: Cancelable

    var cachedScheduleLambda: (((sink: ObserveOnSerialDispatchQueueSink<Observer>, event: Event<Element>)) async -> Disposable)!

    init(scheduler: SerialDispatchQueueScheduler, observer: Observer, cancel: Cancelable) async {
        self.scheduler = scheduler
        self.observer = observer
        self.cancel = cancel
        await super.init()

        self.cachedScheduleLambda = { pair in
            guard await !cancel.isDisposed() else { return Disposables.create() }

            await pair.sink.observer.on(pair.event)

            if pair.event.isStopEvent {
                await pair.sink.dispose()
            }

            return Disposables.create()
        }
    }

    override func onCore(_ event: Event<Element>) async {
        _ = await self.scheduler.schedule((self, event), action: self.cachedScheduleLambda!)
    }

    override func dispose() async {
        await super.dispose()

        await self.cancel.dispose()
    }
}

private final class ObserveOnSerialDispatchQueue<Element>: Producer<Element> {
    let scheduler: SerialDispatchQueueScheduler
    let source: Observable<Element>

    init(source: Observable<Element>, scheduler: SerialDispatchQueueScheduler) async {
        self.scheduler = scheduler
        self.source = source

        #if TRACE_RESOURCES
            _ = await Resources.incrementTotal()
            _ = await increment(numberOfSerialDispatchObservables)
        #endif
    }

    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) async -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        let sink = await ObserveOnSerialDispatchQueueSink(scheduler: self.scheduler, observer: observer, cancel: cancel)
        let subscription = await self.source.subscribe(sink)
        return (sink: sink, subscription: subscription)
    }

    #if TRACE_RESOURCES
        deinit {
            Task {
                _ = await Resources.decrementTotal()
                _ = await decrement(numberOfSerialDispatchObservables)
            }
        }
    #endif
}
