//
//  InvocableType.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 11/7/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

protocol InvocableType: Sendable {
    func invoke(_ c: C) async
}

protocol InvocableWithValueType: Sendable {
    associatedtype Value: Sendable

    func invoke(_ c: C, _ value: Value) async
}
