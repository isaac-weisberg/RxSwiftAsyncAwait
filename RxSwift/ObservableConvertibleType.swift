//
//  ObservableConvertibleType.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 9/17/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/// Type that can be converted to observable sequence (`Observable<Element>`).
public protocol ObservableConvertibleType: Sendable {
    /// Type of elements in sequence.
    associatedtype Element: Sendable

    /// Converts `self` to `Observable` sequence.
    ///
    /// - returns: Observable sequence that represents `self`.
    func asObservable() async -> Observable<Element>
}

/// Type that can be converted to observable sequence (`Observable<Element>`).
public protocol AsyncObservableToAsyncObserverConvertibleType: Sendable {
    /// Type of elements in sequence.
    associatedtype Element: Sendable

    /// Converts `self` to `Observable` sequence.
    ///
    /// - returns: Observable sequence that represents `self`.
    func asObservable() async -> AsyncObservableToAsyncObserver<Element>
}

/// Type that can be converted to observable sequence (`Observable<Element>`).
public protocol AsyncObservableToSyncObserverConvertibleType: Sendable {
    /// Type of elements in sequence.
    associatedtype Element: Sendable

    /// Converts `self` to `Observable` sequence.
    ///
    /// - returns: Observable sequence that represents `self`.
    func asObservable() async -> AsyncObservableToSyncObserver<Element>
}


/// Type that can be converted to observable sequence (`Observable<Element>`).
public protocol SyncObservableToSyncObserverConvertibleType: Sendable {
    /// Type of elements in sequence.
    associatedtype Element: Sendable

    /// Converts `self` to `Observable` sequence.
    ///
    /// - returns: Observable sequence that represents `self`.
    func asObservable() async -> SyncObservableToSyncObserver<Element>
}

/// Type that can be converted to observable sequence (`Observable<Element>`).
public protocol SyncObservableToAsyncObserverConvertibleType: Sendable {
    /// Type of elements in sequence.
    associatedtype Element: Sendable

    /// Converts `self` to `Observable` sequence.
    ///
    /// - returns: Observable sequence that represents `self`.
    func asObservable() async -> SyncObservableToAsyncObserver<Element>
}
