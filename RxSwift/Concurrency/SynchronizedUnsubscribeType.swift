//
//  AsynchronousUnsubscribeType.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 10/25/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

protocol AsynchronousUnsubscribeType: AnyObject {
    associatedtype DisposeKey

    func AsynchronousUnsubscribe(_ disposeKey: DisposeKey) async
}
