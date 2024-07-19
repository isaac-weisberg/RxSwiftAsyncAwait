//
//  Infallible+Create.swift
//  RxSwift
//
//  Created by Shai Mishali on 27/08/2020.
//  Copyright © 2020 Krunoslav Zaher. All rights reserved.
//

import Foundation

public enum InfallibleEvent<Element> {
    /// Next element is produced.
    case next(Element)

    /// Sequence completed successfully.
    case completed
}

public extension Infallible {
    typealias InfallibleObserver = (InfallibleEvent<Element>) async -> Void

    /**
     Creates an observable sequence from a specified subscribe method implementation.

     - seealso: [create operator on reactivex.io](http://reactivex.io/documentation/operators/create.html)

     - parameter subscribe: Implementation of the resulting observable sequence's `subscribe` method.
     - returns: The observable sequence with the specified implementation for the `subscribe` method.
     */
    static func create(subscribe: @escaping (@escaping InfallibleObserver) async -> Disposable) async -> Infallible<Element> {
        let source = await Observable<Element>.create { c, observer in
            await subscribe { event in
                switch event {
                case let .next(element):
                    await observer.onNext(element, c.call())
                case .completed:
                    await observer.onCompleted(c.call())
                }
            }
        }

        return Infallible(source)
    }
}

extension InfallibleEvent: EventConvertible {
    public var event: Event<Element> {
        switch self {
        case let .next(element):
            return .next(element)
        case .completed:
            return .completed
        }
    }
}
