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
    static func combineLatest<Collection: Swift.Collection & Sendable>(
        _ collection: Collection,
        resultSelector: @Sendable @escaping ([Collection.Element.Element]) throws -> Element
    )
        async -> Observable<Element>
        where Collection.Element: ObservableType {
        await CombineLatestCollectionType(sources: collection, resultSelector: resultSelector)
    }

    /**
     Merges the specified observable sequences into one observable sequence whenever any of the observable sequences produces an element.

     - seealso: [combinelatest operator on reactivex.io](http://reactivex.io/documentation/operators/combinelatest.html)

     - returns: An observable sequence containing the result of combining elements of the sources.
     */
    static func combineLatest<Collection: Swift.Collection & Sendable>(_ collection: Collection) async
        -> Observable<[Element]>
        where Collection.Element: ObservableType, Collection.Element.Element == Element {
        await CombineLatestCollectionType(sources: collection, resultSelector: { $0 })
    }
}

final actor CombineLatestCollectionTypeSink<Collection: Swift.Collection, Observer: ObserverType>:
    AsynchronousDisposable where Collection.Element: ObservableType {
    typealias Result = Observer.Element
    typealias SourceElement = Collection.Element.Element
    typealias ResultSelector = ([SourceElement]) throws -> Observer.Element

    let observer: Observer
    let resultSelector: ResultSelector
    let parentSources: Collection
    let parentCount: Int

    // state
    var numberOfValues = 0
    var values: [SourceElement?]
    var isDone: [Bool]
    var numberOfDone = 0
    var subscriptions: [SingleAssignmentDisposable]
    var disposed = false

    init(parentSources: Collection, resultSelector: @escaping ResultSelector, observer: Observer) {
        self.parentSources = parentSources
        parentCount = parentSources.count
        self.resultSelector = resultSelector
        values = [SourceElement?](repeating: nil, count: parentCount)
        isDone = [Bool](repeating: false, count: parentCount)
        subscriptions = Array(repeating: SingleAssignmentDisposable(), count: parentCount)

        self.observer = observer
    }

    func forwardOn(_ event: Event<Observer.Element>, _ c: C) async {
        if !disposed {
            await self.observer.on(event, c.call())
        }
    }

    func dispose() async {
        if !disposed {
            disposed = true
            var index = 0
            while index < subscriptions.count {
                let subscription = subscriptions[index]
                await subscription.dispose()?.dispose()
                index += 1
            }
        }
    }

    func on(_ c: C, _ event: Event<SourceElement>, atIndex: Int) async {
        if disposed {
            return
        }

        switch event {
        case .next(let element):
            if values[atIndex] == nil {
                numberOfValues += 1
            }

            values[atIndex] = element

            if numberOfValues < parentCount {
                let numberOfOthersThatAreDone = numberOfDone - (isDone[atIndex] ? 1 : 0)
                if numberOfOthersThatAreDone == parentCount - 1 {
                    await forwardOn(.completed, c.call())
                    await dispose()
                }
                return
            }

            do {
                let result = try resultSelector(values.map { $0! })
                await forwardOn(.next(result), c.call())
            } catch {
                await forwardOn(.error(error), c.call())
                await dispose()
            }

        case .error(let error):
            await forwardOn(.error(error), c.call())
            await dispose()

        case .completed:
            if isDone[atIndex] {
                return
            }

            isDone[atIndex] = true
            numberOfDone += 1

            if numberOfDone == parentCount {
                await forwardOn(.completed, c.call())
                await dispose()
            } else {
                await subscriptions[atIndex].dispose()?.dispose()
            }
        }
    }

    func run(_ c: C) async {
        var j = 0
        for i in parentSources {
            let index = j
            let source = i
            let disposable = await source.subscribe(c.call(), AnyAsyncObserver(eventHandler: { event, c in
                await self.on(c.call(), event, atIndex: index)
            }))

            await subscriptions[j].setDisposable(disposable)?.dispose()

            j += 1
        }

        if parentCount == 0 {
            do {
                let result = try resultSelector([])
                await forwardOn(.next(result), c.call())
                await forwardOn(.completed, c.call())
                await dispose()
            } catch {
                await forwardOn(.error(error), c.call())
                await dispose()
            }
        }
    }
}

final class CombineLatestCollectionType<Collection: Swift.Collection & Sendable, Result: Sendable>: Observable<Result>
    where Collection.Element: ObservableType {
    typealias ResultSelector = @Sendable ([Collection.Element.Element]) throws -> Result

    let sources: Collection
    let resultSelector: ResultSelector
    let count: Int

    init(sources: Collection, resultSelector: @escaping ResultSelector) async {
        self.sources = sources
        self.resultSelector = resultSelector
        count = self.sources.count
        super.init()
    }

    override func subscribe<Observer>(_ c: C, _ observer: Observer) async -> any AsynchronousDisposable
        where Result == Observer.Element, Observer: ObserverType {
        let sink = CombineLatestCollectionTypeSink(
            parentSources: sources,
            resultSelector: resultSelector,
            observer: observer
        )
        await sink.run(c.call())
        return sink
    }
}
