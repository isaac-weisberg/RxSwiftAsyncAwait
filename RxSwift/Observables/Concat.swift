//
//  Concat.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 3/21/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

public extension ObservableType {
    /**
     Concatenates the second observable sequence to `self` upon successful termination of `self`.

     - seealso: [concat operator on reactivex.io](http://reactivex.io/documentation/operators/concat.html)

     - parameter second: Second observable sequence.
     - returns: An observable sequence that contains the elements of `self`, followed by those of the second sequence.
     */
    func concat<Source: ObservableConvertibleType>(_ second: Source) -> Observable<Element>
        where Source.Element == Element {
        Observable.concat([asObservable(), second.asObservable()])
    }
}

public extension ObservableType {
    /**
     Concatenates all observable sequences in the given sequence, as long as the previous observable sequence terminated successfully.

     This operator has tail recursive optimizations that will prevent stack overflow.

     Optimizations will be performed in cases equivalent to following:

     [1, [2, [3, .....].concat()].concat].concat()

     - seealso: [concat operator on reactivex.io](http://reactivex.io/documentation/operators/concat.html)

     - returns: An observable sequence that contains the elements of each given sequence, in sequential order.
     */
    static func concat<Sequence: Swift.Sequence>(_ sequence: Sequence) -> Observable<Element>
        where Sequence.Element == Observable<Element> {
        Concat(sources: sequence, count: nil)
    }

    /**
     Concatenates all observable sequences in the given collection, as long as the previous observable sequence terminated successfully.

     This operator has tail recursive optimizations that will prevent stack overflow.

     Optimizations will be performed in cases equivalent to following:

     [1, [2, [3, .....].concat()].concat].concat()

     - seealso: [concat operator on reactivex.io](http://reactivex.io/documentation/operators/concat.html)

     - returns: An observable sequence that contains the elements of each given sequence, in sequential order.
     */
    static func concat<Collection: Swift.Collection>(_ collection: Collection) -> Observable<Element>
        where Collection.Element == Observable<Element> {
        Concat(sources: collection)
    }

    /**
     Concatenates all observable sequences in the given collection, as long as the previous observable sequence terminated successfully.

     This operator has tail recursive optimizations that will prevent stack overflow.

     Optimizations will be performed in cases equivalent to following:

     [1, [2, [3, .....].concat()].concat].concat()

     - seealso: [concat operator on reactivex.io](http://reactivex.io/documentation/operators/concat.html)

     - returns: An observable sequence that contains the elements of each given sequence, in sequential order.
     */
    static func concat(_ sources: Observable<Element> ...) -> Observable<Element> {
        Concat(sources: sources)
    }
}

private final actor ConcatSink<Sequence: Swift.Sequence, Observer: ObserverType>: Sink, ObserverType
    where Sequence.Element: ObservableConvertibleType, Sequence.Element.Element == Observer.Element {
    typealias Element = Observer.Element

    let baseSink: BaseSink<Observer>
    var sourcesIterator: Sequence.Iterator
    let serialDisposable = SerialDisposableGeneric<Disposable>()

    init(sources: Sequence, observer: Observer) {
        baseSink = BaseSink(observer: observer)
        sourcesIterator = sources.makeIterator()
    }

    func run(_ c: C) async {
        await runNext(c.call())
    }

    func runNext(_ c: C) async {
        if baseSink.disposed {
            return
        }

        if let nextObservableConvertibleType = sourcesIterator.next() {

            let observable = nextObservableConvertibleType.asObservable()

            let subscription = await observable.subscribe(c.call(), self)
            await serialDisposable.replace(subscription)?.dispose()
            return
        } else {
            await dispose()
        }
    }

    func on(_ event: Event<Element>, _ c: C) async {
        if baseSink.disposed {
            return
        }
        switch event {
        case .next:
            await forwardOn(event, c.call())
        case .error:
            await forwardOn(event, c.call())
            await dispose()
        case .completed:
            await runNext(c.call())
        }
    }

    func dispose() async {
        baseSink.setDisposed()
        await serialDisposable.dispose()?.dispose()
    }
}

private final class Concat<Sequence: Swift.Sequence & Sendable>: Producer<Sequence.Element.Element>
    where Sequence.Element: ObservableConvertibleType {
    typealias Element = Sequence.Element.Element

    fileprivate let sources: Sequence

    init(sources: Sequence) {
        self.sources = sources
        super.init()
    }

    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> AsynchronousDisposable
        where Observer.Element == Element {
        let sink = ConcatSink<Sequence, Observer>(sources: sources, observer: observer)
        await sink.run(c.call())
        return sink
    }
}
