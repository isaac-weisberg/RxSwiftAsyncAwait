//
//  Zip+Collection.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 8/30/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

public extension ObservableType {
    /**
     Merges the specified observable sequences into one observable sequence by using the selector function whenever all of the observable sequences have produced an element at a corresponding index.

     - seealso: [zip operator on reactivex.io](http://reactivex.io/documentation/operators/zip.html)

     - parameter resultSelector: Function to invoke for each series of elements at corresponding indexes in the sources.
     - returns: An observable sequence containing the result of combining elements of the sources using the specified result selector function.
     */
    static func zip<Collection: Swift.Collection>(
        _ collection: Collection,
        resultSelector: @escaping ([Collection.Element.Element]) throws -> Element
    ) -> Observable<Element>
        where Collection.Element: ObservableType {
        ZipCollectionType(sources: collection, resultSelector: resultSelector)
    }

    /**
     Merges the specified observable sequences into one observable sequence whenever all of the observable sequences have produced an element at a corresponding index.

     - seealso: [zip operator on reactivex.io](http://reactivex.io/documentation/operators/zip.html)

     - returns: An observable sequence containing the result of combining elements of the sources.
     */
    static func zip<Collection: Swift.Collection>(_ collection: Collection) -> Observable<[Element]>
        where Collection.Element: ObservableType, Collection.Element.Element == Element {
        ZipCollectionType(sources: collection, resultSelector: { $0 })
    }
}

private final actor ZipCollectionTypeSink<Collection: Swift.Collection, Observer: ObserverType>:
    Sink where Collection.Element: ObservableConvertibleType {
    typealias Result = Observer.Element
    typealias Parent = ZipCollectionType<Collection, Result>
    typealias SourceElement = Collection.Element.Element

    private let parent: Parent

    // state
    private var numberOfValues = 0
    private var values: [Queue<SourceElement>]
    private var isDone: [Bool]
    private var numberOfDone = 0
    private var subscriptions: [SingleAssignmentDisposable]
    let baseSink: BaseSink<Observer>

    init(parent: Parent, observer: Observer) {
        self.parent = parent
        values = [Queue<SourceElement>](repeating: Queue(capacity: 2), count: parent.count)
        isDone = [Bool](repeating: false, count: parent.count)
        subscriptions = [SingleAssignmentDisposable]()
        subscriptions.reserveCapacity(parent.count)

        for _ in 0 ..< parent.count {
            subscriptions.append(SingleAssignmentDisposable())
        }

        baseSink = BaseSink(observer: observer)
    }

    func on(_ c: C, _ event: Event<SourceElement>, atIndex: Int) async {
        switch event {
        case .next(let element):
            values[atIndex].enqueue(element)

            if values[atIndex].count == 1 {
                numberOfValues += 1
            }

            if numberOfValues < parent.count {
                if numberOfDone == parent.count - 1 {
                    await forwardOn(.completed, c.call())
                    await dispose()
                }
                return
            }

            do {
                var arguments = [SourceElement]()
                arguments.reserveCapacity(parent.count)

                // recalculate number of values
                numberOfValues = 0

                for i in 0 ..< values.count {
                    arguments.append(values[i].dequeue()!)
                    if !values[i].isEmpty {
                        numberOfValues += 1
                    }
                }

                let result = try parent.resultSelector(arguments)
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
                await subscriptions[atIndex].dispose()?.dispose()
            }
        }
    }

    func run(_ c: C) async {
        var j = 0
        for i in parent.sources {
            let index = j
            let source = i.asObservable()

            let disposable = await source.subscribe(c.call(), AnyObserver { event, c in
                await self.on(c.call(), event, atIndex: index)
            })
            await subscriptions[j].setDisposable(disposable)?.dispose()
            j += 1
        }

        if parent.sources.isEmpty {
            await forwardOn(.completed, c.call())
        }
    }

    func dispose() async {
        baseSink.setDisposed()
        let disposables = subscriptions.map { sub in
            sub.dispose()
        }

        for disp in disposables {
            await disp?.dispose()
        }
    }
}

private final class ZipCollectionType<Collection: Swift.Collection, Result: Sendable>: Producer<Result>, @unchecked Sendable
    where Collection.Element: ObservableConvertibleType {
    typealias ResultSelector = ([Collection.Element.Element]) throws -> Result

    let sources: Collection
    let resultSelector: ResultSelector
    let count: Int

    init(sources: Collection, resultSelector: @escaping ResultSelector) {
        self.sources = sources
        self.resultSelector = resultSelector
        count = self.sources.count
        super.init()
    }

    override func run<Observer>(_ c: C, _ observer: Observer) async -> any AsynchronousDisposable
        where Result == Observer.Element, Observer: ObserverType {
        let sink = ZipCollectionTypeSink(parent: self, observer: observer)
        await sink.run(c.call())
        return sink
    }
}
