//
//  SynchronizedOnType.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 10/25/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

protocol SynchronizedOnType: AnyObject, ObserverType {
    func synchronized_on(_ event: Event<Element>, _ c: C) async
}

extension SynchronizedOnType {
    func synchronizedOn(_ event: Event<Element>, _ c: C) async {
        await synchronized_on(event, c.call())
    }
}
