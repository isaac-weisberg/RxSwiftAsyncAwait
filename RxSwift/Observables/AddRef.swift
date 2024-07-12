//
//  AddRef.swift
//  RxSwift
//
//  Created by Junior B. on 30/10/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

final class AddRefSink<Observer: ObserverType>: Sink<Observer>, ObserverType {
    typealias Element = Observer.Element

    func on(_ event: Event<Element>) async {
        switch event {
        case .next:
            await self.forwardOn(event)
        case .completed, .error:
            await self.forwardOn(event)
            await self.dispose()
        }
    }
}

final class AddRef<Element>: Producer<Element> {
    private let source: Observable<Element>
    private let refCount: RefCountDisposable

    init(source: Observable<Element>, refCount: RefCountDisposable) {
        self.source = source
        self.refCount = refCount
    }

    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) async -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        let releaseDisposable = await self.refCount.retain()
        let sink = await AddRefSink(observer: observer, cancel: cancel)
        let subscription = await Disposables.create(releaseDisposable, await self.source.subscribe(sink))

        return (sink: sink, subscription: subscription)
    }
}
