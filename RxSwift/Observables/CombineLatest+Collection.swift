//
//  CombineLatest+Collection.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 8/29/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

public extension ObservableType {
    /**
     Merges the specified observable sequences into one observable sequence by using the selector function whenever any of the observable sequences produces an element.

     - seealso: [combinelatest operator on reactivex.io](http://reactivex.io/documentation/operators/combinelatest.html)

     - parameter resultSelector: Function to invoke whenever any of the sources produces an element.
     - returns: An observable sequence containing the result of combining elements of the sources using the specified result selector function.
     */
    static func combineLatest<Collection: Swift.Collection>(_ collection: Collection, resultSelector: @escaping ([Collection.Element.Element]) throws -> Element) async -> Observable<Element>
        where Collection.Element: ObservableType
    {
        await CombineLatestCollectionType(sources: collection, resultSelector: resultSelector)
    }

    /**
     Merges the specified observable sequences into one observable sequence whenever any of the observable sequences produces an element.

     - seealso: [combinelatest operator on reactivex.io](http://reactivex.io/documentation/operators/combinelatest.html)

     - returns: An observable sequence containing the result of combining elements of the sources.
     */
    static func combineLatest<Collection: Swift.Collection>(_ collection: Collection) async -> Observable<[Element]>
        where Collection.Element: ObservableType, Collection.Element.Element == Element
    {
        await CombineLatestCollectionType(sources: collection, resultSelector: { $0 })
    }
}

final class CombineLatestCollectionTypeSink<Collection: Swift.Collection, Observer: ObserverType>:
    Sink<Observer> where Collection.Element: ObservableConvertibleType
{
    typealias Result = Observer.Element
    typealias Parent = CombineLatestCollectionType<Collection, Result>
    typealias SourceElement = Collection.Element.Element
    
    let parent: Parent
    
    let lock: RecursiveLock

    // state
    var numberOfValues = 0
    var values: [SourceElement?]
    var isDone: [Bool]
    var numberOfDone = 0
    var subscriptions: [SingleAssignmentDisposable]
    
    init(parent: Parent, observer: Observer, cancel: Cancelable) async {
        self.lock = await RecursiveLock()
        self.parent = parent
        self.values = [SourceElement?](repeating: nil, count: parent.count)
        self.isDone = [Bool](repeating: false, count: parent.count)
        self.subscriptions = [SingleAssignmentDisposable]()
        self.subscriptions.reserveCapacity(parent.count)
        
        for _ in 0 ..< parent.count {
            await self.subscriptions.append(SingleAssignmentDisposable())
        }
        
        await super.init(observer: observer, cancel: cancel)
    }
    
    func on(_ c: C, _ event: Event<SourceElement>, atIndex: Int) async {
        await self.lock.performLocked(c.call()) { c in
            switch event {
            case .next(let element):
                if self.values[atIndex] == nil {
                    self.numberOfValues += 1
                }
                
                self.values[atIndex] = element
                
                if self.numberOfValues < self.parent.count {
                    let numberOfOthersThatAreDone = self.numberOfDone - (self.isDone[atIndex] ? 1 : 0)
                    if numberOfOthersThatAreDone == self.parent.count - 1 {
                        await self.forwardOn(.completed, c.call())
                        await self.dispose()
                    }
                    return
                }
                
                do {
                    let result = try self.parent.resultSelector(self.values.map { $0! })
                    await self.forwardOn(.next(result), c.call())
                }
                catch {
                    await self.forwardOn(.error(error), c.call())
                    await self.dispose()
                }
                
            case .error(let error):
                await self.forwardOn(.error(error), c.call())
                await self.dispose()

            case .completed:
                if self.isDone[atIndex] {
                    return
                }
                
                self.isDone[atIndex] = true
                self.numberOfDone += 1
                
                if self.numberOfDone == self.parent.count {
                    await self.forwardOn(.completed, c.call())
                    await self.dispose()
                }
                else {
                    await self.subscriptions[atIndex].dispose()
                }
            }
        }
    }
    
    func run(_ c: C) async -> Disposable {
        var j = 0
        for i in self.parent.sources {
            let index = j
            let source = await i.asObservable()
            let disposable = await source.subscribe(c.call(), AnyObserver { c, event in
                await self.on(c.call(), event, atIndex: index)
            })

            await self.subscriptions[j].setDisposable(disposable)
            
            j += 1
        }

        if self.parent.sources.isEmpty {
            do {
                let result = try self.parent.resultSelector([])
                await self.forwardOn(.next(result), c.call())
                await self.forwardOn(.completed, c.call())
                await self.dispose()
            }
            catch {
                await self.forwardOn(.error(error), c.call())
                await self.dispose()
            }
        }
        
        return await Disposables.create(self.subscriptions)
    }
}

final class CombineLatestCollectionType<Collection: Swift.Collection, Result>: Producer<Result> where Collection.Element: ObservableConvertibleType {
    typealias ResultSelector = ([Collection.Element.Element]) throws -> Result
    
    let sources: Collection
    let resultSelector: ResultSelector
    let count: Int

    init(sources: Collection, resultSelector: @escaping ResultSelector) async {
        self.sources = sources
        self.resultSelector = resultSelector
        self.count = self.sources.count
        await super.init()
    }
    
    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer, cancel: Cancelable) async -> (sink: Disposable, subscription: Disposable) where Observer.Element == Result {
        let sink = await CombineLatestCollectionTypeSink(parent: self, observer: observer, cancel: cancel)
        let subscription = await sink.run(c.call())
        return (sink: sink, subscription: subscription)
    }
}
