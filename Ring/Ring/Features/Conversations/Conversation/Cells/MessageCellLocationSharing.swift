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

class MessageCellLocationSharing: MessageCell {

    var maplyViewController: MaplyBaseViewController? // protected in Swift?
    private var workaround = 0

    override func willRemoveSubview(_ subview: UIView) {
        super.willRemoveSubview(subview)
        self.workaround = 0
    }

    override func configureFromItem(_ conversationViewModel: ConversationViewModel, _ items: [MessageViewModel]?, cellForRowAt indexPath: IndexPath) {
        super.configureFromItem(conversationViewModel, items, cellForRowAt: indexPath)

        if self.maplyViewController as? MaplyViewController == nil || workaround < 2 {
            self.setupMaply()
            self.displayMapTile()
            workaround += 1
        }
    }

    private func setupMaply() {
        self.maplyViewController = MaplyViewController(mapType: .typeFlat)
        self.bubble.addSubview(self.maplyViewController!.view)
        self.maplyViewController!.view.frame = self.bubble.bounds
        // TODO: look into this
        //self.addChild(self.maplyViewController!)
    }

    private static func getMaplyLayer() -> MaplyQuadImageTilesLayer? {
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
        if let layer = MessageCellLocationSharing.getMaplyLayer() {
            layer.handleEdges = false
            layer.coverPoles = false
            layer.requireElev = false
            layer.waitLoad = false
            layer.drawPriority = 0
            layer.singleLevelLoading = false
            self.maplyViewController!.add(layer)
        }

        if let mapViewC = self.maplyViewController as? MaplyViewController {
            mapViewC.panGesture = false
            mapViewC.pinchGesture = false
            mapViewC.rotateGesture = false
            mapViewC.twoFingerTapGesture = false
            mapViewC.doubleTapDragGesture = false
            mapViewC.doubleTapZoomGesture = false

            mapViewC.height = 0.0005
        }
    }

    // For children
    func updateLocationAndMarker(location: CLLocationCoordinate2D,
                                 imageData: Data?,
                                 marker: MaplyScreenMarker,
                                 markerDump: MaplyComponentObject?) -> MaplyComponentObject? {
        // only the first time
        if markerDump != nil {
            if let imageData = imageData, let circledImage = UIImage(data: imageData)?.circleMasked {
                marker.image = circledImage
            } else {
                marker.image = UIImage(asset: Asset.fallbackAvatar)!
            }
             marker.size = CGSize(width: 32, height: 32)
        }

        let maplyCoordonate = MaplyCoordinateMakeWithDegrees(Float(location.longitude), Float(location.latitude))

        marker.loc.x = maplyCoordonate.x
        marker.loc.y = maplyCoordonate.y

        var dumpToReturn: MaplyComponentObject?

        if let mapViewC = self.maplyViewController as? MaplyViewController {
            if markerDump != nil {
                self.maplyViewController!.remove(markerDump!)
            }
            dumpToReturn = self.maplyViewController!.addScreenMarkers([marker], desc: nil)

            mapViewC.animate(toPosition: maplyCoordonate, time: 0.1)
        }
        return dumpToReturn
    }
}
