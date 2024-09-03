//
//  ToArray.swift
//  RxSwift
//
//  Created by Junior B. on 20/10/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

public extension ObservableType {
    /**
     Converts an Observable into a Single that emits the whole sequence as a single array and then terminates.

     For aggregation behavior see `reduce`.

     - seealso: [toArray operator on reactivex.io](http://reactivex.io/documentation/operators/to.html)

     - returns: A Single sequence containing all the emitted elements as array.
     */
    func toArray() -> Single<[Element]> {
        PrimitiveSequence(raw: ToArray(source: asObservable()))
    }
}

private final actor ToArraySink<SourceType, Observer: ObserverType>: SinkOverSingleSubscription,
    ObserverType where Observer.Element == [SourceType] {
    typealias Parent = ToArray<SourceType>

    let parent: Parent
    var list = [SourceType]()
    let baseSink: BaseSinkOverSingleSubscription<Observer>

    init(parent: Parent, observer: Observer) {
        self.parent = parent

        baseSink = BaseSinkOverSingleSubscription(observer: observer)
    }

    func dispose() async {
        await baseSink.setDisposed()?.dispose()
    }

    func on(_ event: Event<SourceType>, _ c: C) async {
        if baseSink.disposed {
            return
        }
        switch event {
        case .next(let value):
            list.append(value)
        case .error(let e):
            await forwardOn(.error(e), c.call())
            await dispose()
        case .completed:
            await forwardOn(.next(list), c.call())
            await forwardOn(.completed, c.call())
            await dispose()
        }
    }
}

private final class ToArray<SourceType: Sendable>: Producer<[SourceType]> {
    let source: Observable<SourceType>

    init(source: Observable<SourceType>) {
        self.source = source
        super.init()
    }

    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> AsynchronousDisposable
        where Observer.Element == [SourceType] {
        let sink = ToArraySink(parent: self, observer: observer)
        await sink.run(c.call(), source)
        return sink
    }
}
