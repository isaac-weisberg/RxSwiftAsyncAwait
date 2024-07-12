//
//  SynchronizedDisposeType.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 10/25/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

protocol SynchronizedDisposeType: AnyObject, Disposable, Lock {
    func synchronized_dispose() async
}

extension SynchronizedDisposeType {
    func synchronizedDispose() async {
        return await performLocked {
            await self.synchronized_dispose()
        }
    }
}
