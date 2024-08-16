////
////  SwitchIfEmpty.swift
////  RxSwift
////
////  Created by sergdort on 23/12/2016.
////  Copyright © 2016 Krunoslav Zaher. All rights reserved.
////
//
//public extension ObservableType {
//    /**
//     Returns the elements of the specified sequence or `switchTo` sequence if the sequence is empty.
//
//     - seealso: [DefaultIfEmpty operator on reactivex.io](http://reactivex.io/documentation/operators/defaultifempty.html)
//
//     - parameter other: Observable sequence being returned when source sequence is empty.
//     - returns: Observable sequence that contains elements from switchTo sequence if source is empty, otherwise returns source sequence elements.
//     */
//    func ifEmpty(switchTo other: Observable<Element>) async -> Observable<Element> {
//        await SwitchIfEmpty(source: self.asObservable(), ifEmpty: other)
//    }
//}
//
//private final class SwitchIfEmpty<Element>: Producer<Element> {
//    private let source: Observable<Element>
//    private let ifEmpty: Observable<Element>
//    
//    init(source: Observable<Element>, ifEmpty: Observable<Element>) async {
//        self.source = source
//        self.ifEmpty = ifEmpty
//        await super.init()
//    }
//    
//    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> AsynchronousDisposable where Observer.Element == Element {
//        let sink = await SwitchIfEmptySink(ifEmpty: self.ifEmpty,
//                                           observer: observer,
//                                           cancel: cancel)
//        let subscription = await sink.run(self.source.asObservable(), c.call())
//        
//        return sink
//    }
//}
//
//private final actor SwitchIfEmptySink<Observer: ObserverType>: Sink,
//    ObserverType
//{
//    typealias Element = Observer.Element
//    
//    private let ifEmpty: Observable<Element>
//    private var isEmpty = true
//    private let ifEmptySubscription: SingleAssignmentDisposable
//    let baseSink: BaseSink<Observer>
//    
//    init(ifEmpty: Observable<Element>, observer: Observer) async {
//        self.ifEmpty = ifEmpty
//        self.ifEmptySubscription = await SingleAssignmentDisposable()
//        self.baseSink = BaseSink(observer: observer)
//    }
//    
//    func run(_ source: Observable<Observer.Element>, _ c: C) async -> Disposable {
//        let subscription = await source.subscribe(c.call(), self)
//        return await Disposables.create(subscription, self.ifEmptySubscription)
//    }
//    
//    func on(_ event: Event<Element>, _ c: C) async {
//        switch event {
//        case .next:
//            self.isEmpty = false
//            await self.forwardOn(event, c.call())
//        case .error:
//            await self.forwardOn(event, c.call())
//            await self.dispose()
//        case .completed:
//            guard self.isEmpty else {
//                await self.forwardOn(.completed, c.call())
//                await self.dispose()
//                return
//            }
//            let ifEmptySink = SwitchIfEmptySinkIter(parent: self)
//            await self.ifEmptySubscription.setDisposable(self.ifEmpty.subscribe(c.call(), ifEmptySink))
//        }
//    }
//}
//
//private final class SwitchIfEmptySinkIter<Observer: ObserverType>:
//    ObserverType
//{
//    typealias Element = Observer.Element
//    typealias Parent = SwitchIfEmptySink<Observer>
//    
//    private let parent: Parent
//
//    init(parent: Parent) {
//        self.parent = parent
//    }
//    
//    func on(_ event: Event<Element>, _ c: C) async {
//        switch event {
//        case .next:
//            await self.parent.forwardOn(event, c.call())
//        case .error:
//            await self.parent.forwardOn(event, c.call())
//            await self.parent.dispose()
//        case .completed:
//            await self.parent.forwardOn(event, c.call())
//            await self.parent.dispose()
//        }
//    }
//}
