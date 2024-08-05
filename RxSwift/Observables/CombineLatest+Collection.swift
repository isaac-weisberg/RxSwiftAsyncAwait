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
    static func combineLatest<Collection: Swift.Collection>(
        _ collection: Collection,
        resultSelector: @escaping ([Collection.Element.Element]) throws -> Element
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
    static func combineLatest<Collection: Swift.Collection>(_ collection: Collection) async -> Observable<[Element]>
        where Collection.Element: ObservableType, Collection.Element.Element == Element {
        await CombineLatestCollectionType(sources: collection, resultSelector: { $0 })
    }
}

final actor CombineLatestCollectionTypeSink<Collection: Swift.Collection, Observer: ObserverType>:
    Sink where Collection.Element: ObservableConvertibleType {
    typealias Result = Observer.Element
    typealias Parent = CombineLatestCollectionType<Collection, Result>
    typealias SourceElement = Collection.Element.Element

    let parent: Parent

    let baseSink: BaseSink<Observer>

    // state
    var numberOfValues = 0
    var values: [SourceElement?]
    var isDone: [Bool]
    var numberOfDone = 0
    var subscriptions: [SingleAssignmentDisposable]

    init(parent: Parent, observer: Observer, cancel: SynchronizedCancelable) async {
        self.parent = parent
        values = [SourceElement?](repeating: nil, count: parent.count)
        isDone = [Bool](repeating: false, count: parent.count)
        subscriptions = [SingleAssignmentDisposable]()
        subscriptions.reserveCapacity(parent.count)

        for _ in 0 ..< parent.count {
            await subscriptions.append(SingleAssignmentDisposable())
        }

        baseSink = await BaseSink(observer: observer, cancel: cancel)
    }

    func forwardOn(_ event: Event<Observer.Element>, _ c: C) async {
        baseSink.beforeForwardOn()
        if !baseSink.isDisposed() {
            await baseSink.forwardOn(event, c.call())
        }
        baseSink.afterForwardOn()
    }

    func dispose() async {
        baseSink.setDisposedSync()
        await baseSink.dispose()
    }

    func on(_ c: C, _ event: Event<SourceElement>, atIndex: Int) async {
        switch event {
        case .next(let element):
            if values[atIndex] == nil {
                numberOfValues += 1
            }

            values[atIndex] = element

            if numberOfValues < parent.count {
                let numberOfOthersThatAreDone = numberOfDone - (isDone[atIndex] ? 1 : 0)
                if numberOfOthersThatAreDone == parent.count - 1 {
                    await forwardOn(.completed, c.call())
                    await dispose()
                }
                return
            }

            do {
                let result = try parent.resultSelector(values.map { $0! })
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

            if numberOfDone == parent.count {
                await forwardOn(.completed, c.call())
                await dispose()
            } else {
                await subscriptions[atIndex].dispose()
            }
        }
    }

    func run(_ c: C) async -> SynchronizedCancelable {
        var j = 0
        for i in parent.sources {
            let index = j
            let source = await i.asObservable()
            let disposable = await source.subscribe(c.call(), AnyObserver { c, event in
                await self.on(c.call(), event, atIndex: index)
            })

            await subscriptions[j].setDisposable(disposable)

            j += 1
        }

        if parent.sources.isEmpty {
            do {
                let result = try parent.resultSelector([])
                await forwardOn(.next(result), c.call())
                await forwardOn(.completed, c.call())
                await dispose()
            } catch {
                await forwardOn(.error(error), c.call())
                await dispose()
            }
        }

        return await Disposables.create(subscriptions)
    }
}

final class CombineLatestCollectionType<Collection: Swift.Collection, Result>: Producer<Result>
    where Collection.Element: ObservableConvertibleType {
    typealias ResultSelector = ([Collection.Element.Element]) throws -> Result

    let sources: Collection
    let resultSelector: ResultSelector
    let count: Int

    init(sources: Collection, resultSelector: @escaping ResultSelector) async {
        self.sources = sources
        self.resultSelector = resultSelector
        count = self.sources.count
        await super.init()
    }

    override func run<Observer: ObserverType>(
        _ c: C,
        _ observer: Observer,
        cancel: SynchronizedCancelable
    )
        async -> (sink: SynchronizedDisposable, subscription: SynchronizedDisposable) where Observer.Element == Result {
        let sink = await CombineLatestCollectionTypeSink(parent: self, observer: observer, cancel: cancel)
        let subscription = await sink.run(c.call())
        return (sink: sink, subscription: subscription)
    }
}
