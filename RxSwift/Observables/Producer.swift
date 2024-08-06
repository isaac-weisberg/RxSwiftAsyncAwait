////
////  Producer.swift
////  RxSwift
////
////  Created by Krunoslav Zaher on 2/20/15.
////  Copyright © 2015 Krunoslav Zaher. All rights reserved.
////
//
//class Producer<Element>: Observable<Element> {
//    override init() async {
//        await super.init()
//    }
//
//    override func subscribe<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> AsynchronousDisposable
//        where Observer.Element == Element {
//
//        // The returned disposable needs to release all references once it was disposed.
//        let sinkAndSubscription = await run(c.call(), observer)
//
//        return sinkAndSubscription
//    }
//
//    func run<Observer: ObserverType>(
//        _ c: C,
//        _ observer: Observer
//    )
//        async -> AsynchronousDisposable
//        where Observer.Element == Element {
//        rxAbstractMethod()
//    }
//}
