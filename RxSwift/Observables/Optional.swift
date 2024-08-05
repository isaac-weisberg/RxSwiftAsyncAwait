//
//  Optional.swift
//  RxSwift
//
//  Created by tarunon on 2016/12/13.
//  Copyright © 2016 Krunoslav Zaher. All rights reserved.
//

public extension ObservableType {
    /**
     Converts a optional to an observable sequence.

     - seealso: [from operator on reactivex.io](http://reactivex.io/documentation/operators/from.html)

     - parameter optional: Optional element in the resulting observable sequence.
     - returns: An observable sequence containing the wrapped value or not from given optional.
     */
    static func from(optional: Element?) async -> Observable<Element> {
        await ObservableOptional(optional: optional)
    }

    /**
     Converts a optional to an observable sequence.

     - seealso: [from operator on reactivex.io](http://reactivex.io/documentation/operators/from.html)

     - parameter optional: Optional element in the resulting observable sequence.
     - parameter scheduler: Scheduler to send the optional element on.
     - returns: An observable sequence containing the wrapped value or not from given optional.
     */
    static func from(optional: Element?, scheduler: ImmediateSchedulerType) async -> Observable<Element> {
        await ObservableOptionalScheduled(optional: optional, scheduler: scheduler)
    }
}

private final actor ObservableOptionalScheduledSink<Observer: ObserverType>: Sink {
    typealias Element = Observer.Element
    typealias Parent = ObservableOptionalScheduled<Element>

    private let parent: Parent
    let baseSink: BaseSink<Observer>

    init(parent: Parent, observer: Observer) async {
        self.parent = parent
        baseSink = BaseSink(observer: observer)
    }

    func run(_ c: C) async -> Disposable {
        await parent.scheduler.schedule(parent.optional, c.call()) { (c, optional: Element?) -> Disposable in
            if let next = optional {
                await self.forwardOn(.next(next), c.call())
                return await self.parent.scheduler.schedule((), c.call()) { c, _ in
                    await self.forwardOn(.completed, c.call())
                    await self.dispose()
                    return Disposables.create()
                }
            } else {
                await self.forwardOn(.completed, c.call())
                await self.dispose()
                return Disposables.create()
            }
        }
    }
}

private final class ObservableOptionalScheduled<Element>: Producer<Element> {
    fileprivate let optional: Element?
    fileprivate let scheduler: ImmediateSchedulerType

    init(optional: Element?, scheduler: ImmediateSchedulerType) async {
        self.optional = optional
        self.scheduler = scheduler
        await super.init()
    }

    override func run<Observer: ObserverType>(
        _ c: C,
        _ observer: Observer
    )
        async -> SynchronizedDisposable where Observer.Element == Element {
        let sink = await ObservableOptionalScheduledSink(parent: self, observer: observer)
        let subscription = await sink.run(c.call())
        return sink
    }
}

private final class ObservableOptional<Element>: Producer<Element> {
    private let optional: Element?

    init(optional: Element?) async {
        self.optional = optional
        await super.init()
    }

    override func subscribe<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> SynchronizedDisposable
        where Observer.Element == Element {
        if let element = optional {
            await observer.on(.next(element), c.call())
        }
        await observer.on(.completed, c.call())
        return Disposables.create()
    }
}
