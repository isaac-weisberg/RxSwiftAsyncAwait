//
//  DisposeBase.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 4/4/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

func SynchronousDisposeBaseInit() {
    
        #if TRACE_RESOURCES
        Task {
            _ = await Resources.incrementTotal()
        }
        #endif
}

func SynchronousDisposeBaseDeinit() {
    
        #if TRACE_RESOURCES
            Task {
                _ = await Resources.decrementTotal()
            }
        #endif
}

///// Base class for all disposables.
//public class SynchronousDisposeBase {
//    init() {
//        SynchronousDisposeBaseInit()
//    }
//
//    deinit {
//        SynchronousDisposeBaseDeinit()
//    }
//}
