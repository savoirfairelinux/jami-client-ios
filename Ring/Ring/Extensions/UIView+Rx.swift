/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
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

import UIKit
import RxSwift
import RxCocoa

extension Reactive where Base: UIView {

    //show view with animation and hide without
    public var isVisible: AnyObserver<Bool> {
        return Binder(self.base) { view, hidden in
            if hidden == true {
                view.isHidden = true
                view.alpha = 0
            } else {
                UIView.animate(withDuration: 0.3, delay: 0.5, options: .curveEaseOut,
                               animations: { view.alpha = 1 },
                               completion: { _ in view.isHidden = false
                })
            }
        }.asObserver()
    }
}
