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
    static func using<Resource: Disposable>(_ resourceFactory: @escaping () async throws -> Resource, observableFactory: @escaping (Resource) async throws -> Observable<Element>) async -> Observable<Element> {
        await Using(resourceFactory: resourceFactory, observableFactory: observableFactory)
    }
}

private final class UsingSink<ResourceType: Disposable, Observer: ObserverType>: Sink<Observer>, ObserverType {
    typealias SourceType = Observer.Element
    typealias Parent = Using<SourceType, ResourceType>

    private let parent: Parent
    
    init(parent: Parent, observer: Observer, cancel: Cancelable) async {
        self.parent = parent
        await super.init(observer: observer, cancel: cancel)
    }
    
    func run(_ c: C) async -> Disposable {
        var disposable = Disposables.create()
        
        do {
            let resource = try await self.parent.resourceFactory()
            disposable = resource
            let source = try await self.parent.observableFactory(resource)
            
            return await Disposables.create(
                source.subscribe(c.call(), self),
                disposable
            )
        } catch {
            return await Disposables.create(
                Observable.error(error).subscribe(c.call(), self),
                disposable
            )
        }
    }
    
    func on(_ event: Event<SourceType>, _ c: C) async {
        switch event {
        case let .next(value):
            await self.forwardOn(.next(value), c.call())
        case let .error(error):
            await self.forwardOn(.error(error), c.call())
            await self.dispose()
        case .completed:
            await self.forwardOn(.completed, c.call())
            await self.dispose()
        }
    }
}

private final class Using<SourceType, ResourceType: Disposable>: Producer<SourceType> {
    typealias Element = SourceType
    
    typealias ResourceFactory = () async throws -> ResourceType
    typealias ObservableFactory = (ResourceType) async throws -> Observable<SourceType>
    
    fileprivate let resourceFactory: ResourceFactory
    fileprivate let observableFactory: ObservableFactory
    
    init(resourceFactory: @escaping ResourceFactory, observableFactory: @escaping ObservableFactory) async {
        self.resourceFactory = resourceFactory
        self.observableFactory = observableFactory
        await super.init()
    }
    
    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer, cancel: Cancelable) async -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        let sink = await UsingSink(parent: self, observer: observer, cancel: cancel)
        let subscription = await sink.run(C())
        return (sink: sink, subscription: subscription)
    }
}
