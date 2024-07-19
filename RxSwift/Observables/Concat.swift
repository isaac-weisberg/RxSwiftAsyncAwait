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
    func concat<Source: ObservableConvertibleType>(_ second: Source) async -> Observable<Element> where Source.Element == Element {
        await Observable.concat([self.asObservable(), second.asObservable()])
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
    static func concat<Sequence: Swift.Sequence>(_ sequence: Sequence) async -> Observable<Element>
        where Sequence.Element == Observable<Element>
    {
        return await Concat(sources: sequence, count: nil)
    }

    /**
     Concatenates all observable sequences in the given collection, as long as the previous observable sequence terminated successfully.

     This operator has tail recursive optimizations that will prevent stack overflow.

     Optimizations will be performed in cases equivalent to following:

     [1, [2, [3, .....].concat()].concat].concat()

     - seealso: [concat operator on reactivex.io](http://reactivex.io/documentation/operators/concat.html)

     - returns: An observable sequence that contains the elements of each given sequence, in sequential order.
     */
    static func concat<Collection: Swift.Collection>(_ collection: Collection) async -> Observable<Element>
        where Collection.Element == Observable<Element>
    {
        return await Concat(sources: collection, count: Int64(collection.count))
    }

    /**
     Concatenates all observable sequences in the given collection, as long as the previous observable sequence terminated successfully.

     This operator has tail recursive optimizations that will prevent stack overflow.

     Optimizations will be performed in cases equivalent to following:

     [1, [2, [3, .....].concat()].concat].concat()

     - seealso: [concat operator on reactivex.io](http://reactivex.io/documentation/operators/concat.html)

     - returns: An observable sequence that contains the elements of each given sequence, in sequential order.
     */
    static func concat(_ sources: Observable<Element> ...) async -> Observable<Element> {
        await Concat(sources: sources, count: Int64(sources.count))
    }
}

private final class ConcatSink<Sequence: Swift.Sequence, Observer: ObserverType>:
    TailRecursiveSink<Sequence, Observer>,
    ObserverType where Sequence.Element: ObservableConvertibleType, Sequence.Element.Element == Observer.Element
{
    typealias Element = Observer.Element

    override init(observer: Observer, cancel: Cancelable) async {
        await super.init(observer: observer, cancel: cancel)
    }

    func on(_ event: Event<Element>, _ c: C) async {
        switch event {
        case .next:
            await self.forwardOn(event, c.call())
        case .error:
            await self.forwardOn(event, c.call())
            await self.dispose()
        case .completed:
            await self.schedule(c.call(), .moveNext)
        }
    }

    override func subscribeToNext(_ c: C, _ source: Observable<Element>) async -> Disposable {
        await source.subscribe(c.call(), self)
    }

    override func extract(_ c: C, _ observable: Observable<Element>) -> SequenceGenerator? {
        if let source = observable as? Concat<Sequence> {
            return (source.sources.makeIterator(), source.count)
        }
        else {
            return nil
        }
    }
}

private final class Concat<Sequence: Swift.Sequence>: Producer<Sequence.Element.Element> where Sequence.Element: ObservableConvertibleType {
    typealias Element = Sequence.Element.Element

    fileprivate let sources: Sequence
    fileprivate let count: IntMax?

    init(sources: Sequence, count: IntMax?) async {
        self.sources = sources
        self.count = count
        await super.init()
    }

    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer, cancel: Cancelable) async -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        let sink = await ConcatSink<Sequence, Observer>(observer: observer, cancel: cancel)
        let subscription = await sink.run(c.call(), (self.sources.makeIterator(), self.count))
        return (sink: sink, subscription: subscription)
    }
}
