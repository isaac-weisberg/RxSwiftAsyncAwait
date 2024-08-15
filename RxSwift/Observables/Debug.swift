//
//  Debug.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 5/2/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

import Foundation

public extension ObservableType {
    /**
     Prints received events for all observers on standard output.

     - seealso: [do operator on reactivex.io](http://reactivex.io/documentation/operators/do.html)

     - parameter identifier: Identifier that is printed together with event description to standard output.
     - parameter trimOutput: Should output be trimmed to max 40 characters.
     - returns: An observable sequence whose events are printed to standard output.
     */
    func debug(
        _ identifier: String? = nil,
        trimOutput: Bool = false,
        file: String = #file,
        line: UInt = #line,
        function: String = #function
    )
        -> Observable<Element> {
        Debug(source: self, identifier: identifier, trimOutput: trimOutput, file: file, line: line, function: function)
    }
}

private let dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"

private func logEvent(_ identifier: String, dateFormat: DateFormatter, content: String) {
    print("\(dateFormat.string(from: Date())): \(identifier) -> \(content)")
}

private final actor DebugSink<Source: ObservableType, Observer: ObserverType>: SinkOverSingleSubscription,
    ObserverType where Observer.Element == Source.Element {
    typealias Element = Observer.Element
    typealias Parent = Debug<Source>

    private let parent: Parent
    private let timestampFormatter = DateFormatter()
    let baseSink: BaseSinkOverSingleSubscription<Observer>

    init(parent: Parent, observer: Observer) async {
        self.parent = parent
        timestampFormatter.dateFormat = dateFormat

        logEvent(self.parent.identifier, dateFormat: timestampFormatter, content: "subscribed")

        baseSink = BaseSinkOverSingleSubscription(observer: observer)
    }

    func on(_ event: Event<Element>, _ c: C) async {
        let maxEventTextLength = 40
        let eventText = "\(event)"

        let eventNormalized = (eventText.count > maxEventTextLength) && parent.trimOutput
            ? String(eventText.prefix(maxEventTextLength / 2)) + "..." +
            String(eventText.suffix(maxEventTextLength / 2))
            : eventText

        logEvent(parent.identifier, dateFormat: timestampFormatter, content: "Event \(eventNormalized)")

        await forwardOn(event, c.call())
        if event.isStopEvent {
            await dispose()
        }
    }

    func dispose() async {
        let disposable = baseSink.setDisposed()

        if let disposable {
            logEvent(parent.identifier, dateFormat: timestampFormatter, content: "willDispose")

            await disposable.dispose()
        }

        logEvent(parent.identifier, dateFormat: timestampFormatter, content: "isDisposed")

    }
}

private final class Debug<Source: ObservableType>: Producer<Source.Element> {
    fileprivate let identifier: String
    fileprivate let trimOutput: Bool
    private let source: Source

    init(source: Source, identifier: String?, trimOutput: Bool, file: String, line: UInt, function: String) {
        self.trimOutput = trimOutput
        if let identifier {
            self.identifier = identifier
        } else {
            let trimmedFile: String
            if let lastIndex = file.lastIndex(of: "/") {
                trimmedFile = String(file[file.index(after: lastIndex) ..< file.endIndex])
            } else {
                trimmedFile = file
            }
            self.identifier = "\(trimmedFile):\(line) (\(function))"
        }
        self.source = source
        super.init()
    }

    override func run<Observer: ObserverType>(_ c: C, _ observer: Observer) async -> AsynchronousDisposable
        where Observer.Element == Source.Element {
        let sink = await DebugSink(parent: self, observer: observer)
        let subscription = await source.subscribe(c.call(), sink)
        return sink
    }
}
