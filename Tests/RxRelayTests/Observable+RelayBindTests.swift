//
//  Observable+RelayBindTests.swift
//  Tests
//
//  Created by Shai Mishali on 09/04/2019.
//  Copyright © 2019 Krunoslav Zaher. All rights reserved.
//

import RxSwift
import RxRelay
import RxTest
import XCTest

class ObservableRelayBindTest: RxTest {
    
}

// MARK: bind(to:) publish relay
extension ObservableRelayBindTest {
    func testBindToPublishRelay() async {
        var events: [Recorded<Event<Int>>] = []

        let relay = await PublishRelay<Int>()

        _ = await relay.subscribe { event in
            events.append(Recorded(time: 0, value: event))
        }

        _ = await Observable.just(1).bind(to: relay)

        XCTAssertEqual(events, [
            .next(1)
            ])
    }

    func testBindToPublishRelays() async {
        var events1: [Recorded<Event<Int>>] = []
        var events2: [Recorded<Event<Int>>] = []

        let relay1 = await PublishRelay<Int>()
        let relay2 = await PublishRelay<Int>()

        _ = await relay1.subscribe { event in
            events1.append(Recorded(time: 0, value: event))
        }

        _ = await relay2.subscribe { event in
            events2.append(Recorded(time: 0, value: event))
        }

        _ = await Observable.just(1).bind(to: relay1, relay2)

        XCTAssertEqual(events1, [
            .next(1)
            ])

        XCTAssertEqual(events2, [
            .next(1)
            ])
    }

    func testBindToOptionalPublishRelay() async {
        var events: [Recorded<Event<Int?>>] = []

        let relay = await PublishRelay<Int?>()

        _ = await relay.subscribe { event in
            events.append(Recorded(time: 0, value: event))
        }

        _ = await (Observable.just(1) as Observable<Int>).bind(to: relay)

        XCTAssertEqual(events, [
            .next(1)
            ])
    }

    func testBindToOptionalPublishRelays() async {
        var events1: [Recorded<Event<Int?>>] = []
        var events2: [Recorded<Event<Int?>>] = []

        let relay1 = await PublishRelay<Int?>()
        let relay2 = await PublishRelay<Int?>()

        _ = await relay1.subscribe { event in
            events1.append(Recorded(time: 0, value: event))
        }

        _ = await relay2.subscribe { event in
            events2.append(Recorded(time: 0, value: event))
        }

        _ = await (Observable.just(1) as Observable<Int>).bind(to: relay1, relay2)

        XCTAssertEqual(events1, [
            .next(1)
            ])

        XCTAssertEqual(events2, [
            .next(1)
            ])
    }

    func testBindToPublishRelayNoAmbiguity() async {
        var events: [Recorded<Event<Int?>>] = []

        let relay = await PublishRelay<Int?>()

        _ = await relay.subscribe { event in
            events.append(Recorded(time: 0, value: event))
        }

        _ = await Observable.just(1).bind(to: relay)

        XCTAssertEqual(events, [
            .next(1)
            ])
    }
}

// MARK: bind(to:) behavior relay
extension ObservableRelayBindTest {
    func testBindToBehaviorRelay() async {
        let relay = await BehaviorRelay<Int>(value: 0)

        _ = await Observable.just(1).bind(to: relay)

        XCTAssertEqual(relay.value(), 1)
    }

    func testBindToBehaviorRelays() async {
        let relay1 = await BehaviorRelay<Int>(value: 0)
        let relay2 = await BehaviorRelay<Int>(value: 0)

        _ = await Observable.just(1).bind(to: relay1, relay2)

        let value1 = await relay1.value()
        XCTAssertEqual(value1, 1)
        let value2 = await relay2.value()
        XCTAssertEqual(value2, 1)
    }

    func testBindToOptionalBehaviorRelay() async {
        let relay = await BehaviorRelay<Int?>(value: 0)

        _ = await (Observable.just(1) as Observable<Int>).bind(to: relay)

        let value = await relay.value()
        XCTAssertEqual(value, 1)
    }

    func testBindToOptionalBehaviorRelays() async {
        let relay1 = await BehaviorRelay<Int?>(value: 0)
        let relay2 = await BehaviorRelay<Int?>(value: 0)

        _ = await (Observable.just(1) as Observable<Int>).bind(to: relay1, relay2)

        let value1 = await relay1.value()
        XCTAssertEqual(value1, 1)
        let value2 = await relay2.value()
        XCTAssertEqual(value2, 1)
    }

    func testBindToBehaviorRelayNoAmbiguity() async {
        let relay = await BehaviorRelay<Int?>(value: 0)

        _ = await Observable.just(1).bind(to: relay)

        let value = await relay.value()
        XCTAssertEqual(value, 1)
    }
}

// MARK: bind(to:) replay relay
extension ObservableRelayBindTest {
    func testBindToReplayRelay() async {
        var events: [Recorded<Event<Int>>] = []

        let relay = await ReplayRelay<Int>.create(bufferSize: 1)

        _ = await relay.subscribe { event in
            events.append(Recorded(time: 0, value: event))
        }

        _ = await Observable.just(1).bind(to: relay)

        XCTAssertEqual(events, [
            .next(1),
        ])
    }

    func testBindToReplayRelays() async {
        var events1: [Recorded<Event<Int>>] = []
        var events2: [Recorded<Event<Int>>] = []

        let relay1 = await ReplayRelay<Int>.create(bufferSize: 1)
        let relay2 = await ReplayRelay<Int>.create(bufferSize: 1)

        _ = await relay1.subscribe { event in
            events1.append(Recorded(time: 0, value: event))
        }

        _ = await relay2.subscribe { event in
            events2.append(Recorded(time: 0, value: event))
        }

        _ = await Observable.just(1).bind(to: relay1, relay2)

        XCTAssertEqual(events1, [
            .next(1),
        ])

        XCTAssertEqual(events2, [
            .next(1),
        ])
    }

    func testBindToOptionalReplayRelay() async {
        var events: [Recorded<Event<Int?>>] = []

        let relay = await ReplayRelay<Int?>.create(bufferSize: 1)

        _ = await relay.subscribe { event in
            events.append(Recorded(time: 0, value: event))
        }

        _ = await (Observable.just(1) as Observable<Int>).bind(to: relay)

        XCTAssertEqual(events, [
            .next(1),
        ])
    }

    func testBindToOptionalReplayRelays() async {
        var events1: [Recorded<Event<Int?>>] = []
        var events2: [Recorded<Event<Int?>>] = []

        let relay1 = await ReplayRelay<Int?>.create(bufferSize: 1)
        let relay2 = await ReplayRelay<Int?>.create(bufferSize: 1)

        _ = await relay1.subscribe { event in
            events1.append(Recorded(time: 0, value: event))
        }

        _ = await relay2.subscribe { event in
            events2.append(Recorded(time: 0, value: event))
        }

        _ = await (Observable.just(1) as Observable<Int>).bind(to: relay1, relay2)

        XCTAssertEqual(events1, [
            .next(1),
        ])

        XCTAssertEqual(events2, [
            .next(1),
        ])
    }

    func testBindToReplayRelayNoAmbiguity() async {
        var events: [Recorded<Event<Int?>>] = []

        let relay = await ReplayRelay<Int?>.create(bufferSize: 1)

        _ = await relay.subscribe { event in
            events.append(Recorded(time: 0, value: event))
        }

        _ = await Observable.just(1).bind(to: relay)

        XCTAssertEqual(events, [
            .next(1),
        ])
    }
}
