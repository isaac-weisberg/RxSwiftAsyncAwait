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
    static func of(_ elements: Element ...) -> Observable<Element> {
        ObservableSequence(elements: elements)
    }

    static func of(_ elements: Element ..., scheduler: any AsyncScheduler) -> Observable<Element> {
        from(elements, scheduler: scheduler)
    }

    static func of(
        _ elements: Element ...,
        scheduler: some MainLegacySchedulerProtocol
    )
        -> AssumeSyncAndReemitAllOnMainScheduler<Observable<Element>, some MainLegacySchedulerProtocol> {
        from(elements, scheduler: scheduler)
    }
}

public extension ObservableType {
    /**
     Converts a sequence to an observable sequence.

     - seealso: [from operator on reactivex.io](http://reactivex.io/documentation/operators/from.html)

     - returns: The observable sequence whose elements are pulled from the given enumerable sequence.
     */
    static func from<Sequence: Swift.Sequence>(_ sequence: Sequence) -> Observable<Element>
        where Sequence.Element == Element {
        ObservableSequence(elements: sequence)
    }

    static func from<Sequence: Swift.Sequence>(
        _ sequence: Sequence,
        scheduler: any AsyncScheduler
    ) -> Observable<Element>
        where Sequence.Element == Element {
        from(sequence)
            .assumeSyncAndReemitAll(on: scheduler, predictedEventCount: sequence.underestimatedCount)
    }

    static func from<Sequence: Swift.Sequence>(
        _ sequence: Sequence,
        scheduler: some MainLegacySchedulerProtocol
    ) -> AssumeSyncAndReemitAllOnMainScheduler<Observable<Element>, some MainLegacySchedulerProtocol>
        where Sequence.Element == Element {
        from(sequence)
            .assumeSyncAndReemitAll(on: scheduler, predictedEventCount: sequence.underestimatedCount)
    }
}

private final class ObservableSequence<Sequence: Swift.Sequence>: Producer<Sequence.Element>
    where Sequence.Element: Sendable {
    fileprivate let elements: Sequence

    init(elements: Sequence) {
        self.elements = elements
        super.init()
    }

    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> AsynchronousDisposable where
        Observer.Element == Element {

        for element in elements {
            await observer.on(.next(element), c.call())
        }
        await observer.on(.completed, c.call())

        return Disposables.create {}
    }
}
