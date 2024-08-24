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
        SwitchIfEmpty(source: asObservable(), ifEmpty: other)
    }
}

private final class SwitchIfEmpty<Element: Sendable>: Producer<Element> {
    private let source: Observable<Element>
    private let ifEmpty: Observable<Element>

    init(source: Observable<Element>, ifEmpty: Observable<Element>) {
        self.source = source
        self.ifEmpty = ifEmpty
        super.init()
    }

    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> AsynchronousDisposable
        where Observer.Element == Element {
        let sink = SwitchIfEmptySink(
            ifEmpty: ifEmpty,
            observer: observer
        )
        await sink.run(source.asObservable(), c.call())

        return sink
    }
}

private final actor SwitchIfEmptySink<Observer: ObserverType>: Sink,
    ObserverType {
    typealias Element = Observer.Element

    private let ifEmpty: Observable<Element>
    private var isEmpty = true
    private let sourceSubscription: SingleAssignmentDisposable
    private let ifEmptySubscription: SingleAssignmentDisposable
    let baseSink: BaseSink<Observer>

    init(ifEmpty: Observable<Element>, observer: Observer) {
        self.ifEmpty = ifEmpty
        sourceSubscription = SingleAssignmentDisposable()
        ifEmptySubscription = SingleAssignmentDisposable()
        baseSink = BaseSink(observer: observer)
    }

    func run(_ source: Observable<Observer.Element>, _ c: C) async {
        let subscription = await source.subscribe(c.call(), self)
        await sourceSubscription.setDisposable(subscription)?.dispose()
    }

    func on(_ event: Event<Element>, _ c: C) async {
        if baseSink.disposed {
            return
        }
        switch event {
        case .next:
            isEmpty = false
            await forwardOn(event, c.call())
        case .error:
            await forwardOn(event, c.call())
            await dispose()
        case .completed:
            guard isEmpty else {
                await forwardOn(.completed, c.call())
                await dispose()
                return
            }
            let ifEmptySink = SwitchIfEmptySinkIter(parent: self)
            await ifEmptySubscription.setDisposable(ifEmpty.subscribe(c.call(), ifEmptySink))?.dispose()
        }
    }

    func handleIfEmptyEvent(_ event: Event<Element>, _ c: C) async {
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
            await forwardOn(event, c.call())
            await dispose()
        }
    }

    func dispose() async {
        baseSink.setDisposed()
        async let disposeSource: ()? = sourceSubscription.dispose()?.dispose()
        async let disposeIfEmpty: ()? = ifEmptySubscription.dispose()?.dispose()

        await disposeSource
        await disposeIfEmpty
    }
}

private final class SwitchIfEmptySinkIter<Observer: ObserverType>:
    ObserverType {
    typealias Element = Observer.Element
    typealias Parent = SwitchIfEmptySink<Observer>

    private let parent: Parent

    init(parent: Parent) {
        self.parent = parent
    }

    func on(_ event: Event<Element>, _ c: C) async {
        await parent.handleIfEmptyEvent(event, c.call())
    }
}
