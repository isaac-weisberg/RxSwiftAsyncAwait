//
//  AnonymousObserver.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/8/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

//final class AnonymousObserver<Element>: ObserverBase<Element> {
//    typealias EventHandler = (_ c: C, Event<Element>) async -> Void
//
//    private let eventHandler: EventHandler
//
//    init(_ eventHandler: @escaping EventHandler) async {
//        #if TRACE_RESOURCES
//            _ = await Resources.incrementTotal()
//        #endif
//        self.eventHandler = eventHandler
//        await super.init()
//    }
//
//    override func onCore(_ event: Event<Element>, _ c: C) async {
//        await eventHandler(c.call(), event)
//    }
//
//    #if TRACE_RESOURCES
//        deinit {
//            Task {
//                _ = await Resources.decrementTotal()
//            }
//        }
//    #endif
//}
