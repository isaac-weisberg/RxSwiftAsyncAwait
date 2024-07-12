//
//  DefaultIfEmpty.swift
//  RxSwift
//
//  Created by sergdort on 23/12/2016.
//  Copyright © 2016 Krunoslav Zaher. All rights reserved.
//

public extension ObservableType {
    /**
     Emits elements from the source observable sequence, or a default element if the source observable sequence is empty.

     - seealso: [DefaultIfEmpty operator on reactivex.io](http://reactivex.io/documentation/operators/defaultifempty.html)

     - parameter default: Default element to be sent if the source does not emit any elements
     - returns: An observable sequence which emits default element end completes in case the original sequence is empty
     */
    func ifEmpty(default: Element) async -> Observable<Element> {
        await DefaultIfEmpty(source: self.asObservable(), default: `default`)
    }
}

private final class DefaultIfEmptySink<Observer: ObserverType>: Sink<Observer>, ObserverType {
    typealias Element = Observer.Element
    private let `default`: Element
    private var isEmpty = true

    init(default: Element, observer: Observer, cancel: Cancelable) async {
        self.default = `default`
        await super.init(observer: observer, cancel: cancel)
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
            if self.isEmpty {
                await self.forwardOn(.next(self.default))
            }
            await self.forwardOn(.completed)
            await self.dispose()
        }
    }
}

private final class DefaultIfEmpty<SourceType>: Producer<SourceType> {
    private let source: Observable<SourceType>
    private let `default`: SourceType

    init(source: Observable<SourceType>, default: SourceType) async {
        self.source = source
        self.default = `default`
        await super.init()
    }

    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) async -> (sink: Disposable, subscription: Disposable) where Observer.Element == SourceType {
        let sink = await DefaultIfEmptySink(default: self.default, observer: observer, cancel: cancel)
        let subscription = await self.source.subscribe(sink)
        return (sink: sink, subscription: subscription)
    }
}
