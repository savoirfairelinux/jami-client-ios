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
import Reusable
import UIKit
import RxSwift

/// We assume that every application ViewModel should be aware of the injection bag
/// it allows the factorize a ViewModelBased UIViewController instantiation
protocol ViewModel: AnyObject {

    /// Initializes a new ViewModel with a dependancy injection bag
    ///
    /// - Parameter injectionBag: The injection Bag that will be passed to every sub components that need it
    init(with injectionBag: InjectionBag)
}

protocol Dismissable: AnyObject {

    var dismiss: PublishSubject<Bool> { get set }

    func dismissView()
}

extension Dismissable {
    func dismissView() {
        dismiss.onNext(true)
    }
}

protocol ViewModelBased: AnyObject {
    associatedtype VMType: ViewModel

    /// The viewModel that will be automagically instantiated by instantiate(with injectionBag: InjectionBag)
    var viewModel: VMType! { get set }
}

extension ViewModelBased where Self: UIViewController, Self: StoryboardBased {

    /// Initializes a new ViewModelBased UIViewController
    /// The associated ViewModel will be instantiated as well
    ///
    /// - Parameter injectionBag: The injection Bag that will be passed to every sub components that need it
    /// - Returns: The ViewModelBased UIViewController with its inner ViewModel already instantiated
    static func instantiate(with injectionBag: InjectionBag) -> Self {
        let viewController = Self.instantiate()
        viewController.viewModel = VMType(with: injectionBag)
        return viewController
    }
}
