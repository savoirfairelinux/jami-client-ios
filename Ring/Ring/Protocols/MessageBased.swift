//
//  MessageBased.swift
//  Ring
//
//  Created by kateryna on 2022-11-16.
//  Copyright © 2022 Savoir-faire Linux. All rights reserved.
//

import Foundation
import RxSwift

/// A MessageBased used to create  swiftUI components for message
public protocol MessageBased {

    var message: MessageModel { get }
    var contextMenuState: PublishSubject<State> { get set }

    init(message: MessageModel, contextMenuState: PublishSubject<State>)

}
