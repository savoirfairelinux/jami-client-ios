/*
 *  Copyright (C) 2020 Savoir-faire Linux Inc.
 *
 *  Author: Raphaël Brulé <raphael.brule@savoirfairelinux.com>
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
import Reusable

class MessageCellLocationSharingReceived: MessageCellLocationSharing {

    @IBOutlet weak var receivedBubbleLeading: NSLayoutConstraint!
    @IBOutlet weak var receivedBubbleTrailling: NSLayoutConstraint!

    override func configureFromItem(_ conversationViewModel: ConversationViewModel, _ items: [MessageViewModel]?, cellForRowAt indexPath: IndexPath) {
        super.configureFromItem(conversationViewModel, items, cellForRowAt: indexPath)

        // Primary location
        conversationViewModel.myContactsLocation
            .subscribe(onNext: { [weak self, weak conversationViewModel] _ in
                // TODO: implement location map with a new API
            })
            .disposed(by: self.disposeBag)

        // Secondary location
        conversationViewModel.myLocation
            .subscribe(onNext: { [weak self, weak conversationViewModel] _ in
                // TODO: implement location map with a new API
            })
            .disposed(by: self.disposeBag)
    }

    override func setUplocationSharingMessageTextView(username: String) {
        super.setUplocationSharingMessageTextView(username: username)
        self.locationSharingMessageTextView.text = L10n.Conversation.explanationReceivingLocationFrom + username
        self.locationSharingMessageTextView.adjustHeightFromContentSize()
    }

    override func updateWidth(_ shouldExpand: Bool) {
        let normalValue: CGFloat = 116
        let extendedValue: CGFloat = 16
        if shouldExpand {
            self.receivedBubbleTrailling.constant = extendedValue
            self.receivedBubbleLeading.constant = extendedValue
        } else {
            self.receivedBubbleTrailling.constant = normalValue
            self.receivedBubbleLeading.constant = 64
        }
    }
}
