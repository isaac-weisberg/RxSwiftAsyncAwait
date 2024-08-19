public extension ObservableConvertibleType {
    func observe<Scheduler: LegacySynchronousScheduler>(on scheduler: Scheduler)
        -> ObserveOnLegacySynchronousScheduler<Element, Scheduler> {
        ObserveOnLegacySynchronousScheduler(source: asObservable(), scheduler: scheduler)
    }
}

public protocol LegacySynchronousScheduler: Sendable {
    func perform(_ work: @Sendable () -> Void) async
}

public final class WhateverLegacySynchronousScheduler: LegacySynchronousScheduler {
    public static let instance = WhateverLegacySynchronousScheduler()

    public func perform(_ work: @Sendable () -> Void) async {
        work()
    }
}

public protocol SynchronouslyHandlingObservable {
    associatedtype Element: Sendable

    func subscribe<Observer: SynchronousObserver>(_ c: C, _ observer: Observer) async -> Disposable
        where Observer.Element == Element
}

public final actor ObserveOnLegacySynchronousSchedulerSink<
    Observer: SynchronousObserver,
    Scheduler: LegacySynchronousScheduler
>: Disposable, ObserverType {
    public typealias Element = Observer.Element

    let observer: Observer
    let scheduler: Scheduler
    let sourceDisposable = SingleAssignmentDisposable()

    init(observer: Observer, scheduler: Scheduler) {
        self.observer = observer
        self.scheduler = scheduler
    }

    func run(_ c: C, _ source: Observable<Element>) async {
        await sourceDisposable.setDisposable(source.subscribe(c.call(), self))?.dispose()
    }

    public func on(_ event: Event<Element>, _ c: C) async {
        await scheduler.perform { @Sendable in
            observer.on(event, c.call())
        }
    }

    public func dispose() async {
        await sourceDisposable.dispose()?.dispose()
    }
}

public final class ObserveOnLegacySynchronousScheduler<
    Element: Sendable,
    Scheduler: LegacySynchronousScheduler
>: SynchronouslyHandlingObservable {
    let scheduler: Scheduler
    let source: Observable<Element>

    init(source: Observable<Element>, scheduler: Scheduler) {
        self.source = source
        self.scheduler = scheduler
    }

    public func subscribe<Observer: SynchronousObserver>(_ c: C, _ observer: Observer) async -> any Disposable
        where Element == Observer.Element {
        let sink = ObserveOnLegacySynchronousSchedulerSink(observer: observer, scheduler: scheduler)
        await sink.run(c.call(), source)
        return sink
    }
}

public protocol SynchronousObserver: Sendable {
    associatedtype Element: Sendable

    func on(_ event: Event<Element>, _ c: C)
}

final class AnySynchronousObserver<Element: Sendable>: SynchronousObserver {
    let handler: @Sendable (Event<Element>, C) -> Void

    init(handler: @Sendable @escaping (Event<Element>, C) -> Void) {
        self.handler = handler
    }

    func on(_ event: Event<Element>, _ c: C) {
        handler(event, c.call())
    }
}

public extension SynchronouslyHandlingObservable {
    /**
     Subscribes an event handler to an observable sequence.
     
     - parameter on: Action to invoke for each event in the observable sequence.
     - returns: Subscription object used to unsubscribe from the observable sequence.
     */
    #if VICIOUS_TRACING
        func subscribe(
            _ file: StaticString = #file,
            _ function: StaticString = #function,
            _ line: UInt = #line,
            _ on: @Sendable @escaping (Event<Element>, C) -> Void
        )
            async -> AsynchronousDisposable {
            await subscribe(C(file, function, line), on)
        }
    #else
        func subscribe(
            _ on: @Sendable @escaping (Event<Element>, C) -> Void
        )
            async -> AsynchronousDisposable {
            await subscribe(C(), on)
        }
    #endif

    func subscribe(_ c: C, _ on: @Sendable @escaping (Event<Element>, C) -> Void) async -> AsynchronousDisposable {
        let observer = AnySynchronousObserver<Element> { e, c in
            on(e, c.call())
        }
        return await subscribe(c.call(), observer)
    }

    /**
     Subscribes an element handler, an error handler, a completion handler and disposed handler to an observable sequence.

     Also, take in an object and provide an unretained, safe to use (i.e. not implicitly unwrapped), reference to it along with the events emitted by the sequence.

     - Note: If `object` can't be retained, none of the other closures will be invoked.

     - parameter object: The object to provide an unretained reference on.
     - parameter onNext: Action to invoke for each element in the observable sequence.
     - parameter onError: Action to invoke upon errored termination of the observable sequence.
     - parameter onCompleted: Action to invoke upon graceful termination of the observable sequence.
     - parameter onDisposed: Action to invoke upon any type of termination of sequence (if the sequence has
     gracefully completed, errored, or if the generation is canceled by disposing subscription).
     - returns: Subscription object used to unsubscribe from the observable sequence.
     */
    func subscribe<Object: AnyObject & Sendable>(
        _ c: C,
        with object: Object,
        onNext: (@Sendable (Object, Element) -> Void)? = nil,
        onError: (@Sendable (Object, Swift.Error) -> Void)? = nil,
        onCompleted: (@Sendable (Object) -> Void)? = nil,
        onDisposed: (@Sendable (Object) -> Void)? = nil
    )
        async -> AsynchronousDisposable {
        await subscribe(
            c.call(),
            onNext: { [weak object] in
                guard let object else { return }
                onNext?(object, $0)
            },
            onError: { [weak object] in
                guard let object else { return }
                onError?(object, $0)
            },
            onCompleted: { [weak object] in
                guard let object else { return }
                onCompleted?(object)
            },
            onDisposed: { [weak object] in
                guard let object else { return }
                onDisposed?(object)
            }
        )
    }

    /**
     Subscribes an element handler, an error handler, a completion handler and disposed handler to an observable sequence.
     
     - parameter onNext: Action to invoke for each element in the observable sequence.
     - parameter onError: Action to invoke upon errored termination of the observable sequence.
     - parameter onCompleted: Action to invoke upon graceful termination of the observable sequence.
     - parameter onDisposed: Action to invoke upon any type of termination of sequence (if the sequence has
     gracefully completed, errored, or if the generation is canceled by disposing subscription).
     - returns: Subscription object used to unsubscribe from the observable sequence.
     */
    #if VICIOUS_TRACING
        func subscribe(
            _ file: StaticString = #file,
            _ function: StaticString = #function,
            _ line: UInt = #line,
            onNext: (@Sendable (Element) -> Void)? = nil,
            onError: (@Sendable (Swift.Error) -> Void)? = nil,
            onCompleted: (@Sendable () -> Void)? = nil,
            onDisposed: (@Sendable () -> Void)? = nil
        )
            async -> AsynchronousDisposable {
            let c = C(file, function, line)
            return await subscribe(
                c,
                onNext: onNext,
                onError: onError,
                onCompleted: onCompleted,
                onDisposed: onDisposed
            )
        }
    #else
        func subscribe(
            onNext: (@Sendable (Element) -> Void)? = nil,
            onError: (@Sendable (Swift.Error) -> Void)? = nil,
            onCompleted: (@Sendable () -> Void)? = nil,
            onDisposed: (@Sendable () -> Void)? = nil
        )
            async -> AsynchronousDisposable {
            await subscribe(C(), onNext: onNext, onError: onError, onCompleted: onCompleted, onDisposed: onDisposed)
        }
    #endif

    func subscribe(
        _ c: C,
        onNext: (@Sendable (Element) -> Void)? = nil,
        onError: (@Sendable (Swift.Error) -> Void)? = nil,
        onCompleted: (@Sendable () -> Void)? = nil,
        onDisposed: (@Sendable () -> Void)? = nil
    )
        async -> AsynchronousDisposable {
        let disposable: AsynchronousDisposable

        if let disposed = onDisposed {
            disposable = Disposables.create(with: disposed)
        } else {
            disposable = Disposables.create()
        }

        let callStack = Hooks.recordCallStackOnError ? await Hooks.getCustomCaptureSubscriptionCallstack()() : []

        let observer = AnySynchronousObserver<Element> { event, _ in
            switch event {
            case .next(let value):
                onNext?(value)
            case .error(let error):
                if let onError {
                    onError(error)
                } else {
                    Task {
                        await Hooks.getDefaultErrorHandler()(callStack, error)
                    }
                }
                Task {
                    await disposable.dispose()
                }
            case .completed:
                onCompleted?()
                Task {
                    await disposable.dispose()
                }
            }
        }

        let disposableFromSub = await subscribe(c.call(), observer)
        return Disposables.create {
            await disposableFromSub.dispose()
            await disposable.dispose()
        }
    }
}
