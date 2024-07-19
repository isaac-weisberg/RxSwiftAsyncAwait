//
//  Bag+Rx.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 10/19/16.
//  Copyright © 2016 Krunoslav Zaher. All rights reserved.
//

// MARK: forEach

@inline(__always)
func dispatch<Element>(_ bag: Bag<(Event<Element>, _ c: C) async -> Void>, _ event: Event<Element>, _ c: C) async {
    await bag._value0?(event, c.call())

    if bag._onlyFastPath {
        return
    }

    let pairs = bag._pairs
    for i in 0 ..< pairs.count {
        await pairs[i].value(event, c.call())
    }

    if let dictionary = bag._dictionary {
        for element in dictionary.values {
            await element(event, c.call())
        }
    }
}

/// Dispatches `dispose` to all disposables contained inside bag.
func disposeAll(in bag: Bag<Disposable>) async {
    await bag._value0?.dispose()

    if bag._onlyFastPath {
        return
    }

    let pairs = bag._pairs
    for i in 0 ..< pairs.count {
        await pairs[i].value.dispose()
    }

    if let dictionary = bag._dictionary {
        for element in dictionary.values {
            await element.dispose()
        }
    }
}
