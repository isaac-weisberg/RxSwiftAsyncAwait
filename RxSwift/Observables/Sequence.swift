//
//  Sequence.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 11/14/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

public extension ObservableType {
    // MARK: of

    /**
     This method creates a new Observable instance with a variable number of elements.

     - seealso: [from operator on reactivex.io](http://reactivex.io/documentation/operators/from.html)

     - parameter elements: Elements to generate.
     - parameter scheduler: Scheduler to send elements on. If `nil`, elements are sent immediately on subscription.
     - returns: The observable sequence whose elements are pulled from the given arguments.
     */
    static func of(_ elements: Element ..., scheduler: ImmediateSchedulerType = CurrentThreadScheduler.instance) async -> Observable<Element> {
        await ObservableSequence(elements: elements, scheduler: scheduler)
    }
}

public extension ObservableType {
    /**
     Converts an array to an observable sequence.

     - seealso: [from operator on reactivex.io](http://reactivex.io/documentation/operators/from.html)

     - returns: The observable sequence whose elements are pulled from the given enumerable sequence.
     */
    static func from(_ array: [Element], scheduler: ImmediateSchedulerType = CurrentThreadScheduler.instance) async -> Observable<Element> {
        await ObservableSequence(elements: array, scheduler: scheduler)
    }

    /**
     Converts a sequence to an observable sequence.

     - seealso: [from operator on reactivex.io](http://reactivex.io/documentation/operators/from.html)

     - returns: The observable sequence whose elements are pulled from the given enumerable sequence.
     */
    static func from<Sequence: Swift.Sequence>(_ sequence: Sequence, scheduler: ImmediateSchedulerType = CurrentThreadScheduler.instance) async -> Observable<Element> where Sequence.Element == Element {
        await ObservableSequence(elements: sequence, scheduler: scheduler)
    }
}

private final actor ObservableSequenceSink<Sequence: Swift.Sequence, Observer: ObserverType>: Sink where Sequence.Element == Observer.Element {
    typealias Parent = ObservableSequence<Sequence>

    private let parent: Parent
    let baseSink: BaseSink<Observer>

    init(parent: Parent, observer: Observer) async {
        self.parent = parent
        self.baseSink = BaseSink(observer: observer)
    }

    func run(_ c: C) async -> Disposable {
        return await self.parent.scheduler.scheduleRecursive(self.parent.elements.makeIterator(), c.call()) { iterator, c, recurse in
            var mutableIterator = iterator
            if let next = mutableIterator.next() {
                await self.forwardOn(.next(next), c.call())
                await recurse(mutableIterator)
            }
            else {
                await self.forwardOn(.completed, c.call())
                await self.dispose()
            }
        }
    }
}

private final class ObservableSequence<Sequence: Swift.Sequence>: Producer<Sequence.Element> {
    fileprivate let elements: Sequence
    fileprivate let scheduler: ImmediateSchedulerType

    init(elements: Sequence, scheduler: ImmediateSchedulerType) async {
        self.elements = elements
        self.scheduler = scheduler
        await super.init()
    }

    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> SynchronizedDisposable where Observer.Element == Element {
        let sink = await ObservableSequenceSink(parent: self, observer: observer)
        let subscription = await sink.run(c.call())
        return sink
    }
}
