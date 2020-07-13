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
import RxCocoa

class MessageCellLocationSharingSent: MessageCellLocationSharing {

    private var myLocationMarker = MaplyScreenMarker()
    private var markerComponentObject: MaplyComponentObject?

    @IBOutlet weak var sentBubbleLeading: NSLayoutConstraint!

    @IBOutlet weak var stopSharingButton: UIButton!
    @IBAction func stopSharingButton(_ sender: Any) {
        self.delete(sender)
    }

    override func configureFromItem(_ conversationViewModel: ConversationViewModel, _ items: [MessageViewModel]?, cellForRowAt indexPath: IndexPath) {
        super.configureFromItem(conversationViewModel, items, cellForRowAt: indexPath)

        conversationViewModel.myLocation
            .subscribe({ [weak self, weak conversationViewModel] location in
                guard let self = self, location.element != nil, let location = location.element!?.coordinate else { return }

                self.markerComponentObject = self.updateLocationAndMarker(location: location,
                                                                          imageData: conversationViewModel?.myOwnProfileImageData,
                                                                          username: conversationViewModel?.userName.value,
                                                                          marker: self.myLocationMarker,
                                                                          markerDump: self.markerComponentObject)
            })
            .disposed(by: self.disposeBag)

        self.setupStopSharingButton()
    }

    private func setupStopSharingButton() {
        self.stopSharingButton.setTitle(L10n.Actions.stopLocationSharing, for: .normal)
        self.stopSharingButton.backgroundColor = UIColor.red
        self.stopSharingButton.setTitleColor(UIColor.white, for: .normal)
        self.bubble.addSubview(stopSharingButton)
    }

    override func myPositionButtonAction(sender: UIButton!) {
        if let mapViewC = self.maplyViewController as? MaplyViewController {
            mapViewC.animate(toPosition: self.myLocationMarker.loc, time: 0.5)
        }
    }

    override func updateWidth(_ shouldExpand: Bool) {
        let normalValue: CGFloat = 164
        let extendedValue: CGFloat = 16
        if shouldExpand {
            self.sentBubbleLeading.constant = extendedValue
        } else {
            self.sentBubbleLeading.constant = normalValue
        }
    }
}
