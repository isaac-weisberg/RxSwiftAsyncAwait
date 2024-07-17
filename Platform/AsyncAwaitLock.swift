//
//  AsyncAwaitLock.swift
//  RxSwift
//
//  Created by i.weisberg on 12/07/2024.
//  Copyright © 2024 Krunoslav Zaher. All rights reserved.
//

import Foundation

public final actor AsyncAwaitLock {
    private var latestTask: Task<Void, Never>?
    
    public init() async {
        #if TRACE_RESOURCES
            _ = await Resources.incrementTotal()
        #endif
    }

    deinit {
        #if TRACE_RESOURCES
            Task {
                _ = await Resources.decrementTotal()
            }
        #endif
    }
    
    public func performLocked<R>(_ work: @escaping () async -> R) async -> R {
        let theActualTask: Task<R, Never>
        if let latestTask {
            theActualTask = Task {
                _ = await latestTask.value
                
                let result = await work()
                
                return result
            }
        } else {
            theActualTask = Task {
                let result = await work()
                
                return result
            }
        }
        
        let voidTask = Task<Void, Never> {
            #if TRACE_RESOURCES
                _ = await Resources.incrementTotal()
            #endif
            _ = await theActualTask.value
            
            #if TRACE_RESOURCES
                _ = await Resources.decrementTotal()
            #endif
        }
        latestTask = voidTask
        
        let actualTaskValue = await theActualTask.value
        
        return actualTaskValue
    }
    
    public func performLockedThrowing<R>(_ work: @escaping () async throws -> R) async throws -> R {
        let theActualTask: Task<R, Error> = Task { [self] in
            if let latestTask {
                _ = await latestTask.value
            }
            
            let result = try await work()
            
            return result
        }
        
        let voidTask = Task<Void, Never> {
            #if TRACE_RESOURCES
                _ = await Resources.incrementTotal()
            #endif
            _ = try? await theActualTask.value
            
            #if TRACE_RESOURCES
                _ = await Resources.decrementTotal()
            #endif
        }
        latestTask = voidTask
        
        return try await theActualTask.value
    }
}
