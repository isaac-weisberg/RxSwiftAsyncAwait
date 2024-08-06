//
//  AddRef.swift
//  RxSwift
//
//  Created by Junior B. on 30/10/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

final actor AddRefSink<Observer: ObserverType>: Sink, ObserverType {
    let baseSink: BaseSink<Observer>

    init(observer: Observer, cancel: any Cancelable) async {
        baseSink = BaseSink(observer: observer)
    }

    typealias Element = Observer.Element

    func on(_ event: Event<Element>, _ c: C) async {
        switch event {
        case .next:
            await forwardOn(event, c.call())
        case .completed, .error:
            await forwardOn(event, c.call())
            await dispose()
        }
    }
}

final class AddRef<Element>: Producer<Element> {
    private let source: Observable<Element>
    private let refCount: RefCountDisposable

    init(source: Observable<Element>, refCount: RefCountDisposable) async {
        self.source = source
        self.refCount = refCount
        await super.init()
    }

    override func run<Observer: ObserverType>(
        _ c: C,
        _ observer: Observer
    )
        async -> AsynchronousDisposable where Observer.Element == Element {
        let releaseDisposable = await refCount.retain()
        let sink = await AddRefSink(observer: observer)
        let subscription = await Disposables.create(releaseDisposable, source.subscribe(c.call(), sink))

        return sink
    }
}
