////
////  CombineLatest.swift
////  RxSwift
////
////  Created by Krunoslav Zaher on 3/21/15.
////  Copyright © 2015 Krunoslav Zaher. All rights reserved.
////
//
//protocol CombineLatestProtocol: AnyObject {
//    func next(_ c: C, _ index: Int) async
//    func fail(_ c: C, _ error: Swift.Error) async
//    func done(_ c: C, _ index: Int) async
//}
//
//actor CombineLatestSink<Observer: ObserverType>:
//    Sink,
//    CombineLatestProtocol {
//    typealias Element = Observer.Element
//
//    private let arity: Int
//    private var numberOfValues = 0
//    private var numberOfDone = 0
//    private var hasValue: [Bool]
//    private var isDone: [Bool]
//    private var disposed = false
//
//    let baseSink: BaseSink<Observer>
//
//    init(arity: Int, observer: Observer) async {
//        self.arity = arity
//        hasValue = [Bool](repeating: false, count: arity)
//        isDone = [Bool](repeating: false, count: arity)
//
//        baseSink = BaseSink(observer: observer)
//    }
//
//    func getResult() async throws -> Element {
//        rxAbstractMethod()
//    }
//
//    func next(_ c: C, _ index: Int) async {
//        if !hasValue[index] {
//            hasValue[index] = true
//            numberOfValues += 1
//        }
//
//        if numberOfValues == arity {
//            do {
//                let result = try await getResult()
//                await forwardOn(.next(result), c.call())
//            } catch let e {
//                await self.forwardOn(.error(e), c.call())
//                await self.dispose()
//            }
//        } else {
//            var allOthersDone = true
//
//            for i in 0 ..< arity {
//                if i != index, !isDone[i] {
//                    allOthersDone = false
//                    break
//                }
//            }
//
//            if allOthersDone {
//                await forwardOn(.completed, c.call())
//                await dispose()
//            }
//        }
//    }
//
//    func fail(_ c: C, _ error: Swift.Error) async {
//        await forwardOn(.error(error), c.call())
//        await dispose()
//    }
//
//    func done(_ c: C, _ index: Int) async {
//        if isDone[index] {
//            return
//        }
//
//        isDone[index] = true
//        numberOfDone += 1
//
//        if numberOfDone == arity {
//            await forwardOn(.completed, c.call())
//            await dispose()
//        }
//    }
//
//    func dispose() async {
//        if !disposed {
//            disposed = true
//        }
//    }
//
//    func forwardOn(_ event: Event<Observer.Element>, _ c: C) async {
//        if !disposed {
//            await baseSink.observer.on(event, c.call())
//        }
//    }
//}
//
//final class CombineLatestObserver<Element>:
//    ObserverType,
//    AsynchronousOnType {
//    typealias ValueSetter = (Element) -> Void
//
//    private let parent: CombineLatestProtocol
//
//    private let index: Int
//    private let this: AsynchronousDisposable
//    private let setLatestValue: ValueSetter
//
//    init(
//        parent: CombineLatestProtocol,
//        index: Int,
//        setLatestValue: @escaping ValueSetter,
//        this: AsynchronousDisposable
//    ) {
//        self.parent = parent
//        self.index = index
//        self.this = this
//        self.setLatestValue = setLatestValue
//    }
//
//    func on(_ event: Event<Element>, _ c: C) async {
//        await AsynchronousOn(event, c.call())
//    }
//
//    func Asynchronous_on(_ event: Event<Element>, _ c: C) async {
//        switch event {
//        case .next(let value):
//            setLatestValue(value)
//            await parent.next(c.call(), index)
//        case .error(let error):
//            await this.dispose()
//            await parent.fail(c.call(), error)
//        case .completed:
//            await this.dispose()
//            await parent.done(c.call(), index)
//        }
//    }
//}
