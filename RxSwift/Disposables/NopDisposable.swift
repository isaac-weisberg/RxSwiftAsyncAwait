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
private struct NopDisposable : UnsynchronizedDisposable {
 
    fileprivate static let noOp: UnsynchronizedDisposable = NopDisposable()
    
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
    static public func create() -> UnsynchronizedDisposable { NopDisposable.noOp }
    static public func createSync() -> SynchronizedDisposable { NopSyncDisposable.noOp }
}

private struct NopSyncDisposable : SynchronizedDisposable {
 
    fileprivate static let noOp: SynchronizedDisposable = NopSyncDisposable()
    
    private init() {
        
    }
    
    /// Does nothing.
    public func dispose() async {
    }
}
