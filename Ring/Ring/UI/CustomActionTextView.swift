/*
*  Copyright (C) 2020 Savoir-faire Linux Inc.
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

enum SupportedActions {
    case paste
    case copy
    case cut
    case lookUp
    case delete
    case none

    func toSelector() -> Selector? {
        switch self {
        case .none:
            return nil
        case .copy:
            return #selector(UIResponderStandardEditActions.copy(_:))
        case .paste:
            return #selector(UIResponderStandardEditActions.paste(_:))
        case .cut:
            return #selector(UIResponderStandardEditActions.cut(_:))
        case .delete:
            return #selector(UIResponderStandardEditActions.delete(_:))
        case .lookUp:
            return Selector(("_lookup:"))
        }
    }
}

class CustomActionTextView: UITextView {
    var actionsToRemove = [SupportedActions.none]

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {

        for actionToRemove in actionsToRemove {
            if action == actionToRemove.toSelector() {
                return false
            }
        }
        return super.canPerformAction(action, withSender: sender)
    }

    override var canBecomeFirstResponder: Bool {
        return true
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        setup()
    }
    func setup() {
        textContainerInset = UIEdgeInsets.zero
        textContainer.lineFragmentPadding = 0
    }

    func centerVertically() {
        let space = self.bounds.size.height - self.contentSize.height
        let inset = max(0, space/2.0)
        self.contentInset = UIEdgeInsets(top: inset, left: self.contentInset.left, bottom: inset, right: self.contentInset.right)
    }
}
