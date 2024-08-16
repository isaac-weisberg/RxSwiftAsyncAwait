//
//  ColdObservable.swift
//  RxTest
//
//  Created by Krunoslav Zaher on 3/14/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

import RxSwift

/// A representation of cold observable sequence.
///
/// Recorded events are replayed after subscription once per subscriber.
///
/// Event times represent relative offset to subscription time.
final class ColdObservable<Element>
    : TestableObservable<Element> {

    override init(testScheduler: TestScheduler, recordedEvents: [Recorded<Event<Element>>]) async {
        await super.init(testScheduler: testScheduler, recordedEvents: recordedEvents)
    }

    /// Subscribes `observer` to receive events for this sequence.
    override func subscribe<Observer: ObserverType>(_ observer: Observer) async -> Disposable where Observer.Element == Element {
        self.subscriptions.append(Subscription(self.testScheduler.clock))
        
        let i = self.subscriptions.count - 1

        var disposed = false

        for recordedEvent in self.recordedEvents {
            _ = await self.testScheduler.scheduleRelativeVirtual((), dueTime: recordedEvent.time, action: { _ in
                if !disposed {
                    await observer.on(recordedEvent.value)
                }
                return Disposables.create()
            })
        }
        
        return await Disposables.create {
            disposed = true
            let existing = self.subscriptions[i]
            self.subscriptions[i] = Subscription(existing.subscribe, self.testScheduler.clock)
        }
    }
}
