//
//  Cancelable.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 3/12/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

//public protocol SynchronousCancelable: SynchronousDisposable {
//    func isDisposed() -> Bool
//}

/// Represents disposable resource with state tracking.
public protocol AsynchronousCancelable: AsynchronousDisposable {
    /// Was resource disposed.
    func isDisposed() async -> Bool
}
