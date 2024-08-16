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
    func ifEmpty(default: Element) -> Observable<Element> {
        DefaultIfEmpty(source: asObservable(), default: `default`)
    }
}

private final actor DefaultIfEmptySink<Observer: ObserverType>: SinkOverSingleSubscription, ObserverType {
    typealias Element = Observer.Element
    private let `default`: Element
    private var isEmpty = true
    let baseSink: BaseSinkOverSingleSubscription<Observer>

    init(default: Element, observer: Observer) async {
        self.default = `default`
        baseSink = BaseSinkOverSingleSubscription(observer: observer)
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

    func dispose() async {
        await baseSink.setDisposed()?.dispose()
    }
}

private final class DefaultIfEmpty<SourceType: Sendable>: Producer<SourceType> {
    private let source: Observable<SourceType>
    private let `default`: SourceType

    init(source: Observable<SourceType>, default: SourceType) {
        self.source = source
        self.default = `default`
        super.init()
    }

    override func run<Observer: ObserverType>(
        _ c: C,
        _ observer: Observer
    )
        async -> AsynchronousDisposable where Observer.Element == SourceType {
        let sink = await DefaultIfEmptySink(default: self.default, observer: observer)
        await sink.run(c.call(), source)
        return sink
    }
}
