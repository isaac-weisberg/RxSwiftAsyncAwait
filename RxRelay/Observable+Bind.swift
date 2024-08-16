//
//  Observable+Bind.swift
//  RxRelay
//
//  Created by Shai Mishali on 09/04/2019.
//  Copyright © 2019 Krunoslav Zaher. All rights reserved.
//

import RxSwift

public extension ObservableType {
    /**
     Creates new subscription and sends elements to publish relay(s).
     In case error occurs in debug mode, `fatalError` will be raised.
     In case error occurs in release mode, `error` will be logged.
     - parameter relays: Target publish relays for sequence elements.
     - returns: Disposable object that can be used to unsubscribe the observer.
     */

    #if VICIOUS_TRACING
        func bind(
            _ file: StaticString = #file,
            _ function: StaticString = #function,
            _ line: UInt = #line,
            to relays: PublishRelay<Element>...
        )
            async -> Disposable {
            let c = C(file, function, line)
            return await bind(c.call(), to: relays)
        }
    #else
        func bind(to relays: PublishRelay<Element>...) async -> Disposable {
            await bind(C(), to: relays)
        }
    #endif

    /**
     Creates new subscription and sends elements to publish relay(s).

     In case error occurs in debug mode, `fatalError` will be raised.
     In case error occurs in release mode, `error` will be logged.

     - parameter relays: Target publish relays for sequence elements.
     - returns: Disposable object that can be used to unsubscribe the observer.
     */

    #if VICIOUS_TRACING
        func bind(
            _ file: StaticString = #file,
            _ function: StaticString = #function,
            _ line: UInt = #line,
            to relays: PublishRelay<Element?>...
        )
            async -> Disposable {
            let c = C(file, function, line)
            return await map { $0 as Element? }.bind(c.call(), to: relays)
        }
    #else
        func bind(to relays: PublishRelay<Element?>...) async -> Disposable {
            await map { $0 as Element? }.bind(C(), to: relays)
        }
    #endif

    /**
     Creates new subscription and sends elements to publish relay(s).
     In case error occurs in debug mode, `fatalError` will be raised.
     In case error occurs in release mode, `error` will be logged.
     - parameter relays: Target publish relays for sequence elements.
     - returns: Disposable object that can be used to unsubscribe the observer.
     */
    private func bind(_ c: C, to relays: [PublishRelay<Element>]) async -> Disposable {
        await subscribe(c.call()) { e, c in
            switch e {
            case .next(let element):
                for relay in relays {
                    await relay.accept(element, c.call())
                }
            case .error(let error):
                rxFatalErrorInDebug("Binding error to publish relay: \(error)")
            case .completed:
                break
            }
        }
    }

    /**
     Creates new subscription and sends elements to behavior relay(s).
     In case error occurs in debug mode, `fatalError` will be raised.
     In case error occurs in release mode, `error` will be logged.
     - parameter relays: Target behavior relay for sequence elements.
     - returns: Disposable object that can be used to unsubscribe the observer.
     */
    #if VICIOUS_TRACING
        func bind(
            _ file: StaticString = #file,
            _ function: StaticString = #function,
            _ line: UInt = #line,
            to relays: BehaviorRelay<Element>...
        )
            async -> Disposable {
            let c = C(file, function, line)
            return await bind(c.call(), to: relays)
        }
    #else
        func bind(to relays: BehaviorRelay<Element>...) async -> Disposable {
            await bind(C(), to: relays)
        }
    #endif

    /**
     Creates new subscription and sends elements to behavior relay(s).

     In case error occurs in debug mode, `fatalError` will be raised.
     In case error occurs in release mode, `error` will be logged.

     - parameter relays: Target behavior relay for sequence elements.
     - returns: Disposable object that can be used to unsubscribe the observer.
     */

    #if VICIOUS_TRACING
        func bind(
            _ file: StaticString = #file,
            _ function: StaticString = #function,
            _ line: UInt = #line,
            to relays: BehaviorRelay<Element?>...
        )
            async -> Disposable {
            let c = C(file, function, line)
            return await map { $0 as Element? }.bind(c.call(), to: relays)
        }
    #else
        func bind(to relays: BehaviorRelay<Element?>...) async -> Disposable {
            await map { $0 as Element? }.bind(C(), to: relays)
        }
    #endif

    /**
     Creates new subscription and sends elements to behavior relay(s).
     In case error occurs in debug mode, `fatalError` will be raised.
     In case error occurs in release mode, `error` will be logged.
     - parameter relays: Target behavior relay for sequence elements.
     - returns: Disposable object that can be used to unsubscribe the observer.
     */
    private func bind(_ c: C, to relays: [BehaviorRelay<Element>]) async -> Disposable {
        await subscribe(c.call()) { e, c in
            switch e {
            case .next(let element):
                for relay in relays {
                    await relay.accept(element, c.call())
                }
            case .error(let error):
                rxFatalErrorInDebug("Binding error to behavior relay: \(error)")
            case .completed:
                break
            }
        }
    }

    /**
     Creates new subscription and sends elements to replay relay(s).
     In case error occurs in debug mode, `fatalError` will be raised.
     In case error occurs in release mode, `error` will be logged.
     - parameter relays: Target replay relay for sequence elements.
     - returns: Disposable object that can be used to unsubscribe the observer.
     */
    #if VICIOUS_TRACING
        func bind(
            _ file: StaticString = #file,
            _ function: StaticString = #function,
            _ line: UInt = #line,
            to relays: ReplayRelay<Element>...
        )
            async -> Disposable {
            let c = C(file, function, line)
            return await bind(c.call(), to: relays)
        }
    #else
        func bind(to relays: ReplayRelay<Element>...) async -> Disposable {
            await bind(C(), to: relays)
        }
    #endif

    /**
     Creates new subscription and sends elements to replay relay(s).
     
     In case error occurs in debug mode, `fatalError` will be raised.
     In case error occurs in release mode, `error` will be logged.
     
     - parameter relays: Target replay relay for sequence elements.
     - returns: Disposable object that can be used to unsubscribe the observer.
     */
    #if VICIOUS_TRACING
        func bind(
            _ file: StaticString = #file,
            _ function: StaticString = #function,
            _ line: UInt = #line,
            to relays: ReplayRelay<Element?>...
        )
            async -> Disposable {
            let c = C(file, function, line)
            return await map { $0 as Element? }.bind(c, to: relays)
        }
    #else
        func bind(to relays: ReplayRelay<Element?>...) async -> Disposable {
            await map { $0 as Element? }.bind(C(), to: relays)
        }
    #endif

    /**
     Creates new subscription and sends elements to replay relay(s).
     In case error occurs in debug mode, `fatalError` will be raised.
     In case error occurs in release mode, `error` will be logged.
     - parameter relays: Target replay relay for sequence elements.
     - returns: Disposable object that can be used to unsubscribe the observer.
     */
    private func bind(_ c: C, to relays: [ReplayRelay<Element>]) async -> Disposable {
        await subscribe(c.call()) { event, c in
            switch event {
            case .next(let element):
                for relay in relays {
                    await relay.accept(element, c.call())
                }
            case .error(let error):
                rxFatalErrorInDebug("Binding error to behavior relay: \(error)")
            case .completed:
                break
            }
        }
    }
}
