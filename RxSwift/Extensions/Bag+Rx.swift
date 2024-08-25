//
//  Bag+Rx.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 10/19/16.
//  Copyright © 2016 Krunoslav Zaher. All rights reserved.
//

// MARK: forEach

@inline(__always)
func dispatch<Element>(
    _ bag: Bag<@Sendable (Event<Element>, _ c: C) async -> Void>,
    _ event: Event<Element>,
    _ c: C
)
    async {
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
func disposeAll(in bag: Bag<SynchronousDisposable>) async {
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

extension Bag: Sequence {
    func makeIterator() -> BagIterator<T> {
        BagIterator(self)
    }
}

struct BagIterator<T: Sendable>: IteratorProtocol {
    typealias Element = T
    let bag: Bag<T>
    let sortedKeysOfDictCount: Int
    let sortedKeysOfDict: [BagKey]!

    init(_ bag: Bag<T>) {
        self.bag = bag
        let sortedKeysOfDict = bag._dictionary.map { dict in
            Array(dict.keys)
        }
        self.sortedKeysOfDict = sortedKeysOfDict
        sortedKeysOfDictCount = sortedKeysOfDict?.count ?? 0
    }

    var itemEmission = 0

    mutating func next() -> T? {
        let element = {
            if itemEmission == 0 {
                return bag._value0
            } else {
                if bag._onlyFastPath {
                    return nil
                }

                let pairIndex = itemEmission - 1 //
                if pairIndex < bag._pairs.count {
                    return bag._pairs[pairIndex].value
                }

                let dictIndex = itemEmission - bag._pairs.count - 1

                if dictIndex < sortedKeysOfDictCount {
                    let key = sortedKeysOfDict![dictIndex]
                    return bag._dictionary?[key]
                }

                return nil
            }
        }()

        itemEmission += 1

        return element
    }
}
