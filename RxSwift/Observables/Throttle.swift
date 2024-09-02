//
//  Throttle.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 3/22/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

import Foundation

public extension ObservableType {
    /**
     Returns an Observable that emits the first and maybe the latest item emitted by the source Observable during sequential time windows of a specified duration.

     This operator makes sure that no two elements are emitted in less then dueTime.

     - seealso: [debounce operator on reactivex.io](http://reactivex.io/documentation/operators/debounce.html)

     - parameter dueTime: Throttling duration for each element.
     - parameter emitLatestElementOnceWindowRunsOut: If false, all events received during dueTime are ignored. If true, the latest one is emitted.
     - parameter scheduler: Scheduler to run the throttle timers on.
     - returns: The throttled sequence.
     */
    func throttle(_ dueTime: RxTimeInterval, emitLatestElementOnceWindowRunsOut: Bool = true) -> Observable<Element> {
        Throttle(
            source: asObservable(),
            dueTime: dueTime,
            emitLatestElementOnceWindowRunsOut: emitLatestElementOnceWindowRunsOut
        )
    }

    func throttle(
        _ dueTime: RxTimeInterval,
        emitLatestElementOnceWindowRunsOut: Bool = true,
        scheduler: some AsyncScheduler
    ) -> Observable<Element> {
        throttle(dueTime, emitLatestElementOnceWindowRunsOut: emitLatestElementOnceWindowRunsOut)
            .observe(on: scheduler)
    }

    func throttle(
        _ dueTime: RxTimeInterval,
        emitLatestElementOnceWindowRunsOut: Bool = true,
        scheduler: some MainLegacySchedulerProtocol
    ) -> ObserveOnMainActorObservable<Element, some MainLegacySchedulerProtocol> {
        throttle(dueTime, emitLatestElementOnceWindowRunsOut: emitLatestElementOnceWindowRunsOut)
            .observe(on: scheduler)
    }
}

private final actor ThrottleSink<Observer: ObserverType>: Sink, ObserverType {
    typealias Element = Observer.Element
    typealias ParentType = Throttle<Element>

    private let parent: ParentType
    let baseSink: BaseSink<Observer>
    private let sourceDisposable = SingleAssignmentDisposable()

    // state
    private var lastUnsentElement: Element?
    private var completedReceived = false
    private var throttleTimer: DisposableTimer?

    init(parent: ParentType, observer: Observer) {
        self.parent = parent

        baseSink = BaseSink(observer: observer)
    }

    func run(_ c: C) async {
        let subscription = await parent.source.subscribe(c.call(), self)
        await sourceDisposable.setDisposable(subscription)?.dispose()
    }

    func dispose() async {
        baseSink.setDisposed()
        let disp = sourceDisposable.dispose()
        throttleTimer?.dispose()
        throttleTimer = nil

        await disp?.dispose()
    }

    func on(_ event: Event<Element>, _ c: C) async {
        if baseSink.disposed {
            return
        }

        switch event {
        case .next(let element):
            if throttleTimer == nil {
                throttleTimer = DisposableTimer(parent.dueTime) { [weak self] _ in
                    await self?.handleThrottleTimerEnded(c.call())
                }
                await forwardOn(event, c.call())
            } else {
                if parent.emitLatestElementOnceWindowRunsOut {
                    lastUnsentElement = element
                }
            }
        case .error:
            lastUnsentElement = nil
            async let fwd: ()? = forwardOn(event, c.call())
            async let disposed: ()? = dispose()

            await fwd
            await disposed
        case .completed:
            if parent.emitLatestElementOnceWindowRunsOut, lastUnsentElement != nil {
                completedReceived = true
            } else {
                await forwardOn(.completed, c.call())
                await dispose()
            }
        }
    }

    private func handleThrottleTimerEnded(_ c: C) async {
        throttleTimer = nil

        if baseSink.disposed {
            assertionFailure() // I would assume that it should never be called,
            // if we're disposed, since the throttle timer should be cancelled
            return
        }

        if parent.emitLatestElementOnceWindowRunsOut, let lastUnsentElement {
            self.lastUnsentElement = nil
            await forwardOn(.next(lastUnsentElement), c.call())
        }

        if completedReceived {
            await forwardOn(.completed, c.call())
            await dispose()
        }
    }
}

private final class Throttle<Element: Sendable>: Producer<Element> {
    fileprivate let source: Observable<Element>
    fileprivate let dueTime: RxTimeInterval
    fileprivate let emitLatestElementOnceWindowRunsOut: Bool

    init(
        source: Observable<Element>,
        dueTime: RxTimeInterval,
        emitLatestElementOnceWindowRunsOut: Bool
    ) {
        self.source = source
        self.dueTime = dueTime
        self.emitLatestElementOnceWindowRunsOut = emitLatestElementOnceWindowRunsOut
        super.init()
    }

    override func run<Observer>(_ c: C, _ observer: Observer) async -> any AsynchronousDisposable
        where Element == Observer.Element, Observer: ObserverType {
        let sink = ThrottleSink(parent: self, observer: observer)
        await sink.run(c.call())
        return sink
    }
}
