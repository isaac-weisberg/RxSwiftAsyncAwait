//
//  AsyncAwaitLock.swift
//  RxSwift
//
//  Created by i.weisberg on 12/07/2024.
//  Copyright © 2024 Krunoslav Zaher. All rights reserved.
//

import Foundation

final actor AsyncAwaitLock {
    private var latestTask: Task<Void, Never>?
    
    init() async {
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
    
    func performLocked<R>(_ work: @escaping () async -> R) async -> R {
        let theActualTask: Task<R, Never> = Task { [self] in
            if let latestTask {
                _ = await latestTask.value
            }
            
            let result = await work()
            
            return result
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
        
        return await theActualTask.value
    }
    
    func performLockedThrowing<R>(_ work: @escaping () async throws -> R) async throws -> R {
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
