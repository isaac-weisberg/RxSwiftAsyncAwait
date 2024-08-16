//
//  ObserverType.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/8/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

//public enum ObserverOnCompletedHandler {
//    case sync((C) -> Void)
//    case async((C) async -> Void)
//}
//
//public enum ObserverOnErrorHandler {
//    case sync((Swift.Error, C) -> Void)
//    case async((Swift.Error, C) async -> Void)
//}
//
//public enum ObserverOnNextHandler<Element> {
//    case sync((Element, C) -> Void)
//    case async((Element, C) async -> Void)
//}

//public typealias SyncObserverEventHandler<Element> = @Sendable (Event<Element>, C) -> Void
public typealias AsyncObserverEventHandler<Element> = @Sendable (Event<Element>, C) async -> Void

//public enum ObserverEventHandler<Element>: Sendable {
//    case sync(SyncObserverEventHandler<Element>)
//    case async(AsyncObserverEventHandler<Element>)
//}

public protocol ObserverType: Sendable {
    associatedtype Element: Sendable

//    func asAnyObserver() -> AnyAsyncObserver<Element>
    @Sendable
    func on(_ event: Event<Element>, _ c: C) async -> Void
}

public extension ObserverType {
    func onNext(_ element: Element, _ c: C) async {
        await on(.next(element), c)
    }
    
    func onCompleted(_ c: C) async {
        await on(.completed, c)
    }
    
    func onError(_ error: Error, _ c: C) async {
        await on(.error(error), c)
    }
}

//
//public protocol SyncObserverType: Sendable, ObserverType {
//    @Sendable func on(_ event: Event<Element>, _ c: C) -> Void
//}

//public extension SyncObserverType {
//    func asAnyObserver() -> AnySyncObserver<Element> {
//        AnySyncObserver(eventHandler: on(_:_:))
//    }
//}

public typealias AsyncObserverType = ObserverType
public typealias SyncObserverType = ObserverType

//public extension AsyncObserverType {
//    func asAnyObserver() -> AnyAsyncObserver<Element> {
//        AnyAsyncObserver(eventHandler: on(_:_:))
//    }
//}

//
// public protocol ObserverType: Sendable {
//    associatedtype Element: Sendable
//
//    var on: ObserverEventHandler<Element> { get }
// }
//
// public extension ObserverType {
//    var onNext: ObserverOnNextHandler<Element> {
//        switch on {
//        case .sync(let on):
//            return .sync { e, c in
//                on(.next(e), c.call())
//            }
//        case .async(let on):
//            return .async { e, c in
//                await on(.next(e), c.call())
//            }
//        }
//    }
//
//    var onError: ObserverOnErrorHandler {
//        switch on {
//        case .sync(let on):
//            return .sync { e, c in
//                on(.error(e), c.call())
//            }
//        case .async(let on):
//            return .async { e, c in
//                await on(.error(e), c.call())
//            }
//        }
//    }
//
//    var onCompleted: ObserverOnCompletedHandler {
//        switch on {
//        case .sync(let on):
//            return .sync { c in
//                on(.completed, c.call())
//            }
//        case .async(let on):
//            return .async { c in
//                await on(.completed, c.call())
//            }
//        }
//    }
// }
