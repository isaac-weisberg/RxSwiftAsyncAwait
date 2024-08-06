//
//  NopDisposable.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/15/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/// Represents a disposable that does nothing on disposal.
///
/// Nop = No Operation
private struct NopDisposable : SynchronousDisposable {
 
    fileprivate static let noOp: SynchronousDisposable = NopDisposable()
    
    private init() {
        
    }
    
    /// Does nothing.
    public func dispose() {
    }
}

extension Disposables {
    /**
     Creates a disposable that does nothing on disposal.
     */
    static public func create() -> SynchronousDisposable { NopDisposable.noOp }
    static public func createSync() -> AsynchronousDisposable { NopSyncDisposable.noOp }
}

private struct NopSyncDisposable : AsynchronousDisposable {
 
    fileprivate static let noOp: AsynchronousDisposable = NopSyncDisposable()
    
    private init() {
        
    }
    
    /// Does nothing.
    public func dispose() async {
    }
}
