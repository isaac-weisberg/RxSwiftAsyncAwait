//
//  Using.swift
//  RxSwift
//
//  Created by Yury Korolev on 10/15/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

public extension ObservableType {
    /**
     Constructs an observable sequence that depends on a resource object, whose lifetime is tied to the resulting observable sequence's lifetime.

     - seealso: [using operator on reactivex.io](http://reactivex.io/documentation/operators/using.html)

     - parameter resourceFactory: Factory function to obtain a resource object.
     - parameter observableFactory: Factory function to obtain an observable sequence that depends on the obtained resource.
     - returns: An observable sequence whose lifetime controls the lifetime of the dependent resource object.
     */
    static func using<Resource: Disposable>(
        _ resourceFactory: @escaping () async throws -> Resource,
        observableFactory: @escaping (Resource) async throws -> Observable<Element>
    ) -> Observable<Element> {
        Using(resourceFactory: resourceFactory, observableFactory: observableFactory)
    }
}

private final actor UsingSink<ResourceType: Disposable, Observer: ObserverType>: Sink, ObserverType {
    typealias SourceType = Observer.Element
    typealias Parent = Using<SourceType, ResourceType>

    private let parent: Parent
    let baseSink: BaseSink<Observer>
    let sourceSubscription = SingleAssignmentDisposable()
    let resourceDisposable = SingleAssignmentDisposable()

    init(parent: Parent, observer: Observer) {
        self.parent = parent
        baseSink = BaseSink(observer: observer)
    }

    func run(_ c: C) async {
        let resource: ResourceType
        do {
            resource = try await parent.resourceFactory()
        } catch {
            await forwardOn(.error(error), c.call())
            await dispose()
            return
        }

        await resourceDisposable.setDisposable(resource)?.dispose()

        let source: Observable<SourceType>
        do {
            source = try await parent.observableFactory(resource)
        } catch {
            await forwardOn(.error(error), c.call())
            await dispose()
            return
        }

        let subscription = await source.subscribe(c.call(), self)

        await sourceSubscription.setDisposable(subscription)?.dispose()
    }

    func on(_ event: Event<SourceType>, _ c: C) async {
        if baseSink.disposed {
            return
        }

        switch event {
        case .next(let value):
            await forwardOn(.next(value), c.call())
        case .error(let error):
            await forwardOn(.error(error), c.call())
            await dispose()
        case .completed:
            await forwardOn(.completed, c.call())
            await dispose()
        }
    }

    func dispose() async {
        baseSink.setDisposed()
        let sourceDisposable = sourceSubscription.dispose()
        let resourceDisposable = resourceDisposable.dispose()

        await sourceDisposable?.dispose()
        await resourceDisposable?.dispose()
    }
}

private final class Using<SourceType: Sendable, ResourceType: Disposable>: Producer<SourceType> {
    typealias Element = SourceType

    typealias ResourceFactory = () async throws -> ResourceType
    typealias ObservableFactory = (ResourceType) async throws -> Observable<SourceType>

    fileprivate let resourceFactory: ResourceFactory
    fileprivate let observableFactory: ObservableFactory

    init(resourceFactory: @escaping ResourceFactory, observableFactory: @escaping ObservableFactory) {
        self.resourceFactory = resourceFactory
        self.observableFactory = observableFactory
        super.init()
    }

    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> AsynchronousDisposable
        where Observer.Element == Element {
        let sink = UsingSink(parent: self, observer: observer)
        await sink.run(c.call())
        return sink
    }
}
