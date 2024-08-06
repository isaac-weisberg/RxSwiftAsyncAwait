//
//  AsynchronousDisposeType.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 10/25/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

protocol AsynchronousDisposeType: AnyObject, Disposable, Lock {
    func Asynchronous_dispose() async
}

extension AsynchronousDisposeType {
    func AsynchronousDispose() async {
        return await performLocked {
            await self.Asynchronous_dispose()
        }
    }
}
