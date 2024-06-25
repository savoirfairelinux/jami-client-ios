/*
 *  Copyright (C) 2017-2021 Savoir-faire Linux Inc.
 *
 *  Author: Alireza Toghiani Matado <alireza.toghiani@savoirfairelinux.com>
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

class PaddingTextField: UITextField {
    var padding: UIEdgeInsets

    init(
        padding: UIEdgeInsets = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10),
        frame: CGRect
    ) {
        self.padding = padding
        super.init(frame: frame)
    }

    required init?(coder aDecoder: NSCoder) {
        padding = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
        super.init(coder: aDecoder)
    }

    override
    func textRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.inset(by: padding)
    }

    override
    func placeholderRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.inset(by: padding)
    }

    override
    func editingRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.inset(by: padding)
    }
}
