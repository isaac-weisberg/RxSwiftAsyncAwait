//
//  ObserverBase.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/15/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

protocol ObserverBase: Disposable, ObserverType {
    associatedtype Element
    
    func onCore(_ event: Event<Element>) async
    func isStopped() async -> Bool
    func setIsStopped() async
}

extension ObserverBase {
    func on(_ event: Event<Element>) async {
        switch event {
        case .next:
            if await !isStopped() {
                await self.onCore(event)
            }
        case .error, .completed:
            if await !isStopped() {
                await setIsStopped()
                await self.onCore(event)
            }
        }
    }
}

private final actor ObserverBaseImpl<Element>: ObserverBase {
    /// copy-paster
    private var isStopped = false
    
    func setIsStopped() async {
        isStopped = true
    }
    
    func isStopped() async -> Bool {
        isStopped
    }
    
    func dispose() {
        isStopped = true
    }
    /// copy-paster

    func on(_ event: Event<Element>) async {
        switch event {
        case .next:
            if !isStopped {
                self.onCore(event)
            }
        case .error, .completed:
            if !isStopped {
                isStopped = true
                self.onCore(event)
            }
        }
    }

    func onCore(_ event: Event<Element>) {
        rxAbstractMethod()
    }
}



private actor ObserverBaseLegacyyy<Element> : Disposable, ObserverType {
    private var isStopped = false

    func on(_ event: Event<Element>) async {
        switch event {
        case .next:
            if !isStopped {
                self.onCore(event)
            }
        case .error, .completed:
            if !isStopped {
                isStopped = true
                self.onCore(event)
            }
        }
    }

    func onCore(_ event: Event<Element>) {
        rxAbstractMethod()
    }

    func dispose() {
        isStopped = true
    }
}
