//
//  GroupBy.swift
//  RxSwift
//
//  Created by Tomi Koskinen on 01/12/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

public extension ObservableType {
    /*
     Groups the elements of an observable sequence according to a specified key selector function.

     - seealso: [groupBy operator on reactivex.io](http://reactivex.io/documentation/operators/groupby.html)

     - parameter keySelector: A function to extract the key for each element.
     - returns: A sequence of observable groups, each of which corresponds to a unique key value, containing all elements that share that same key value.
     */
    func groupBy<Key: Hashable>(keySelector: @escaping (Element) throws -> Key) async
        -> Observable<GroupedObservable<Key, Element>>
    {
        await GroupBy(source: self.asObservable(), selector: keySelector)
    }
}

private final class GroupedObservableImpl<Element>: Observable<Element> {
    private var subject: PublishSubject<Element>
    private var refCount: RefCountDisposable

    init(subject: PublishSubject<Element>, refCount: RefCountDisposable) async {
        self.subject = subject
        self.refCount = refCount
        await super.init()
    }

    override public func subscribe<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> Disposable where Observer.Element == Element {
        let release = await self.refCount.retain()
        let subscription = await self.subject.subscribe(c.call(), observer)
        return await Disposables.create(release, subscription)
    }
}

private final class GroupBySink<Key: Hashable, Element, Observer: ObserverType>:
    Sink<Observer>,
    ObserverType where Observer.Element == GroupedObservable<Key, Element>
{
    typealias ResultType = Observer.Element
    typealias Parent = GroupBy<Key, Element>

    private let parent: Parent
    private let subscription: SingleAssignmentDisposable
    private var refCountDisposable: RefCountDisposable!
    private var groupedSubjectTable: [Key: PublishSubject<Element>]

    init(parent: Parent, observer: Observer, cancel: Cancelable) async {
        self.subscription = await SingleAssignmentDisposable()
        self.parent = parent
        self.groupedSubjectTable = [Key: PublishSubject<Element>]()
        await super.init(observer: observer, cancel: cancel)
    }

    func run(_ c: C) async -> Disposable {
        self.refCountDisposable = await RefCountDisposable(disposable: self.subscription)

        await self.subscription.setDisposable(self.parent.source.subscribe(c.call(), self))

        return self.refCountDisposable
    }

    private func onGroupEvent(key: Key, value: Element) async {
        if let writer = self.groupedSubjectTable[key] {
            await writer.on(.next(value), C())
        } else {
            let writer = await PublishSubject<Element>()
            self.groupedSubjectTable[key] = writer

            let group = await GroupedObservable(
                key: key,
                source: GroupedObservableImpl(subject: writer, refCount: refCountDisposable)
            )

            await self.forwardOn(.next(group), C())
            await writer.on(.next(value), C())
        }
    }

    final func on(_ event: Event<Element>, _ c: C) async {
        switch event {
        case let .next(value):
            do {
                let groupKey = try self.parent.selector(value)
                await self.onGroupEvent(key: groupKey, value: value)
            } catch let e {
                await self.error(e)
                return
            }
        case let .error(e):
            await self.error(e)
        case .completed:
            await self.forwardOnGroups(event: .completed)
            await self.forwardOn(.completed, c.call())
            await self.subscription.dispose()
            await self.dispose()
        }
    }

    final func error(_ error: Swift.Error) async {
        await self.forwardOnGroups(event: .error(error))
        await self.forwardOn(.error(error), C())
        await self.subscription.dispose()
        await self.dispose()
    }

    final func forwardOnGroups(event: Event<Element>) async {
        for writer in self.groupedSubjectTable.values {
            await writer.on(event, C())
        }
    }
}

private final class GroupBy<Key: Hashable, Element>: Producer<GroupedObservable<Key, Element>> {
    typealias KeySelector = (Element) throws -> Key

    fileprivate let source: Observable<Element>
    fileprivate let selector: KeySelector

    init(source: Observable<Element>, selector: @escaping KeySelector) async {
        self.source = source
        self.selector = selector
        await super.init()
    }

    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer, cancel: Cancelable) async -> (sink: Disposable, subscription: Disposable) where Observer.Element == GroupedObservable<Key, Element> {
        let sink = await GroupBySink(parent: self, observer: observer, cancel: cancel)
        return (sink: sink, subscription: await sink.run(C()))
    }
}
