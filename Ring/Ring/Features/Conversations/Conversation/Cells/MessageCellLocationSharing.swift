/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
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

class MessageCellLocationSharing: MessageCell {

    private let locationManager = CLLocationManager()
    var maplyViewController: MaplyBaseViewController? // protected in Swift?

    override func configureFromItem(_ conversationViewModel: ConversationViewModel, _ items: [MessageViewModel]?, cellForRowAt indexPath: IndexPath) {
        super.configureFromItem(conversationViewModel, items, cellForRowAt: indexPath)

        self.setupMaply()
        self.displayMapTile()
    }

    private func setupMaply() {
        self.maplyViewController = MaplyViewController(mapType: .typeFlat)
        self.bubble.addSubview(self.maplyViewController!.view)
        self.maplyViewController!.view.frame = self.bubble.bounds
        // TODO: look into this
        //self.addChild(self.maplyViewController!)
    }

    private func getMaplyLayer() -> MaplyQuadImageTilesLayer? {
        // we'll need this layer in a second
        let layer: MaplyQuadImageTilesLayer

        // Because this is a remote tile set, we'll want a cache directory
        let baseCacheDir = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0]
        let tilesCacheDir = "\(baseCacheDir)/stamentiles/"
        let maxZoom = Int32(19)

        // Stamen Terrain Tiles, courtesy of Stamen Design under the Creative Commons Attribution License.
        // Data by OpenStreetMap under the Open Data Commons Open Database License.
        guard let tileSource = MaplyRemoteTileSource(
            baseURL: "http://tile.stamen.com/terrain/",
            ext: "png",
            minZoom: 0,
            maxZoom: maxZoom) else {
                // can't create remote tile source
                return nil
        }
        tileSource.cacheDir = tilesCacheDir
        layer = MaplyQuadImageTilesLayer(tileSource: tileSource)!

        return layer
    }

    private func displayMapTile() {
        self.maplyViewController!.clearColor = UIColor.white

        // and thirty fps if we can get it ­ change this to 3 if you find your app is struggling
        self.maplyViewController!.frameInterval = 2

        // set up the data source
        if let layer = getMaplyLayer() {
            layer.handleEdges = false
            layer.coverPoles = false
            layer.requireElev = false
            layer.waitLoad = false
            layer.drawPriority = 0
            layer.singleLevelLoading = false
            self.maplyViewController!.add(layer)
        }

        // start up over Madrid, center of the old-world
//                let long = -3.6704803
//                let lat = 40.5023056

        //if let location = locationManager.location?.coordinate {
        //            long = location.longitude
        //            lat = location.latitude
        //        }

        if let mapViewC = self.maplyViewController as? MaplyViewController {
            mapViewC.panGesture = false
            mapViewC.pinchGesture = false
            mapViewC.rotateGesture = false
            mapViewC.twoFingerTapGesture = false
            mapViewC.doubleTapDragGesture = false
            mapViewC.doubleTapZoomGesture = false

            mapViewC.height = 0.0005
            //mapViewC.setPosition(MaplyCoordinateMakeWithDegrees(Float(long), Float(lat)))
//            mapViewC.animate(toPosition: MaplyCoordinateMakeWithDegrees(Float(long), Float(lat)), height: 0.001, time: 0)

//            mapViewC.startLocationTracking(with: self, useHeading: true, useCourse: true, simulate: false)
//            mapViewC.changeLocationTrackingLockType(MaplyLocationLockNorthUp)
        }
    }
}

extension MessageCellLocationSharing: MaplyLocationTrackerDelegate {
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        self.log.error(error.localizedDescription)
    }

    func locationManager(_ manager: CLLocationManager, didChange status: CLAuthorizationStatus) {
        self.log.debug("[MaplyLocationTrackerDelegate] didChange \(status.rawValue)")
    }
}
