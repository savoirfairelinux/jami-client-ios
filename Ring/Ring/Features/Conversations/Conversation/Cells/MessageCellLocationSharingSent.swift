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
    @IBOutlet weak var stopSharingButton: UIButton!

    @IBAction func stopSharingButton(_ sender: Any) {
        self.delete(sender)
    }

    override func configureFromItem(_ conversationViewModel: ConversationViewModel, _ items: [MessageViewModel]?, cellForRowAt indexPath: IndexPath) {
        super.configureFromItem(conversationViewModel, items, cellForRowAt: indexPath)

        conversationViewModel.myLocation
 //            .observeOn(MainScheduler.instance)
            .subscribe({ [weak self] location in
                guard let self = self, location.element != nil, let location = location.element!?.coordinate else { return }

                let maplyCoordonate = MaplyCoordinateMakeWithDegrees(Float(location.longitude), Float(location.latitude))

                // TODO: get the proper image data
                let circledImage = UIImage(asset: Asset.fallbackAvatar)!
                self.myLocationMarker.image = circledImage

                self.myLocationMarker.loc.x = maplyCoordonate.x
                self.myLocationMarker.loc.y = maplyCoordonate.y
                self.myLocationMarker.size = CGSize(width: 32, height: 32)

                if let mapViewC = self.maplyViewController as? MaplyViewController {
                    mapViewC.animate(toPosition: maplyCoordonate, time: 0)
                }
            })
            .disposed(by: self.disposeBag)

        self.maplyViewController!.addScreenMarkers([myLocationMarker], desc: nil)

        self.stopSharingButton.setTitle(L10n.Actions.stopLocationSharing, for: .normal)
        self.stopSharingButton.backgroundColor = UIColor.red
        self.stopSharingButton.setTitleColor(UIColor.white, for: .normal)
        self.maplyViewController!.view.addSubview(stopSharingButton)
    }

}
