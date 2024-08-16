////
////  PrimitiveSequence+ConcurrencyTests.swift
////  Tests
////
////  Created by Shai Mishali on 22/09/2021.
////  Copyright © 2021 Krunoslav Zaher. All rights reserved.
////
//
//#if swift(>=5.6) && canImport(_Concurrency) && !os(Linux)
//import Dispatch
//import RxSwift
//import XCTest
//import RxTest
//
//@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
//class PrimitiveSequenceConcurrencyTests: RxTest {
//    var scheduler: TestScheduler!
//    
//    override func setUp() async throws {
//        scheduler = await TestScheduler(initialClock: 0)
//        try await super.setUp()
//    }
//}
//
//// MARK: - Single
//@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
//extension PrimitiveSequenceConcurrencyTests {
//    func testSingleEmitsElement() async throws {
//        let single = await Single.just("Hello")
//
//        do {
//            let value = try await single.value()
//            XCTAssertEqual(value, "Hello")
//        } catch {
//            XCTFail("Should not throw an error")
//        }
//    }
//
//    func testSingleThrowsError() async throws {
//        let single = await Single<String>.error(RxError.unknown)
//
//        do {
//            _ = try await single.value()
//            XCTFail("Should not proceed beyond try")
//        } catch {
//            XCTAssertTrue(true)
//        }
//    }
//
//    func testSingleThrowsCancellationWithoutEvents() async throws {
//        let single = await Single<Void>.never()
//
//        Task {
//            do {
//                try await single.value()
//                XCTFail("Should not proceed beyond try")
//            } catch {
//                XCTAssertTrue(Task.isCancelled)
//                XCTAssertTrue(error is CancellationError)
//            }
//        }.cancel()
//    }
//
//    func testSingleNotThrowingCancellation() async throws {
//        let single = await Single.just(())
//
//        let task = Task {
//            do {
//                try await single.value()
//                XCTAssertTrue(true)
//            } catch {
//                XCTFail()
//            }
//        }
//
//        try await Task.sleep(nanoseconds: 1_000_000)
//        task.cancel()
//    }
//
//}
//
//// MARK: - Maybe
//@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
//extension PrimitiveSequenceConcurrencyTests {
//    func testMaybeEmitsElement() async throws {
//        let maybe = await Maybe.just("Hello")
//
//        do {
//            let value = try await maybe.value()
//            XCTAssertNotNil(value)
//            XCTAssertEqual(value, "Hello")
//        } catch {
//            XCTFail("Should not throw an error")
//        }
//    }
//
//    func testMaybeEmitsNilWithoutValue() async throws {
//        let maybe = await Maybe<String>.empty()
//
//        do {
//            let value = try await maybe.value()
//            XCTAssertNil(value)
//        } catch {
//            XCTFail("Should not throw an error")
//        }
//    }
//
//    func testMaybeThrowsError() async throws {
//        let maybe = await Maybe<String>.error(RxError.unknown)
//
//        do {
//            _ = try await maybe.value()
//            XCTFail("Should not proceed beyond try")
//        } catch {
//            XCTAssertTrue(true)
//        }
//    }
//
//    func testMaybeThrowsCancellationWithoutEvents() async throws {
//        let maybe = await Maybe<Void>.never()
//
//        Task {
//            do {
//                try await maybe.value()
//                XCTFail("Should not proceed beyond try")
//            } catch {
//                XCTAssertTrue(Task.isCancelled)
//                XCTAssertTrue(error is CancellationError)
//            }
//        }.cancel()
//    }
//
//    func testMaybeNotThrowingCancellationWhenCompleted() async throws {
//        let maybe = await Maybe<Int>.empty()
//
//        Task {
//            do {
//                let value = try await maybe.value()
//                XCTAssertNil(value)
//            } catch {
//                XCTFail("Should not throw an error")
//            }
//        }.cancel()
//    }
//
//    func testMaybeNotThrowingCancellation() async throws {
//        let maybe = await Maybe.just(())
//
//        let task = Task {
//            do {
//                try await maybe.value()
//                XCTAssertTrue(true)
//            } catch {
//                XCTFail("Should not throw an error")
//            }
//        }
//
//        try await Task.sleep(nanoseconds: 1_000_000)
//        task.cancel()
//    }
//}
//
//// MARK: - Completable
//@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
//extension PrimitiveSequenceConcurrencyTests {
//    func testCompletableEmitsVoidOnCompletion() async throws {
//        let completable = await Completable.empty()
//
//        do {
//            let value: Void = try await completable.value()
//            XCTAssert(value == ())
//        } catch {
//            XCTFail("Should not throw an error")
//        }
//    }
//
//    func testCompletableThrowsError() async throws {
//        let completable = await Completable.error(RxError.unknown)
//
//        do {
//            _ = try await completable.value()
//            XCTFail("Should not proceed beyond try")
//        } catch {
//            XCTAssertTrue(true)
//        }
//    }
//
//    func testCompletableThrowsCancellationWithoutEvents() async throws {
//        let completable = await Completable.never()
//
//        Task {
//            do {
//                try await completable.value()
//                XCTFail()
//            } catch {
//                XCTAssertTrue(Task.isCancelled)
//                XCTAssertTrue(error is CancellationError)
//            }
//        }.cancel()
//    }
//
//    func testCompletableNotThrowingCancellation() async throws {
//        let completable = await Completable.empty()
//
//        Task {
//            do {
//                try await completable.value()
//                XCTAssertTrue(true)
//            } catch {
//                XCTFail("Should not throw an error")
//            }
//        }.cancel()
//    }
//}
//#endif
//
