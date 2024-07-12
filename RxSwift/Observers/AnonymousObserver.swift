//
//  AnonymousObserver.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/8/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

final actor AnonymousObserver<Element>: ObserverBase {
    typealias EventHandler = (Event<Element>) async -> Void

    private let eventHandler: EventHandler
    private var isStopped = false
    
    func setIsStopped() async {
        isStopped = true
    }
    
    func isStopped() async -> Bool {
        isStopped
    }
    
    func dispose() async {
        isStopped = true
    }

    init(_ eventHandler: @escaping EventHandler) {
#if TRACE_RESOURCES
        _ = Resources.incrementTotal()
#endif
        self.eventHandler = eventHandler
    }

    func onCore(_ event: Event<Element>) async {
        await self.eventHandler(event)
    }

#if TRACE_RESOURCES
    deinit {
        _ = Resources.decrementTotal()
    }
#endif
}
