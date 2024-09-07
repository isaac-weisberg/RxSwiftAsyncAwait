//
//  SynchronizedOnType.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 10/25/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

protocol SynchronizedOnType: AnyObject, ObserverType, PerformLock {
    func synchronized_on(_ event: Event<Element>)
}

extension SynchronizedOnType {
    func synchronizedOn(_ event: Event<Element>) {
        self.performLockedRecursive {
            self.synchronized_on(event)
        }
    }
}
