//
//  Generate.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 9/2/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

public extension ObservableType {
    /**
     Generates an observable sequence by running a state-driven loop producing the sequence's elements, using the specified scheduler
     to run the loop send out observer messages.

     - seealso: [create operator on reactivex.io](http://reactivex.io/documentation/operators/create.html)

     - parameter initialState: Initial state.
     - parameter condition: Condition to terminate generation (upon returning `false`).
     - parameter iterate: Iteration step function.
     - parameter scheduler: Scheduler on which to run the generator loop.
     - returns: The generated sequence.
     */
    static func generate(
        initialState: Element,
        condition: @escaping (Element) throws -> Bool,
        scheduler: ImmediateSchedulerType = CurrentThreadScheduler.instance,
        iterate: @escaping (Element) throws -> Element
    )
        async -> Observable<Element> {
        await Generate(
            initialState: initialState,
            condition: condition,
            iterate: iterate,
            resultSelector: { $0 },
            scheduler: scheduler
        )
    }
}

private final actor GenerateSink<Sequence, Observer: ObserverType>: Sink {
    typealias Parent = Generate<Sequence, Observer.Element>

    let baseSink: BaseSink<Observer>

    private let parent: Parent

    private var state: Sequence

    init(parent: Parent, observer: Observer) async {
        self.parent = parent
        state = parent.initialState
        baseSink = BaseSink(observer: observer)
    }

    func run(_ c: C) async -> Disposable {
        await parent.scheduler.scheduleRecursive(true, c.call()) { isFirst, c, recurse in
            do {
                if !isFirst {
                    self.state = try self.parent.iterate(self.state)
                }

                if try self.parent.condition(self.state) {
                    let result = try self.parent.resultSelector(self.state)
                    await self.forwardOn(.next(result), c.call())

                    await recurse(false)
                } else {
                    await self.forwardOn(.completed, c.call())
                    await self.dispose()
                }
            } catch {
                await self.forwardOn(.error(error), c.call())
                await self.dispose()
            }
        }
    }
}

private final class Generate<Sequence, Element>: Producer<Element> {
    fileprivate let initialState: Sequence
    fileprivate let condition: (Sequence) throws -> Bool
    fileprivate let iterate: (Sequence) throws -> Sequence
    fileprivate let resultSelector: (Sequence) throws -> Element
    fileprivate let scheduler: ImmediateSchedulerType

    init(
        initialState: Sequence,
        condition: @escaping (Sequence) throws -> Bool,
        iterate: @escaping (Sequence) throws -> Sequence,
        resultSelector: @escaping (Sequence) throws -> Element,
        scheduler: ImmediateSchedulerType
    )
    async {
        self.initialState = initialState
        self.condition = condition
        self.iterate = iterate
        self.resultSelector = resultSelector
        self.scheduler = scheduler
        await super.init()
    }

    override func run<Observer: ObserverType>(
        _ c: C,
        _ observer: Observer
    )
        async -> AsynchronousDisposable where Observer.Element == Element {
        let sink = await GenerateSink(parent: self, observer: observer)
        let subscription = await sink.run(c.call())
        return sink
    }
}
