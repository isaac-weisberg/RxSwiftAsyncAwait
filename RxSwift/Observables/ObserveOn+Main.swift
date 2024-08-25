public extension ObservableConvertibleType {
    func observe<Scheduler: MainLegacySchedulerProtocol>(on mainScheduler: Scheduler)
        -> ObserveOnMainActorObservable<Element, Scheduler> {
        ObserveOnMainActorObservable(source: asObservable(), scheduler: mainScheduler)
    }
}

public protocol MainLegacySchedulerProtocol: Sendable {
    @MainActor
    func perform(_ work: @Sendable @MainActor () async -> Void) async
}

public struct MainLegacyScheduler: MainLegacySchedulerProtocol {
    public static let instance = MainLegacyScheduler()

    @MainActor
    public func perform(_ work: @MainActor () async -> Void) async {
        await work()
    }
}

public struct MainActorObserver<Element: Sendable>: Sendable {
    public typealias On = @MainActor @Sendable (_ event: Event<Element>, _ c: C) async -> Void

    let _on: On

    public init(_ on: @escaping On) {
        _on = on
    }

    @MainActor
    func on(_ event: Event<Element>, _ c: C) async {
        await _on(event, c.call())
    }
}

public protocol MainActorObservable {
    associatedtype Element: Sendable

    func subscribe(_ c: C, _ observer: MainActorObserver<Element>) async -> Disposable
}

final class ObserveOnMainActorObserver<Element: Sendable, Scheduler: MainLegacySchedulerProtocol>: ObserverType {
    let scheduler: Scheduler
    let mainActorObserver: MainActorObserver<Element>

    init(mainActorObserver: MainActorObserver<Element>, scheduler: Scheduler) {
        self.mainActorObserver = mainActorObserver
        self.scheduler = scheduler
    }

    func on(_ event: Event<Element>, _ c: C) async {
        await scheduler.perform {
            await mainActorObserver.on(event, c.call())
        }
    }
}

public final class ObserveOnMainActorObservable<
    Element: Sendable,
    Scheduler: MainLegacySchedulerProtocol
>: MainActorObservable {
    let source: Observable<Element>
    let scheduler: Scheduler

    init(source: Observable<Element>, scheduler: Scheduler) {
        self.source = source
        self.scheduler = scheduler
    }

    public func subscribe(_ c: C, _ observer: MainActorObserver<Element>) async -> any Disposable {
        await source.subscribe(c.call(), ObserveOnMainActorObserver(mainActorObserver: observer, scheduler: scheduler))
    }
}

public extension MainActorObservable {
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
            _ on: @MainActor @Sendable @escaping (Event<Element>, C) async -> Void
        )
            async -> AsynchronousDisposable {
            await subscribe(C(file, function, line), on)
        }
    #else
        func subscribe(
            _ on: @MainActor @Sendable @escaping (Event<Element>, C) async -> Void
        )
            async -> AsynchronousDisposable {
            await subscribe(C(), on)
        }
    #endif

    func subscribe(
        _ c: C,
        _ on: @MainActor @Sendable @escaping (Event<Element>, C) async -> Void
    )
        async -> AsynchronousDisposable {
        let observer = MainActorObserver<Element> { e, c in
            await on(e, c.call())
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
        onNext: (@MainActor @Sendable (Object, Element) async -> Void)? = nil,
        onError: (@MainActor @Sendable (Object, Swift.Error) async -> Void)? = nil,
        onCompleted: (@MainActor @Sendable (Object) async -> Void)? = nil,
        onDisposed: (@MainActor @Sendable (Object) async -> Void)? = nil
    )
        async -> AsynchronousDisposable {
        await subscribe(
            c.call(),
            onNext: { [weak object] in
                guard let object else { return }
                await onNext?(object, $0)
            },
            onError: { [weak object] in
                guard let object else { return }
                await onError?(object, $0)
            },
            onCompleted: { [weak object] in
                guard let object else { return }
                await onCompleted?(object)
            },
            onDisposed: { [weak object] in
                guard let object else { return }
                await onDisposed?(object)
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
            onNext: (@MainActor @Sendable (Element) async -> Void)? = nil,
            onError: (@MainActor @Sendable (Swift.Error) async -> Void)? = nil,
            onCompleted: (@MainActor @Sendable () async -> Void)? = nil,
            onDisposed: (@MainActor @Sendable () async -> Void)? = nil
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
            onNext: (@MainActor @Sendable (Element) async -> Void)? = nil,
            onError: (@MainActor @Sendable (Swift.Error) async -> Void)? = nil,
            onCompleted: (@MainActor @Sendable () async -> Void)? = nil,
            onDisposed: (@MainActor @Sendable () async -> Void)? = nil
        )
            async -> AsynchronousDisposable {
            await subscribe(C(), onNext: onNext, onError: onError, onCompleted: onCompleted, onDisposed: onDisposed)
        }
    #endif

    func subscribe(
        _ c: C,
        onNext: (@MainActor @Sendable (Element) async -> Void)? = nil,
        onError: (@MainActor @Sendable (Swift.Error) async -> Void)? = nil,
        onCompleted: (@MainActor @Sendable () async -> Void)? = nil,
        onDisposed: (@MainActor @Sendable () async -> Void)? = nil
    )
        async -> AsynchronousDisposable {
        let disposable: AsynchronousDisposable

        if let disposed = onDisposed {
            disposable = Disposables.create(with: disposed)
        } else {
            disposable = Disposables.create()
        }

        let callStack = Hooks.recordCallStackOnError ? await Hooks.getCustomCaptureSubscriptionCallstack()() : []

        let observer = MainActorObserver<Element> { event, _ in
            switch event {
            case .next(let value):
                await onNext?(value)
            case .error(let error):
                if let onError {
                    await onError(error)
                } else {
                    await Hooks.getDefaultErrorHandler()(callStack, error)
                }
                await disposable.dispose()
            case .completed:
                await onCompleted?()
                await disposable.dispose()
            }
        }

        let disposableFromSub = await subscribe(c.call(), observer)
        return Disposables.create {
            await disposableFromSub.dispose()
            await disposable.dispose()
        }
    }
}
