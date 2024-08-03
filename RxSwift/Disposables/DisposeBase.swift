//
//  DisposeBase.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 4/4/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

func UnsynchronizedDisposeBaseInit() {
    
        #if TRACE_RESOURCES
        Task {
            _ = await Resources.incrementTotal()
        }
        #endif
}

func UnsynchronizedDisposeBaseDeinit() {
    
        #if TRACE_RESOURCES
            Task {
                _ = await Resources.decrementTotal()
            }
        #endif
}

/// Base class for all disposables.
public class UnsynchronizedDisposeBase {
    init() {
        UnsynchronizedDisposeBaseInit()
    }

    deinit {
        UnsynchronizedDisposeBaseDeinit()
    }
}
