////
////  Completable+AndThen.swift
////  RxSwift
////
////  Created by Krunoslav Zaher on 7/2/17.
////  Copyright © 2017 Krunoslav Zaher. All rights reserved.
////
//
//public extension PrimitiveSequenceType where Trait == CompletableTrait, Element == Never {
//    /**
//     Concatenates the second observable sequence to `self` upon successful termination of `self`.
//
//     - seealso: [concat operator on reactivex.io](http://reactivex.io/documentation/operators/concat.html)
//
//     - parameter second: Second observable sequence.
//     - returns: An observable sequence that contains the elements of `self`, followed by those of the second sequence.
//     */
//    func andThen<Element>(_ second: Single<Element>) async -> Single<Element> {
//        let completable = self.primitiveSequence.asObservable()
//        return await Single(raw: ConcatCompletable(completable: completable, second: second.asObservable()))
//    }
//
//    /**
//     Concatenates the second observable sequence to `self` upon successful termination of `self`.
//
//     - seealso: [concat operator on reactivex.io](http://reactivex.io/documentation/operators/concat.html)
//
//     - parameter second: Second observable sequence.
//     - returns: An observable sequence that contains the elements of `self`, followed by those of the second sequence.
//     */
//    func andThen<Element>(_ second: Maybe<Element>) async -> Maybe<Element> {
//        let completable = self.primitiveSequence.asObservable()
//        return await Maybe(raw: ConcatCompletable(completable: completable, second: second.asObservable()))
//    }
//
//    /**
//     Concatenates the second observable sequence to `self` upon successful termination of `self`.
//
//     - seealso: [concat operator on reactivex.io](http://reactivex.io/documentation/operators/concat.html)
//
//     - parameter second: Second observable sequence.
//     - returns: An observable sequence that contains the elements of `self`, followed by those of the second sequence.
//     */
//    func andThen(_ second: Completable) async -> Completable {
//        let completable = self.primitiveSequence.asObservable()
//        return await Completable(raw: ConcatCompletable(completable: completable, second: second.asObservable()))
//    }
//
//    /**
//     Concatenates the second observable sequence to `self` upon successful termination of `self`.
//
//     - seealso: [concat operator on reactivex.io](http://reactivex.io/documentation/operators/concat.html)
//
//     - parameter second: Second observable sequence.
//     - returns: An observable sequence that contains the elements of `self`, followed by those of the second sequence.
//     */
//    func andThen<Element>(_ second: Observable<Element>) async -> Observable<Element> {
//        let completable = self.primitiveSequence.asObservable()
//        return await ConcatCompletable(completable: completable, second: second.asObservable())
//    }
//}
//
//private final class ConcatCompletable<Element>: Producer<Element> {
//    fileprivate let completable: Observable<Never>
//    fileprivate let second: Observable<Element>
//
//    init(completable: Observable<Never>, second: Observable<Element>) async {
//        self.completable = completable
//        self.second = second
//        await super.init()
//    }
//
//    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> AsynchronousDisposable where Observer.Element == Element {
//        let sink = await ConcatCompletableSink(parent: self, observer: observer)
//        let subscription = await sink.run(c.call())
//        return sink
//    }
//}
//
//private final actor ConcatCompletableSink<Observer: ObserverType>:
//    Sink,
//    ObserverType
//{
//    typealias Element = Never
//    typealias Parent = ConcatCompletable<Observer.Element>
//
//    private let parent: Parent
//    private let subscription: SerialDisposable
//    let baseSink: BaseSink<Observer>
//
//    init(parent: Parent, observer: Observer) async {
//        self.subscription = await SerialDisposable()
//        self.parent = parent
//        self.baseSink = BaseSink(observer: observer)
//    }
//
//    func on(_ event: Event<Element>, _ c: C) async {
//        switch event {
//        case .error(let error):
//            await self.forwardOn(.error(error), c.call())
//            await self.dispose()
//        case .next:
//            break
//        case .completed:
//            let otherSink = ConcatCompletableSinkOther(parent: self)
//            await self.subscription.setDisposable(self.parent.second.subscribe(c.call(), otherSink))
//        }
//    }
//
//    func run(_ c: C) async -> Disposable {
//        let subscription = await SingleAssignmentDisposable()
//        await self.subscription.setDisposable(subscription)
//        await subscription.setDisposable(self.parent.completable.subscribe(c.call(), self))
//        return self.subscription
//    }
//}
//
//private final class ConcatCompletableSinkOther<Observer: ObserverType>:
//    ObserverType
//{
//    typealias Element = Observer.Element
//
//    typealias Parent = ConcatCompletableSink<Observer>
//
//    private let parent: Parent
//
//    init(parent: Parent) {
//        self.parent = parent
//    }
//
//    func on(_ event: Event<Observer.Element>, _ c: C) async {
//        await self.parent.forwardOn(event, c.call())
//        if event.isStopEvent {
//            await self.parent.dispose()
//        }
//    }
//}
