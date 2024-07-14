//
//  PrimitiveHotObservable.swift
//  Tests
//
//  Created by Krunoslav Zaher on 6/4/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

import RxSwift
import RxTest
import Dispatch

let SubscribedToHotObservable = Subscription(0)
let UnsunscribedFromHotObservable = Subscription(0, 0)

class PrimitiveHotObservable<Element> : ObservableType {
    typealias Events = Recorded<Element>
    typealias Observer = AnyObserver<Element>
    
    var _subscriptions = [Subscription]()
    let observers: PublishSubject<Element>
    
    public var subscriptions: [Subscription] {
        get async {
            await lock.performLocked {
                self._subscriptions
            }
        }
    }

    let lock: RecursiveLock
    
    init() async {
        self.lock = await RecursiveLock()
        observers = await PublishSubject<Element>()
    }

    func on(_ event: Event<Element>) async {
        await lock.performLocked { [self] in
            await self.observers.on(event)
        }
    }
    
    func subscribe<Observer: ObserverType>(_ observer: Observer) async -> Disposable where Observer.Element == Element {
        await lock.performLocked { [self] in
            
            let removeObserver = await self.observers.subscribe(observer)
            self._subscriptions.append(SubscribedToHotObservable)
            
            let i = await self.subscriptions.count - 1
            
            var count = 0
            
            return await Disposables.create { [self] in
                await self.lock.performLocked {
                    
                    await removeObserver.dispose()
                    count += 1
                    assert(count == 1)
                    
                    self._subscriptions[i] = UnsunscribedFromHotObservable
                }
            }
        }
    }
}

