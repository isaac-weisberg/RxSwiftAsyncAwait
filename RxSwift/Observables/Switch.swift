////
////  Switch.swift
////  RxSwift
////
////  Created by Krunoslav Zaher on 3/12/15.
////  Copyright © 2015 Krunoslav Zaher. All rights reserved.
////
//
//public extension ObservableType {
//    /**
//     Projects each element of an observable sequence into a new sequence of observable sequences and then
//     transforms an observable sequence of observable sequences into an observable sequence producing values only from the most recent observable sequence.
//
//     It is a combination of `map` + `switchLatest` operator
//
//     - seealso: [flatMapLatest operator on reactivex.io](http://reactivex.io/documentation/operators/flatmap.html)
//
//     - parameter selector: A transform function to apply to each element.
//     - returns: An observable sequence whose elements are the result of invoking the transform function on each element of source producing an
//     Observable of Observable sequences and that at any point in time produces the elements of the most recent inner observable sequence that has been received.
//     */
//    func flatMapLatest<Source: ObservableConvertibleType>(_ selector: @Sendable @escaping (Element) throws -> Source)
//        -> Observable<Source.Element> {
//        FlatMapLatest(source: asObservable(), selector: selector)
//    }
//
//    /**
//     Projects each element of an observable sequence into a new sequence of observable sequences and then
//     transforms an observable sequence of observable sequences into an observable sequence producing values only from the most recent observable sequence.
//
//     It is a combination of `map` + `switchLatest` operator
//
//     - seealso: [flatMapLatest operator on reactivex.io](http://reactivex.io/documentation/operators/flatmap.html)
//
//     - parameter selector: A transform function to apply to each element.
//     - returns: An observable sequence whose elements are the result of invoking the transform function on each element of source producing an
//     Observable of Observable sequences and that at any point in time produces the elements of the most recent inner observable sequence that has been received.
//     */
//    func flatMapLatest<Source: InfallibleType>(_ selector: @Sendable @escaping (Element) throws -> Source)
//        -> Infallible<Source.Element> {
//        Infallible(flatMapLatest(selector))
//    }
//}
//
//public extension ObservableType where Element: ObservableConvertibleType {
//    /**
//     Transforms an observable sequence of observable sequences into an observable sequence
//     producing values only from the most recent observable sequence.
//
//     Each time a new inner observable sequence is received, unsubscribe from the
//     previous inner observable sequence.
//
//     - seealso: [switch operator on reactivex.io](http://reactivex.io/documentation/operators/switch.html)
//
//     - returns: The observable sequence that at any point in time produces the elements of the most recent inner observable sequence that has been received.
//     */
//    func switchLatest() -> Observable<Element.Element> {
//        Switch(source: asObservable())
//    }
//}
//
//// MARK: Producers
//
//private final class Switch<Source: ObservableConvertibleType>: Producer<Source.Element> {
//    private let source: Observable<Source>
//
//    init(source: Observable<Source>) {
//        self.source = source
//        super.init()
//    }
//
//    override func run<Observer>(_ c: C, _ observer: Observer) async -> any AsynchronousDisposable
//        where Source.Element == Observer.Element, Observer: ObserverType {
//        let sink = TotalFlatMapSink(
//            mode: .flatMapLatest(
//                TotalFlatMapSink.Mode.FlatMap(
//                    source: source,
//                    selector: { $0 }
//                )
//            ),
//            observer: observer
//        )
//        await sink.run(c.call())
//        return sink
//    }
//}
//
//private final class FlatMapLatest<
//    Source: Sendable,
//    DerivedSequence: ObservableConvertibleType
//>: Producer<DerivedSequence.Element> {
//    typealias Selector = @Sendable (Source) throws -> DerivedSequence
//
//    private let source: Observable<Source>
//    private let selector: Selector
//
//    init(source: Observable<Source>, selector: @escaping Selector) {
//        self.source = source
//        self.selector = selector
//        super.init()
//    }
//
//    override func run<Observer>(_ c: C, _ observer: Observer) async -> any AsynchronousDisposable
//        where DerivedSequence.Element == Observer.Element, Observer: ObserverType {
//        let sink = TotalFlatMapSink(
//            mode: .flatMapLatest(
//                TotalFlatMapSink.Mode.FlatMap(
//                    source: source,
//                    selector: selector
//                )
//            ),
//            observer: observer
//        )
//        await sink.run(c.call())
//        return sink
//    }
//}
