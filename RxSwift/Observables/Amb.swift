//
//  Amb.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 6/14/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

public extension ObservableType {
    /**
     Propagates the observable sequence that reacts first.

     - seealso: [amb operator on reactivex.io](http://reactivex.io/documentation/operators/amb.html)

     - returns: An observable sequence that surfaces any of the given sequences, whichever reacted first.
     */
    static func amb<Sequence: Swift.Sequence>(_ sequence: Sequence) -> Observable<Element>
        where Sequence.Element == Observable<Element> {
        sequence.reduceAsync(Observable<Sequence.Element.Element>.never()) { a, o in
            a.amb(o.asObservable())
        }
    }
}

public extension Sequence {
    @inlinable func reduceAsync<Result>(
        _ initialResult: Result,
        _ nextPartialResult: (_ partialResult: Result, Self.Element) throws -> Result
    )
        rethrows -> Result {
        var initial = initialResult
        var iterator = makeIterator()
        while let element = iterator.next() {
            initial = try nextPartialResult(initial, element)
        }

        return initial
    }
}

public extension ObservableType {
    /**
     Propagates the observable sequence that reacts first.

     - seealso: [amb operator on reactivex.io](http://reactivex.io/documentation/operators/amb.html)

     - parameter right: Second observable sequence.
     - returns: An observable sequence that surfaces either of the given sequences, whichever reacted first.
     */
    func amb<O2: ObservableType>
    (_ right: O2)
        -> Observable<Element> where O2.Element == Element {
        Amb(left: asObservable(), right: right.asObservable())
    }
}

private enum AmbState {
    case neither
    case left
    case right
}
//
//private final class AmbObserver<Observer: ObserverType>: ObserverType {
//    typealias Element = Observer.Element
//    typealias Parent = AmbSink<Observer>
//    typealias This = AmbObserver<Observer>
//    typealias Sink = (This, Event<Element>) async -> Void
//
//    private let parent: Parent
//    fileprivate var sink: Sink
//    fileprivate var cancel: Disposable
//
//    init(parent: Parent, cancel: Disposable, sink: @escaping Sink) async {
//        #if TRACE_RESOURCES
//            _ = await Resources.incrementTotal()
//        #endif
//
//        self.parent = parent
//        self.sink = sink
//        self.cancel = cancel
//    }
//
//    func on(_ event: Event<Element>, _ c: C) async {
//        await sink(self, event)
//        if event.isStopEvent {
//            await cancel.dispose()
//        }
//    }
//
//    deinit {
//        #if TRACE_RESOURCES
//            Task {
//                _ = await Resources.decrementTotal()
//            }
//        #endif
//    }
//}
//
//private final actor AmbSink<Observer: ObserverType>: Sink {
//    typealias Element = Observer.Element
//    typealias Parent = Amb<Element>
//    typealias AmbObserverType = AmbObserver<Observer>
//
//    private let parent: Parent
//
//    let baseSink: BaseSink<Observer>
//    // state
//    private var choice = AmbState.neither
//    let subscription1 = SingleAssignmentDisposable()
//    let subscription2 = SingleAssignmentDisposable()
//    let disposeAll: BinaryDisposable
//
//    init(parent: Parent, observer: Observer) async {
//        self.parent = parent
//        disposeAll = BinaryDisposable(subscription1, subscription2)
//        baseSink = BaseSink(observer: observer)
//    }
//
//    func run(_ c: C) async {
//        let forwardEvent = { (_: AmbObserverType, event: Event<Element>) async in
//            await self.forwardOn(event, c.call())
//            if event.isStopEvent {
//                await self.dispose()
//            }
//        }
//
//        let decide = { (o: AmbObserverType, event: Event<Element>, me: AmbState, otherSubscription: Disposable) in
//            if self.choice == .neither {
//                self.choice = me
//                o.sink = forwardEvent
//                o.cancel = disposeAll
//                await otherSubscription.dispose()
//            }
//
//            if self.choice == me {
//                await self.forwardOn(event, c.call())
//                if event.isStopEvent {
//                    await self.dispose()
//                }
//            }
//        }
//
//        let sink1 = await AmbObserver(parent: self, cancel: subscription1) { o, e in
//            await decide(o, e, .left, subscription2)
//        }
//
//        let sink2 = await AmbObserver(parent: self, cancel: subscription1) { o, e in
//            await decide(o, e, .right, subscription1)
//        }
//
//        await subscription1.setDisposable(parent.left.subscribe(c.call(), sink1))?.dispose()
//        await subscription2.setDisposable(parent.right.subscribe(c.call(), sink2))?.dispose()
//    }
//
//    func dispose() async {
//        await disposeAll.dispose()?.dispose()
//    }
//}

private final class Amb<Element: Sendable>: Producer<Element> {
    fileprivate let left: Observable<Element>
    fileprivate let right: Observable<Element>

    init(left: Observable<Element>, right: Observable<Element>) {
        self.left = left
        self.right = right
        super.init()
    }

    override func run<Observer: ObserverType>(
        _ c: C,
        _ observer: Observer
    )
        async -> AsynchronousDisposable
        where Observer.Element == Element {

        fatalError()
//            let sink = await AmbSink(parent: self, observer: observer)
//            await sink.run(c.call())
//            return sink
    }
}
