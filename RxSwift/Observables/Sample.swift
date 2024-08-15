////
////  Sample.swift
////  RxSwift
////
////  Created by Krunoslav Zaher on 5/1/15.
////  Copyright © 2015 Krunoslav Zaher. All rights reserved.
////
//
//public extension ObservableType {
//    /**
//     Samples the source observable sequence using a sampler observable sequence producing sampling ticks.
//
//     Upon each sampling tick, the latest element (if any) in the source sequence during the last sampling interval is sent to the resulting sequence.
//
//     **In case there were no new elements between sampler ticks, you may provide a default value to be emitted, instead
//       to the resulting sequence otherwise no element is sent.**
//
//     - seealso: [sample operator on reactivex.io](http://reactivex.io/documentation/operators/sample.html)
//
//     - parameter sampler: Sampling tick sequence.
//     - parameter defaultValue: a value to return if there are no new elements between sampler ticks
//     - returns: Sampled observable sequence.
//     */
//    func sample<Source: ObservableType>(_ sampler: Source, defaultValue: Element? = nil) async
//        -> Observable<Element>
//    {
//        return await Sample(source: self.asObservable(), sampler: sampler.asObservable(), defaultValue: defaultValue)
//    }
//}
//
//private final actor SamplerSink<Observer: ObserverType, SampleType>:
//    ObserverType,
//    AsynchronousOnType
//{
//    typealias Element = SampleType
//
//    typealias Parent = SampleSequenceSink<Observer, SampleType>
//
//    private let parent: Parent
//
//    init(parent: Parent) {
//        self.parent = parent
//    }
//
//    func on(_ event: Event<Element>, _ c: C) async {
//        await self.AsynchronousOn(event, c.call())
//    }
//
//    func Asynchronous_on(_ event: Event<Element>, _ c: C) async {
//        switch event {
//        case .next, .completed:
//            if let element = await parent.element ?? self.parent.defaultValue {
//                await self.parent.setElement(nil)
//                await self.parent.forwardOn(.next(element), c.call())
//            }
//
//            if await self.parent.atEnd {
//                await self.parent.forwardOn(.completed, c.call())
//                await self.parent.dispose()
//            }
//        case .error(let e):
//            await self.parent.forwardOn(.error(e), c.call())
//            await self.parent.dispose()
//        }
//    }
//}
//
//private final actor SampleSequenceSink<Observer: ObserverType, SampleType>:
//    Sink,
//    ObserverType,
//    AsynchronousOnType
//{
//    typealias Element = Observer.Element
//    typealias Parent = Sample<Element, SampleType>
//
//    fileprivate let parent: Parent
//    fileprivate let defaultValue: Element?
//
//    let baseSink: BaseSink<Observer>
//    
//    // state
//    fileprivate var element = nil as Element?
//    func setElement(_ element: Element?) {
//        self.element = element
//    }
//    fileprivate var atEnd = false
//
//    private let sourceSubscription: SingleAssignmentDisposable
//
//    init(parent: Parent, observer: Observer, cancel: Cancelable, defaultValue: Element? = nil) async {
//        self.sourceSubscription = await SingleAssignmentDisposable()
//        self.parent = parent
//        self.defaultValue = defaultValue
//        self.baseSink = BaseSink(observer: observer)
//    }
//
//    func run(_ c: C) async -> Disposable {
//        await self.sourceSubscription.setDisposable(self.parent.source.subscribe(c.call(), self))
//        let samplerSubscription = await self.parent.sampler.subscribe(c.call(), SamplerSink(parent: self))
//
//        return await Disposables.create(self.sourceSubscription, samplerSubscription)
//    }
//
//    func on(_ event: Event<Element>, _ c: C) async {
//        await self.AsynchronousOn(event, c.call())
//    }
//
//    func Asynchronous_on(_ event: Event<Element>, _ c: C) async {
//        switch event {
//        case .next(let element):
//            self.element = element
//        case .error:
//            await self.forwardOn(event, c.call())
//            await self.dispose()
//        case .completed:
//            self.atEnd = true
//            await self.sourceSubscription.dispose()
//        }
//    }
//}
//
//private final class Sample<Element, SampleType>: Producer<Element> {
//    fileprivate let source: Observable<Element>
//    fileprivate let sampler: Observable<SampleType>
//    fileprivate let defaultValue: Element?
//
//    init(source: Observable<Element>, sampler: Observable<SampleType>, defaultValue: Element? = nil) async {
//        self.source = source
//        self.sampler = sampler
//        self.defaultValue = defaultValue
//        await super.init()
//    }
//
//    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> AsynchronousDisposable where Observer.Element == Element {
//        let sink = await SampleSequenceSink(parent: self, observer: observer, cancel: cancel, defaultValue: self.defaultValue)
//        let subscription = await sink.run(c.call())
//        return sink
//    }
//}
