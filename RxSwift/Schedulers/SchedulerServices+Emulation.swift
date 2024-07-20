//
//  SchedulerServices+Emulation.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 6/6/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

enum SchedulePeriodicRecursiveCommand {
    case tick
    case dispatchStart
}

final class SchedulePeriodicRecursive<State> {
    typealias RecursiveAction = (C, State) async -> State
    typealias RecursiveScheduler = AnyRecursiveScheduler<SchedulePeriodicRecursiveCommand>

    private let scheduler: SchedulerType
    private let startAfter: RxTimeInterval
    private let period: RxTimeInterval
    private let action: RecursiveAction

    private var state: State
    private let pendingTickCount: AtomicInt

    init(
        scheduler: SchedulerType,
        startAfter: RxTimeInterval,
        period: RxTimeInterval,
        action: @escaping RecursiveAction,
        state: State
    )
    async {
        pendingTickCount = await AtomicInt(0)
        self.scheduler = scheduler
        self.startAfter = startAfter
        self.period = period
        self.action = action
        self.state = state
    }

    func start(_ c: C) async -> Disposable {
        await scheduler.scheduleRecursive(
            SchedulePeriodicRecursiveCommand.tick,
            c.call(),
            dueTime: startAfter,
            action: tick
        )
    }

    func tick(_ command: SchedulePeriodicRecursiveCommand, _ c: C, scheduler: RecursiveScheduler) async {
        // Tries to emulate periodic scheduling as best as possible.
        // The problem that could arise is if handling periodic ticks take too long, or
        // tick interval is short.
        switch command {
        case .tick:
            await scheduler.schedule(.tick, c.call(), dueTime: period)

            // The idea is that if on tick there wasn't any item enqueued, schedule to perform work immediately.
            // Else work will be scheduled after previous enqueued work completes.
            if await increment(pendingTickCount) == 0 {
                await tick(.dispatchStart, c.call(), scheduler: scheduler)
            }

        case .dispatchStart:
            state = await action(c.call(), state)
            // Start work and schedule check is this last batch of work
            if await decrement(pendingTickCount) > 1 {
                // This gives priority to scheduler emulation, it's not perfect, but helps
                await scheduler.schedule(SchedulePeriodicRecursiveCommand.dispatchStart, c.call())
            }
        }
    }
}
