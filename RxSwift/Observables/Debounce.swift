//
//  Debounce.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 9/11/16.
//  Copyright © 2016 Krunoslav Zaher. All rights reserved.
//

import Foundation

public extension ObservableType {
    /**
     Ignores elements from an observable sequence which are followed by another element within a specified relative time duration, using the specified scheduler to run throttling timers.

     - seealso: [debounce operator on reactivex.io](http://reactivex.io/documentation/operators/debounce.html)

     - parameter dueTime: Throttling duration for each element.
     - parameter scheduler: Scheduler to run the throttle timers on.
     - returns: The throttled sequence.
     */
    func debounce(_ dueTime: RxTimeInterval)
        -> Observable<Element> {
        Debounce(source: asObservable(), dueTime: dueTime)
    }
}

private final actor DebounceSink<Observer: ObserverType>:
    SinkOverSingleSubscription,
    ObserverType, ActorLock {
    typealias Element = Observer.Element
    typealias ParentType = Debounce<Element>

    let baseSink: BaseSinkOverSingleSubscription<Observer>

    private let parent: ParentType

    // state
    private var id = 0 as UInt64
    private var value: Element?
    private let timerSerialDisposable = SerialDisposableGeneric<DisposableTimer>()

    init(parent: ParentType, observer: Observer) {
        self.parent = parent

        baseSink = BaseSinkOverSingleSubscription(observer: observer)
    }

    func on(_ event: Event<Element>, _ c: C) async {
        if baseSink.disposed {
            return
        }
        switch event {
        case .next(let element):
            id = id &+ 1
            let currentId = id
            value = element

            let dueTime = parent.dueTime

            let timer = DisposableTimer(dueTime) { [weak self] in
                await self?.propagate(c: c.call(), currentId)
            }
            timerSerialDisposable.replace(timer)?.dispose()
        case .error:
            value = nil
            await forwardOn(event, c.call())
            await dispose()
        case .completed:
            if let value {
                self.value = nil
                await forwardOn(.next(value), c.call())
            }
            await forwardOn(.completed, c.call())
            await dispose()
        }
    }

    func propagate(c: C, _ currentId: UInt64) async {
        if baseSink.disposed {
            return
        }

        let originalValue = value

        if let value = originalValue, id == currentId {
            self.value = nil
            await forwardOn(.next(value), c.call())
        }
    }

    func dispose() async {
        let disposable1 = baseSink.setDisposed()
        let disposable2 = timerSerialDisposable.dispose()

        disposable2?.dispose()
        await disposable1?.dispose()
    }
}

private final class Debounce<Element: Sendable>: Producer<Element> {
    fileprivate let source: Observable<Element>
    fileprivate let dueTime: RxTimeInterval

    init(source: Observable<Element>, dueTime: RxTimeInterval) {
        self.source = source
        self.dueTime = dueTime
        super.init()
    }

    override func run<Observer: ObserverType>(
        _ c: C,
        _ observer: Observer
    )
        async -> AsynchronousDisposable where Observer.Element == Element {
        let sink = DebounceSink(parent: self, observer: observer)
        await sink.run(c.call(), source)
        return sink
    }
}

final class DisposableTimer: @unchecked Sendable {
    typealias Handler = @Sendable () async -> Void

    var task: Task<Void, Never>?
    var disposed = false

    init(_ timeInterval: RxTimeInterval, _ propagateAndDispose: @escaping Handler) {
        task = Task {
            do {
                try await Task.sleep(nanoseconds: timeInterval.nanoseconds)
            } catch {
                return
            }
            await propagateAndDispose()
        }
    }

    func dispose() {
        rxAssert(!disposed)
        task?.cancel()
        task = nil
    }
}
