/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
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
import Chameleon

extension Chameleon {
    static func setRingThemeUsingPrimaryColor (_ primaryColor: UIColor, withSecondaryColor secondaryColor: UIColor, andContentStyle contentStyle: UIContentStyle) {

        var contentColor: UIColor
        var secondaryContentColor: UIColor

        switch contentStyle {
        case .contrast:
            contentColor = ContrastColorOf(primaryColor, returnFlat: false)
            secondaryContentColor = ContrastColorOf(secondaryColor, returnFlat: false)
        case .light:
            contentColor = UIColor.white
            secondaryContentColor = UIColor.white
        case .dark:
            contentColor = UIColor.flatBlackColorDark()
            secondaryContentColor = UIColor.flatBlackColorDark()
        }

        UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).tintColor = UIColor.flatGray()

        MessageBubble.appearance().tintColor = secondaryContentColor
        MessageBubble.appearance().backgroundColor = secondaryColor

        MessageBubble.appearance(whenContainedInInstancesOf: [MessageCellSent.self]).tintColor = contentColor
        MessageBubble.appearance(whenContainedInInstancesOf: [MessageCellSent.self]).backgroundColor = UIColor.ringMsgCellSent
        UILabel.appearance(whenContainedInInstancesOf: [MessageBubble.self, MessageCellSent.self]).textColor = UIColor.ringMsgCellSentText

        MessageBubble.appearance(whenContainedInInstancesOf: [MessageCellReceived.self]).tintColor = secondaryContentColor
        MessageBubble.appearance(whenContainedInInstancesOf: [MessageCellReceived.self]).backgroundColor = UIColor.ringMsgCellReceived
        UILabel.appearance(whenContainedInInstancesOf: [MessageBubble.self, MessageCellReceived.self]).textColor = UIColor.ringMsgCellReceivedText

        MessageBubble.appearance(whenContainedInInstancesOf: [MessageCellGenerated.self]).tintColor = UIColor.clear
        MessageBubble.appearance(whenContainedInInstancesOf: [MessageCellGenerated.self]).backgroundColor = UIColor.clear

        UIButton.appearance().backgroundColor = UIColor.clear
        DesignableButton.appearance().backgroundColor = secondaryColor
        ButtonTransparentBackground.appearance().tintColor = secondaryColor
        ButtonTransparentBackground.appearance().backgroundColor = UIColor.clear
        UIButton.appearance(whenContainedInInstancesOf: [UIView.self, UIImagePickerController.self]).tintColor = UIColor.white
    }
}
