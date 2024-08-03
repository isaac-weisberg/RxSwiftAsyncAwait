//
//  Observable.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/8/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/// A type-erased `ObservableType`. 
///
/// It represents a push style sequence.

func ObservableInit() {
#if TRACE_RESOURCES
        _ = Resources.incrementTotal()
#endif
}


func ObservableDeinit() {
#if TRACE_RESOURCES
        _ = Resources.decrementTotal()
#endif
}

public class Observable<Element> : ObservableType {
    init() {
        ObservableInit()
    }
    
    public func subscribe<Observer: ObserverType>(_ lock: ActorLock, _ observer: Observer) -> Disposable where Observer.Element == Element {
        rxAbstractMethod()
    }
    
    public func asObservable() -> Observable<Element> { self }
    
    deinit {
#if TRACE_RESOURCES
        _ = Resources.decrementTotal()
#endif
    }
}
