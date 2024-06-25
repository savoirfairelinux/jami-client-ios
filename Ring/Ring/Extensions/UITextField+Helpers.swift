/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
 *
 *  Author: Andreas Traczyk <andreas.traczyk@savoirfairelinux.com>
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

extension UITextField {
    func setPadding(_ left: CGFloat, _ right: CGFloat) {
        leftView = UIView(frame: CGRect(x: 0, y: 0, width: left, height: frame.size.height))
        rightView = UIView(frame: CGRect(x: 0, y: 0, width: right, height: frame.size.height))
        leftViewMode = .always
        rightViewMode = .always
    }

    func addCloseToolbar() {
        let bar = UIToolbar()
        let doneButton = UIBarButtonItem(
            title: L10n.Global.close,
            style: .plain,
            target: self,
            action: #selector(hideKeyboard)
        )
        let spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        bar.items = [spacer, doneButton]
        bar.sizeToFit()
        inputAccessoryView = bar
    }

    @objc
    private func hideKeyboard() {
        resignFirstResponder()
    }
}
