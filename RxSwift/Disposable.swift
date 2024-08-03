//
//  Disposable.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/8/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

public protocol UnsynchronizedDisposable {
    func dispose()
}

/// Represents a disposable resource.
public protocol SynchronizedDisposable {
    /// Dispose resource.
    func dispose() async
}
