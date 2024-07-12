//
//  ScheduledItem.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 9/2/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

struct ScheduledItem<T>:
    ScheduledItemType,
    InvocableType
{
    typealias Action = (T) async -> Disposable

    private let action: Action
    private let state: T

    private let disposable: SingleAssignmentDisposable

    func isDisposed() async -> Bool {
        await self.disposable.isDisposed()
    }

    init(action: @escaping Action, state: T) async {
        self.disposable = await SingleAssignmentDisposable()
        self.action = action
        self.state = state
    }

    func invoke() async {
        await self.disposable.setDisposable(self.action(self.state))
    }

    func dispose() async {
        await self.disposable.dispose()
    }
}
