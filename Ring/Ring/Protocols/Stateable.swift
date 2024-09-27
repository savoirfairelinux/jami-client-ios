/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
 *
 *  Author: Thibault Wittemberg <thibault.wittemberg@savoirfairelinux.com>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 */

import Foundation
import RxSwift
import SwiftUI

/// Represent a navigation state. We mostly use it as an enum
public protocol State {
}

/// A Stateable exposes a navigation state on which StateableResponsive will be subscribed
public protocol Stateable {
    /// The state that will be emitted and catch by the StateableResponsive classes to process the navigation
    var state: Observable<State> { get }
}

class StatePublisher<StateType: State>: Stateable {
    let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()

    func emitState(_ newState: StateType) {
        self.stateSubject.onNext(newState)
    }
}

protocol StateEmittingView: View {
    associatedtype StateEmitterType
    var stateEmitter: StateEmitterType { get }
}
