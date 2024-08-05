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
        await DefaultIfEmpty(source: asObservable(), default: `default`)
    }
}

private final actor DefaultIfEmptySink<Observer: ObserverType>: Sink, ObserverType {
    typealias Element = Observer.Element
    private let `default`: Element
    private var isEmpty = true
    let baseSink: BaseSink<Observer>

    init(default: Element, observer: Observer) async {
        self.default = `default`
        baseSink = BaseSink(observer: observer)
    }

    func on(_ event: Event<Element>, _ c: C) async {
        switch event {
        case .next:
            isEmpty = false
            await forwardOn(event, c.call())
        case .error:
            await forwardOn(event, c.call())
            await dispose()
        case .completed:
            if isEmpty {
                await forwardOn(.next(self.default), c.call())
            }
            await forwardOn(.completed, c.call())
            await dispose()
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

    override func run<Observer: ObserverType>(
        _ c: C,
        _ observer: Observer
    )
        async -> SynchronizedDisposable where Observer.Element == SourceType {
        let sink = await DefaultIfEmptySink(default: self.default, observer: observer)
        let subscription = await source.subscribe(c.call(), sink)
        return sink
    }
}
