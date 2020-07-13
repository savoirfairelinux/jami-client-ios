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

    private var myContactsLocationMarker = MaplyScreenMarker()
    private var markerComponentObject: MaplyComponentObject?

    override func configureFromItem(_ conversationViewModel: ConversationViewModel, _ items: [MessageViewModel]?, cellForRowAt indexPath: IndexPath) {
        super.configureFromItem(conversationViewModel, items, cellForRowAt: indexPath)

        conversationViewModel.myContactsLocation
            //.observeOn(MainScheduler.instance)
            .subscribe({ [weak self] location in
                guard let self = self, location.element != nil, let location = location.element! else { return }

                self.markerComponentObject = self.updateLocationAndMarker(location: location,
                                                                                    imageData: conversationViewModel.profileImageData.value,
                                                                                    marker: self.myContactsLocationMarker,
                                                                                    markerDump: self.markerComponentObject)
            })
            .disposed(by: self.disposeBag)

        self.maplyViewController?.addScreenMarkers([myContactsLocationMarker], desc: nil)
    }
}
