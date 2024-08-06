////
////  GroupBy.swift
////  RxSwift
////
////  Created by Tomi Koskinen on 01/12/15.
////  Copyright © 2015 Krunoslav Zaher. All rights reserved.
////
//
// public extension ObservableType {
//    /*
//     Groups the elements of an observable sequence according to a specified key selector function.
//
//     - seealso: [groupBy operator on reactivex.io](http://reactivex.io/documentation/operators/groupby.html)
//
//     - parameter keySelector: A function to extract the key for each element.
//     - returns: A sequence of observable groups, each of which corresponds to a unique key value, containing all
//     elements that share that same key value.
//     */
//    func groupBy<Key: Hashable>(keySelector: @escaping (Element) throws -> Key) async
//        -> Observable<GroupedObservable<Key, Element>> {
//        await GroupBy(source: asObservable(), selector: keySelector)
//    }
// }
//
// private final class GroupedObservableImpl<Element>: Observable<Element> {
//    private var subject: PublishSubject<Element>
//    private var refCount: RefCountDisposable
//
//    init(subject: PublishSubject<Element>, refCount: RefCountDisposable) async {
//        self.subject = subject
//        self.refCount = refCount
//        await super.init()
//    }
//
//    override public func subscribe<Observer: ObserverType>(_ c: C, _ observer: Observer) async ->
//    AsynchronousDisposable
//        where Observer.Element == Element {
//        let release = await refCount.retain()
//        let subscription = await subject.subscribe(c.call(), observer)
//        return await Disposables.create(release, subscription)
//    }
// }
//
// private final actor GroupBySink<Key: Hashable, Element, Observer: ObserverType>:
//    Sink,
//    ObserverType where Observer.Element == GroupedObservable<Key, Element> {
//    typealias ResultType = Observer.Element
//    typealias Parent = GroupBy<Key, Element>
//
//    let baseSink: BaseSink<Observer>
//    private let parent: Parent
//    private let subscription: SingleAssignmentDisposable
//    private var refCountDisposable: RefCountDisposable!
//    private var groupedSubjectTable: [Key: PublishSubject<Element>]
//
//    init(parent: Parent, observer: Observer) async {
//        subscription = await SingleAssignmentDisposable()
//        self.parent = parent
//        groupedSubjectTable = [Key: PublishSubject<Element>]()
//        baseSink = BaseSink(observer: observer)
//    }
//
//    func run(_ c: C) async -> Disposable {
//        refCountDisposable = await RefCountDisposable(disposable: subscription)
//
//        await subscription.setDisposable(parent.source.subscribe(c.call(), self))
//
//        return refCountDisposable
//    }
//
//    private func onGroupEvent(_ c: C, key: Key, value: Element) async {
//        if let writer = groupedSubjectTable[key] {
//            await writer.on(.next(value), c.call())
//        } else {
//            let writer = await PublishSubject<Element>()
//            groupedSubjectTable[key] = writer
//
//            let group = await GroupedObservable(
//                key: key,
//                source: GroupedObservableImpl(subject: writer, refCount: refCountDisposable)
//            )
//
//            await forwardOn(.next(group), c.call())
//            await writer.on(.next(value), c.call())
//        }
//    }
//
//    final func on(_ event: Event<Element>, _ c: C) async {
//        switch event {
//        case .next(let value):
//            do {
//                let groupKey = try parent.selector(value)
//                await onGroupEvent(c.call(), key: groupKey, value: value)
//            } catch let e {
//                await self.error(c.call(), e)
//                return
//            }
//        case .error(let e):
//            await error(c.call(), e)
//        case .completed:
//            await forwardOnGroups(c.call(), event: .completed)
//            await forwardOn(.completed, c.call())
//            await subscription.dispose()
//            await dispose()
//        }
//    }
//
//    final func error(_ c: C, _ error: Swift.Error) async {
//        await forwardOnGroups(c.call(), event: .error(error))
//        await forwardOn(.error(error), c.call())
//        await subscription.dispose()
//        await dispose()
//    }
//
//    final func forwardOnGroups(_ c: C, event: Event<Element>) async {
//        for writer in groupedSubjectTable.values {
//            await writer.on(event, c.call())
//        }
//    }
// }
//
// private final class GroupBy<Key: Hashable, Element>: Producer<GroupedObservable<Key, Element>> {
//    typealias KeySelector = (Element) throws -> Key
//
//    fileprivate let source: Observable<Element>
//    fileprivate let selector: KeySelector
//
//    init(source: Observable<Element>, selector: @escaping KeySelector) async {
//        self.source = source
//        self.selector = selector
//        await super.init()
//    }
//
//    override func run<Observer: ObserverType>(
//        _ c: C,
//        _ observer: Observer,
//        cancel: AsynchronousCancelable
//    )
//        async -> (sink: SynchronousDisposable, subscription: SynchronousDisposable)
//        where Observer.Element == GroupedObservable<
//            Key,
//            Element
//        > {
//        let sink = await GroupBySink(parent: self, observer: observer)
//        return await (sink: sink, subscription: sink.run(c.call()))
//    }
// }
