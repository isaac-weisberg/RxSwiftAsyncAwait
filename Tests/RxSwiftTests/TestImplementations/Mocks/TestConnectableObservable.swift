//
//  TestConnectableObservable.swift
//  Tests
//
//  Created by Krunoslav Zaher on 4/19/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

import RxSwift

final class TestConnectableObservable<Subject: SubjectType> : ConnectableObservableType where Subject.Element == Subject.Observer.Element {
    typealias Element = Subject.Element

    let o: ConnectableObservable<Subject.Element>
    
    init(o: Observable<Subject.Element>, s: Subject) async {
        self.o = await o.multicast(s)
    }
    
    func connect() async -> Disposable {
        await self.o.connect()
    }
    
    func subscribe<Observer: ObserverType>(_ observer: Observer) async -> Disposable where Observer.Element == Element {
        await self.o.subscribe(observer)
    }
}
