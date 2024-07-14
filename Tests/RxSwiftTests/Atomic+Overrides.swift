//
//  Atomic+Overrides.swift
//  Tests
//
//  Created by Krunoslav Zaher on 1/29/19.
//  Copyright © 2019 Krunoslav Zaher. All rights reserved.
//

/// This is a workaround for the overloaded `load` symbol.
@inline(__always)
func globalLoad(_ this: AtomicInt) async -> Int32 {
    return await load(this)
}

/// This is a workaround for the overloaded `add` symbol.
@inline(__always)
@discardableResult
func globalAdd(_ this: AtomicInt, _ value: Int32) async -> Int32 {
    return await add(this, value)
}
