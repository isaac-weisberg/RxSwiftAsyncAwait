//
//  TakeLast.swift
//  RxSwift
//
//  Created by Tomi Koskinen on 25/10/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

public extension ObservableType {
    /**
     Returns a specified number of contiguous elements from the end of an observable sequence.

     This operator accumulates a buffer with a length enough to store elements count elements. Upon completion of the source sequence, this buffer is drained on the result sequence. This causes the elements to be delayed.

     - seealso: [takeLast operator on reactivex.io](http://reactivex.io/documentation/operators/takelast.html)

     - parameter count: Number of elements to take from the end of the source sequence.
     - returns: An observable sequence containing the specified number of elements from the end of the source sequence.
     */
    func takeLast(_ count: Int) async
        -> Observable<Element>
    {
        await TakeLast(source: self.asObservable(), count: count)
    }
}

private final class TakeLastSink<Observer: ObserverType>: Sink<Observer>, ObserverType {
    typealias Element = Observer.Element
    typealias Parent = TakeLast<Element>

    private let parent: Parent

    private var elements: Queue<Element>

    init(parent: Parent, observer: Observer, cancel: Cancelable) async {
        self.parent = parent
        self.elements = Queue<Element>(capacity: parent.count + 1)
        await super.init(observer: observer, cancel: cancel)
    }

    func on(_ event: Event<Element>, _ c: C) async {
        switch event {
        case .next(let value):
            self.elements.enqueue(value)
            if self.elements.count > self.parent.count {
                _ = self.elements.dequeue()
            }
        case .error:
            await self.forwardOn(event, c.call())
            await self.dispose()
        case .completed:
            for e in self.elements {
                await self.forwardOn(.next(e), c.call())
            }
            await self.forwardOn(.completed, c.call())
            await self.dispose()
        }
    }
}

private final class TakeLast<Element>: Producer<Element> {
    private let source: Observable<Element>
    fileprivate let count: Int

    init(source: Observable<Element>, count: Int) async {
        if count < 0 {
            rxFatalError("count can't be negative")
        }
        self.source = source
        self.count = count
        await super.init()
    }

    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer, cancel: Cancelable) async -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        let sink = await TakeLastSink(parent: self, observer: observer, cancel: cancel)
        let subscription = await self.source.subscribe(c.call(), sink)
        return (sink: sink, subscription: subscription)
    }
}
