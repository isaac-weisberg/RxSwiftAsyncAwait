//
//  SwitchIfEmpty.swift
//  RxSwift
//
//  Created by sergdort on 23/12/2016.
//  Copyright © 2016 Krunoslav Zaher. All rights reserved.
//

public extension ObservableType {
    /**
     Returns the elements of the specified sequence or `switchTo` sequence if the sequence is empty.

     - seealso: [DefaultIfEmpty operator on reactivex.io](http://reactivex.io/documentation/operators/defaultifempty.html)

     - parameter other: Observable sequence being returned when source sequence is empty.
     - returns: Observable sequence that contains elements from switchTo sequence if source is empty, otherwise returns source sequence elements.
     */
    func ifEmpty(switchTo other: Observable<Element>) -> Observable<Element> {
        SwitchIfEmpty(source: self.asObservable(), ifEmpty: other)
    }
}

private final class SwitchIfEmpty<Element>: Producer<Element> {
    private let source: Observable<Element>
    private let ifEmpty: Observable<Element>
    
    init(source: Observable<Element>, ifEmpty: Observable<Element>) {
        self.source = source
        self.ifEmpty = ifEmpty
    }
    
    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) async -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        let sink = await SwitchIfEmptySink(ifEmpty: self.ifEmpty,
                                           observer: observer,
                                           cancel: cancel)
        let subscription = await sink.run(self.source.asObservable())
        
        return (sink: sink, subscription: subscription)
    }
}

private final class SwitchIfEmptySink<Observer: ObserverType>: Sink<Observer>,
    ObserverType
{
    typealias Element = Observer.Element
    
    private let ifEmpty: Observable<Element>
    private var isEmpty = true
    private let ifEmptySubscription: SingleAssignmentDisposable
    
    init(ifEmpty: Observable<Element>, observer: Observer, cancel: Cancelable) async {
        self.ifEmpty = ifEmpty
        self.ifEmptySubscription = await SingleAssignmentDisposable()
        await super.init(observer: observer, cancel: cancel)
    }
    
    func run(_ source: Observable<Observer.Element>) async -> Disposable {
        let subscription = await source.subscribe(self)
        return await Disposables.create(subscription, self.ifEmptySubscription)
    }
    
    func on(_ event: Event<Element>) async {
        switch event {
        case .next:
            self.isEmpty = false
            await self.forwardOn(event)
        case .error:
            await self.forwardOn(event)
            await self.dispose()
        case .completed:
            guard self.isEmpty else {
                await self.forwardOn(.completed)
                await self.dispose()
                return
            }
            let ifEmptySink = SwitchIfEmptySinkIter(parent: self)
            await self.ifEmptySubscription.setDisposable(self.ifEmpty.subscribe(ifEmptySink))
        }
    }
}

private final class SwitchIfEmptySinkIter<Observer: ObserverType>:
    ObserverType
{
    typealias Element = Observer.Element
    typealias Parent = SwitchIfEmptySink<Observer>
    
    private let parent: Parent

    init(parent: Parent) {
        self.parent = parent
    }
    
    func on(_ event: Event<Element>) async {
        switch event {
        case .next:
            await self.parent.forwardOn(event)
        case .error:
            await self.parent.forwardOn(event)
            await self.parent.dispose()
        case .completed:
            await self.parent.forwardOn(event)
            await self.parent.dispose()
        }
    }
}
