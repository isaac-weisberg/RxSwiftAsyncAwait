//
//  CombineLatest.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 3/21/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

protocol CombineLatestProtocol: AnyObject {
    func next(_ c: C, _ index: Int) async
    func fail(_ c: C, _ error: Swift.Error) async
    func done(_ c: C, _ index: Int) async
}

actor CombineLatestSink<Observer: ObserverType>:
    Sink,
    CombineLatestProtocol {
    typealias Element = Observer.Element

    private let arity: Int
    private var numberOfValues = 0
    private var numberOfDone = 0
    private var hasValue: [Bool]
    private var isDone: [Bool]
    private var

    let baseSink: BaseSink<Observer>

    init(arity: Int, observer: Observer) async {
        self.arity = arity
        hasValue = [Bool](repeating: false, count: arity)
        isDone = [Bool](repeating: false, count: arity)

        baseSink = BaseSink(observer: observer)
    }

    func getResult() async throws -> Element {
        rxAbstractMethod()
    }

    func next(_ c: C, _ index: Int) async {
        if !hasValue[index] {
            hasValue[index] = true
            numberOfValues += 1
        }

        if numberOfValues == arity {
            do {
                let result = try await getResult()
                await forwardOn(.next(result), c.call())
            } catch let e {
                await self.forwardOn(.error(e), c.call())
                await self.dispose()
            }
        } else {
            var allOthersDone = true

            for i in 0 ..< arity {
                if i != index, !isDone[i] {
                    allOthersDone = false
                    break
                }
            }

            if allOthersDone {
                await forwardOn(.completed, c.call())
                await dispose()
            }
        }
    }

    func fail(_ c: C, _ error: Swift.Error) async {
        await forwardOn(.error(error), c.call())
        await dispose()
    }

    func done(_ c: C, _ index: Int) async {
        if isDone[index] {
            return
        }

        isDone[index] = true
        numberOfDone += 1

        if numberOfDone == arity {
            await forwardOn(.completed, c.call())
            await dispose()
        }
    }
    
    var isDisposed = false
    func dispose() async {
        if !isDisposed {
            isDisposed = true
            
            
        }
    }

    func forwardOn(_ event: Event<Observer.Element>, _ c: C) async {
        if !disposed {
            await self.baseSink.observer.on(event, c.call())
        }
    }
}

final class CombineLatestObserver<Element>:
    ObserverType,
    SynchronizedOnType {
    typealias ValueSetter = (Element) -> Void

    private let parent: CombineLatestProtocol

    private let index: Int
    private let this: SynchronizedDisposable
    private let setLatestValue: ValueSetter

    init(
        parent: CombineLatestProtocol,
        index: Int,
        setLatestValue: @escaping ValueSetter,
        this: SynchronizedDisposable
    ) {
        self.parent = parent
        self.index = index
        self.this = this
        self.setLatestValue = setLatestValue
    }

    func on(_ event: Event<Element>, _ c: C) async {
        await synchronizedOn(event, c.call())
    }

    func synchronized_on(_ event: Event<Element>, _ c: C) async {
        switch event {
        case .next(let value):
            setLatestValue(value)
            await parent.next(c.call(), index)
        case .error(let error):
            await this.dispose()
            await parent.fail(c.call(), error)
        case .completed:
            await this.dispose()
            await parent.done(c.call(), index)
        }
    }
}

/**
 
 // 2

 public extension ObservableType {
     /**
      Merges the specified observable sequences into one observable sequence by using the selector function whenever any of the observable sequences produces an element.

      - seealso: [combineLatest operator on reactivex.io](http://reactivex.io/documentation/operators/combinelatest.html)

      - parameter resultSelector: Function to invoke whenever any of the sources produces an element.
      - returns: An observable sequence containing the result of combining elements of the sources using the specified result selector function.
      */
     static func combineLatest<O1: ObservableType, O2: ObservableType>
     (_ source1: O1, _ source2: O2, resultSelector: @escaping (O1.Element, O2.Element) throws -> Element) async
         -> Observable<Element> {
         await CombineLatest2(
             source1: source1, source2: source2,
             resultSelector: resultSelector
         )
     }
 }

 public extension ObservableType where Element == Any {
     /**
      Merges the specified observable sequences into one observable sequence of tuples whenever any of the observable sequences produces an element.

      - seealso: [combineLatest operator on reactivex.io](http://reactivex.io/documentation/operators/combinelatest.html)

      - returns: An observable sequence containing the result of combining elements of the sources.
      */
     static func combineLatest<O1: ObservableType, O2: ObservableType>
     (_ source1: O1, _ source2: O2) async
         -> Observable<(O1.Element, O2.Element)> {
         await CombineLatest2(
             source1: source1, source2: source2,
             resultSelector: { ($0, $1) }
         )
     }
 }

 final class CombineLatest2<O1: ObservableType, O2: ObservableType, Result>: Producer<Result> {
     typealias E1 = O1.Element
     typealias E2 = O2.Element
     typealias ResultSelector = (E1, E2) throws -> Result

     enum ParameterElement {
         case e1(E1)
         case e2(E2)
     }

     let source1: O1
     let source2: O2

     let resultSelector: ResultSelector

     init(source1: O1, source2: O2, resultSelector: @escaping ResultSelector) async {
         self.source1 = source1
         self.source2 = source2

         self.resultSelector = resultSelector
         await super.init()
     }

     override func run<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> SynchronizedDisposable
         where Observer.Element == Result {
         let sink = await CombineLatestCollectionTypeSink(
             parentSources: [
                 source1.map { e1 in
                     ParameterElement.e1(e1)
                 },
                 source2.map { e2 in
                     ParameterElement.e2(e2)
                 },
             ], resultSelector: { [resultSelector] coll in
                 if
                     case .e1(let e1) = coll[0],
                     case .e2(let e2) = coll[1] {
                     let result = try resultSelector(
                         e1,
                         e2
                     )

                     return result
                 }

                 rxFatalError("fuck")
             },
             observer: observer
         )
         await sink.run(c.call())
         return sink
     }
 }

 
 */
