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
    func toArray() async
        -> Single<[Element]>
    {
        await PrimitiveSequence(raw: ToArray(source: self.asObservable()))
    }
}

private final class ToArraySink<SourceType, Observer: ObserverType>: Sink<Observer>, ObserverType where Observer.Element == [SourceType] {
    typealias Parent = ToArray<SourceType>
    
    let parent: Parent
    var list = [SourceType]()
    
    init(parent: Parent, observer: Observer, cancel: Cancelable) async {
        self.parent = parent
        
        await super.init(observer: observer, cancel: cancel)
    }
    
    func on(_ event: Event<SourceType>, _ c: C) async {
        switch event {
        case .next(let value):
            self.list.append(value)
        case .error(let e):
            await self.forwardOn(.error(e), c.call())
            await self.dispose()
        case .completed:
            await self.forwardOn(.next(self.list), c.call())
            await self.forwardOn(.completed, c.call())
            await self.dispose()
        }
    }
}

private final class ToArray<SourceType>: Producer<[SourceType]> {
    let source: Observable<SourceType>

    init(source: Observable<SourceType>) async {
        self.source = source
        await super.init()
    }
    
    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer, cancel: Cancelable) async -> (sink: Disposable, subscription: Disposable) where Observer.Element == [SourceType] {
        let sink = await ToArraySink(parent: self, observer: observer, cancel: cancel)
        let subscription = await self.source.subscribe(C(), sink)
        return (sink: sink, subscription: subscription)
    }
}
