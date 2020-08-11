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

/// A StateableResponsive can react to Stateable that expose Observable<State>
protocol StateableResponsive {
    /// The Rx subject that will be feed by each Stateable
    var stateSubject: PublishSubject<State> { get }

    /// The Rx bag that will be used for stateSubject subscriptions
    var disposeBag: DisposeBag { get }
}

extension StateableResponsive where Self: Coordinator {

    /// Present a view controller according to PresentationStyle
    /// It also create a subscription between the stateable and the inner stateSubject
    /// so that a StateableResponsive can react to state updates
    ///
    /// - Parameters:
    ///   - viewController: The ViewController we want to present (it will be presented by the rootViewController)
    ///   - style: The presentation style (show, present or popup)
    ///   - animation: Wether the transition should be animated or not
    ///   - stateable: The stateable the will feed the inner stateSubject
    func present(viewController: UIViewController,
                 withStyle style: PresentationStyle,
                 withAnimation animation: Bool,
                 withStateable stateable: Stateable,
                 lockWhilePresenting VCType: String? = nil) {

        // present the view controller according to the presentation style
        self.present(viewController: viewController, withStyle: style, withAnimation: animation, lockWhilePresenting: VCType, disposeBag: self.disposeBag)

        // bind the stateable to the inner state subject
        stateable.state.takeUntil(viewController.rx.deallocated)
            .subscribe(onNext: { [weak self] (state) in
                self?.stateSubject.onNext(state)
            })
            .disposed(by: self.disposeBag)
    }
}
