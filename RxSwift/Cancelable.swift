//
//  Cancelable.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 3/12/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

public protocol UnsynchronizedCancelable: UnsynchronizedDisposable {
    func isDisposed() -> Bool
}

/// Represents disposable resource with state tracking.
public protocol SynchronizedCancelable: SynchronizedDisposable {
    /// Was resource disposed.
    func isDisposed() async -> Bool
}
