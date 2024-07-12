//
//  CombineLatest.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 3/21/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

protocol CombineLatestProtocol: AnyObject {
    func next(_ index: Int) async
    func fail(_ error: Swift.Error) async
    func done(_ index: Int) async
}

class CombineLatestSink<Observer: ObserverType>:
    Sink<Observer>,
    CombineLatestProtocol
{
    typealias Element = Observer.Element
   
    let lock: RecursiveLock

    private let arity: Int
    private var numberOfValues = 0
    private var numberOfDone = 0
    private var hasValue: [Bool]
    private var isDone: [Bool]
   
    init(arity: Int, observer: Observer, cancel: Cancelable) async {
        self.lock = await RecursiveLock()
        self.arity = arity
        self.hasValue = [Bool](repeating: false, count: arity)
        self.isDone = [Bool](repeating: false, count: arity)
        
        await super.init(observer: observer, cancel: cancel)
    }
    
    func getResult() async throws -> Element {
        rxAbstractMethod()
    }
    
    func next(_ index: Int) async {
        if !self.hasValue[index] {
            self.hasValue[index] = true
            self.numberOfValues += 1
        }

        if self.numberOfValues == self.arity {
            do {
                let result = try await self.getResult()
                await self.forwardOn(.next(result))
            }
            catch let e {
                await self.forwardOn(.error(e))
                await self.dispose()
            }
        }
        else {
            var allOthersDone = true

            for i in 0 ..< self.arity {
                if i != index && !self.isDone[i] {
                    allOthersDone = false
                    break
                }
            }
            
            if allOthersDone {
                await self.forwardOn(.completed)
                await self.dispose()
            }
        }
    }
    
    func fail(_ error: Swift.Error) async {
        await self.forwardOn(.error(error))
        await self.dispose()
    }
    
    func done(_ index: Int) async {
        if self.isDone[index] {
            return
        }

        self.isDone[index] = true
        self.numberOfDone += 1

        if self.numberOfDone == self.arity {
            await self.forwardOn(.completed)
            await self.dispose()
        }
    }
}

final class CombineLatestObserver<Element>:
    ObserverType,
    LockOwnerType,
    SynchronizedOnType
{
    typealias ValueSetter = (Element) -> Void
    
    private let parent: CombineLatestProtocol
    
    let lock: RecursiveLock
    private let index: Int
    private let this: Disposable
    private let setLatestValue: ValueSetter
    
    init(lock: RecursiveLock, parent: CombineLatestProtocol, index: Int, setLatestValue: @escaping ValueSetter, this: Disposable) {
        self.lock = lock
        self.parent = parent
        self.index = index
        self.this = this
        self.setLatestValue = setLatestValue
    }
    
    func on(_ event: Event<Element>) async {
        await self.synchronizedOn(event)
    }

    func synchronized_on(_ event: Event<Element>) async {
        switch event {
        case .next(let value):
            self.setLatestValue(value)
            await self.parent.next(self.index)
        case .error(let error):
            await self.this.dispose()
            await self.parent.fail(error)
        case .completed:
            await self.this.dispose()
            await self.parent.done(self.index)
        }
    }
}
