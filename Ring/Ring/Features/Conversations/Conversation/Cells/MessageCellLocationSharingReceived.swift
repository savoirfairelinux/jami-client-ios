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

    /// Primary location
    private var myContactsLocation: MarkerAndComponentObject = (marker: MaplyScreenMarker(), componentObject: nil)
    /// Secondary location
    private var myLocation: MarkerAndComponentObject = (marker: MaplyScreenMarker(), componentObject: nil)

    @IBOutlet weak var receivedBubbleLeading: NSLayoutConstraint!
    @IBOutlet weak var receivedBubbleTrailling: NSLayoutConstraint!

    override func configureFromItem(_ conversationViewModel: ConversationViewModel, _ items: [MessageViewModel]?, cellForRowAt indexPath: IndexPath) {
        super.configureFromItem(conversationViewModel, items, cellForRowAt: indexPath)

        // Primary location
        conversationViewModel.myContactsLocation
            .subscribe(onNext: { [weak self, weak conversationViewModel] location in
                guard let self = self, let location = location else { return }

                self.myContactsLocation.componentObject = self.updateLocationAndMarker(location: location,
                                                                                       imageData: conversationViewModel?.profileImageData.value,
                                                                                       username: conversationViewModel?.userName.value,
                                                                                       marker: self.myContactsLocation.marker,
                                                                                       markerDump: self.myContactsLocation.componentObject)
            })
            .disposed(by: self.disposeBag)

        // Secondary location
        conversationViewModel.myLocation
            .subscribe(onNext: { [weak self, weak conversationViewModel] location in
                guard let self = self else { return }

                if let location = location?.coordinate {
                    self.myLocation.componentObject = self.updateLocationAndMarker(location: location,
                                                                                   imageData: conversationViewModel?.myOwnProfileImageData,
                                                                                   username: conversationViewModel?.userName.value,
                                                                                   marker: self.myLocation.marker,
                                                                                   markerDump: self.myLocation.componentObject,
                                                                                   tryToAnimateToMarker: false)
                } else if self.myLocation.componentObject != nil {
                    self.maplyViewController!.remove(self.myLocation.componentObject!)
                    self.myLocation.componentObject = nil
                }
            })
            .disposed(by: self.disposeBag)
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
