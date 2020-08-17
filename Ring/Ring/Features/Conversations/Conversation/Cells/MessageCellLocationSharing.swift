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

class MessageCellLocationSharing: MessageCell {

    typealias MarkerAndComponentObject = (marker: MaplyScreenMarker, componentObject: MaplyComponentObject?)

    private static let osmCopyrightAndLicenseURL = "https://www.openstreetmap.org/copyright"
    private static let remoteTileSourceBaseUrl = MessageCellLocationSharing.getBaseURL()

    @IBOutlet weak var locationSharingMessageTextView: UITextView!
    @IBOutlet weak var bubbleHeight: NSLayoutConstraint!

    var xButton: UIButton?
    var myPositionButton: UIButton?

    let locationTapped = BehaviorRelay<(Bool, Bool)>(value: (false, false)) // (shouldAnimate, expanding)

    var maplyViewController: MaplyBaseViewController? // protected in Swift?
    /// The usage of this variable allows for the view to not be refreshed on reuse (e.g. when scrolling)
    private var preventUnnecessaryReuseCounter = 0

    override func willRemoveSubview(_ subview: UIView) {
        super.willRemoveSubview(subview)
        self.preventUnnecessaryReuseCounter = 0
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        NotificationCenter.default.addObserver(self, selector: #selector(shrink), name: UIResponder.keyboardWillShowNotification, object: nil)
    }

    override func configureFromItem(_ conversationViewModel: ConversationViewModel, _ items: [MessageViewModel]?, cellForRowAt indexPath: IndexPath) {
        super.configureFromItem(conversationViewModel, items, cellForRowAt: indexPath)

        self.shrink()

        if self.maplyViewController as? MaplyViewController == nil || preventUnnecessaryReuseCounter < 2 {
            self.setupMaply()
            self.displayMapTile()

            self.configureTapGesture()
            self.setupOSMCopyrightButton()
            let name = (conversationViewModel.displayName.value != nil && !conversationViewModel.displayName.value!.isEmpty) ?
                conversationViewModel.displayName.value! : conversationViewModel.userName.value
            self.setUplocationSharingMessageTextView(username: name)
            preventUnnecessaryReuseCounter += 1
        }
    }

    func setUplocationSharingMessageTextView(username: String) {
        self.locationSharingMessageTextView.isEditable = false
        self.locationSharingMessageTextView.textColor = UIColor.jamiTextBlue
        self.locationSharingMessageTextView.backgroundColor = UIColor.jamiBackgroundColor.withAlphaComponent(0.75)
        self.bubble.addSubview(self.locationSharingMessageTextView)
    }

    override func configureTapGesture() {
        self.bubble.isUserInteractionEnabled = true
        self.tapGestureRecognizer = UITapGestureRecognizer()
        self.tapGestureRecognizer!.rx.event.bind(onNext: { [weak self] _ in self?.onTapGesture() }).disposed(by: self.disposeBag)
        self.bubble.addGestureRecognizer(tapGestureRecognizer!)
    }

    override func onTapGesture() {
        if !locationTapped.value.1 {
            self.expandOrShrink()
        }
    }

    private func removeTapDefaultGestureFromMaply() {
        if let whirlyKitEAGLView = (self.maplyViewController as? MaplyViewController)?.view.subviews[0],
           let gesture = whirlyKitEAGLView.gestureRecognizers?.first(where: { (gesture) -> Bool in gesture is UITapGestureRecognizer }) {
            whirlyKitEAGLView.removeGestureRecognizer(gesture)
        }
    }

    private func setupMaply() {
        self.maplyViewController?.view.removeFromSuperview()

        self.maplyViewController = MaplyViewController(mapType: .typeFlat)
        self.removeTapDefaultGestureFromMaply()

        self.bubble.addSubview(self.maplyViewController!.view)
        self.maplyViewController!.view.frame = self.bubble.bounds
    }

    private func displayMapTile() {
        self.maplyViewController!.clearColor = UIColor.white

        // thirty fps if we can get it
        self.maplyViewController!.frameInterval = 2

        if let layer = MessageCellLocationSharing.getMaplyLayer() {
            layer.handleEdges = false
            layer.coverPoles = false
            layer.requireElev = false
            layer.waitLoad = false
            layer.drawPriority = 0
            layer.singleLevelLoading = false
            self.maplyViewController!.add(layer)
        } else {
            self.log.error("[MessageCellLocationSharing] Could not get the layer")
        }

        if let mapViewC = self.maplyViewController as? MaplyViewController {
            self.toggleMaplyGesture(false)
            mapViewC.height = 0.0001
        }
    }

    private func toggleMaplyGesture(_ value: Bool) {
        if let mapViewC = self.maplyViewController as? MaplyViewController {
            mapViewC.panGesture = value
            mapViewC.pinchGesture = value
            mapViewC.rotateGesture = value
            mapViewC.twoFingerTapGesture = value
            mapViewC.doubleTapDragGesture = value
            mapViewC.doubleTapZoomGesture = value
        }
    }

    private static func getMaplyLayer() -> MaplyQuadImageTilesLayer? {
        let layer: MaplyQuadImageTilesLayer

        // Because this is a remote tile set, we'll want a cache directory
        let baseCacheDir = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0]
        let tilesCacheDir = "\(baseCacheDir)/openstreetmap/"
        let maxZoom = Int32(19)

        guard let tileSource =
            MaplyRemoteTileSource(baseURL: MessageCellLocationSharing.remoteTileSourceBaseUrl,
                                  ext: "png",
                                  minZoom: 0,
                                  maxZoom: maxZoom) else { return nil }
        tileSource.cacheDir = tilesCacheDir
        layer = MaplyQuadImageTilesLayer(tileSource: tileSource)!

        return layer
    }

    private static func getBaseURL() -> String {
        // OpenStreetMap Tiles, © OpenStreetMap contributors
        let urls = ["https://a.tile.openstreetmap.org/",
                    "https://b.tile.openstreetmap.org/",
                    "https://c.tile.openstreetmap.org/"]
        let rngIndex = Int.random(in: 0 ..< 3)

        return urls[rngIndex]
    }
}

// For children
extension MessageCellLocationSharing {
    func updateLocationAndMarker(location: CLLocationCoordinate2D,
                                 imageData: Data?,
                                 username: String?,
                                 marker: MaplyScreenMarker,
                                 markerDump: MaplyComponentObject?,
                                 tryToAnimateToMarker: Bool = true) -> MaplyComponentObject? {
        // only the first time
        if markerDump == nil {
            marker.layoutImportance = MAXFLOAT
            if let imageData = imageData, let circledImage = UIImage(data: imageData)?.circleMasked {
                marker.image = circledImage
            } else {
                marker.image = AvatarView(profileImageData: nil, username: username ?? "", size: 24).convertToImage()
            }
             marker.size = CGSize(width: 24, height: 24)
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

            if tryToAnimateToMarker && !locationTapped.value.1 {
                mapViewC.animate(toPosition: maplyCoordonate, time: 0.1)
            }
        }
        return dumpToReturn
    }
}

// For OSM Copyrights
extension MessageCellLocationSharing {
    private func setupOSMCopyrightButton() {
        let infoButton = UIButton(type: .detailDisclosure)
        infoButton.backgroundColor = UIColor.init(white: 0.75, alpha: 0.25)
        infoButton.cornerRadius = infoButton.frame.height / 2.0
        self.bubble.addSubview(infoButton)

        infoButton.translatesAutoresizingMaskIntoConstraints = false
        let constraintX = NSLayoutConstraint(item: infoButton,
                                             attribute: NSLayoutConstraint.Attribute.centerX,
                                             relatedBy: NSLayoutConstraint.Relation.equal,
                                             toItem: self.bubble,
                                             attribute: NSLayoutConstraint.Attribute.right,
                                             multiplier: 1,
                                             constant: -28)
        let constraintY = NSLayoutConstraint(item: infoButton,
                                             attribute: NSLayoutConstraint.Attribute.centerY,
                                             relatedBy: NSLayoutConstraint.Relation.equal,
                                             toItem: self.bubble,
                                             attribute: NSLayoutConstraint.Attribute.bottom,
                                             multiplier: 1,
                                             constant: -28)
        NSLayoutConstraint.activate([constraintX, constraintY])
        infoButton.addTarget(self, action: #selector(buttonAction), for: .touchUpInside)
    }

    @objc
    func buttonAction(sender: UIButton!) {
        let alert = UIAlertController.init(title: L10n.Alerts.mapInformation,
                                           message: L10n.Alerts.openStreetMapCopyright,
                                           preferredStyle: .alert)
        alert.addAction(.init(title: L10n.Alerts.openStreetMapCopyrightMoreInfo, style: UIAlertAction.Style.default, handler: { (_) in
            if let url = URL(string: MessageCellLocationSharing.osmCopyrightAndLicenseURL), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, completionHandler: nil)
            }
        }))
        alert.addAction(.init(title: L10n.Global.ok, style: UIAlertAction.Style.cancel))

        self.window?.rootViewController?.present(alert, animated: true, completion: nil)
    }
}

// For bigger map
extension MessageCellLocationSharing {
    @objc
    private func shrink() {
        if self.bubbleHeight.constant > 220 {
            self.expandOrShrink()
        }
    }

    private func expandOrShrink() {
        let shouldExpand = !self.locationTapped.value.1

        self.updateHeight(shouldExpand)
        //self.updateWidth(shouldExpand) now in controller, for animation
        self.toggleMaplyGesture(shouldExpand)

        if shouldExpand {
            self.setupXButton()
            self.setupMyPositionButton()
        } else {
            self.removeXButton()
            self.removeMyPositionButton()
        }

        self.locationTapped.accept((true, shouldExpand))
    }

    private func updateHeight(_ shouldExpand: Bool, extendedHeight: CGFloat = 350) {
        let normalHeight: CGFloat = 220
        if shouldExpand {
            self.bubbleHeight.constant = extendedHeight
        } else {
            self.bubbleHeight.constant = normalHeight
        }
    }

    @objc
    func updateWidth(_ shouldExpand: Bool) {
        fatalError("Must override this function")
    }

    func expandHeight(_ shouldExpand: Bool, _ height: CGFloat) {
        if shouldExpand {
            let percentage: CGFloat = self.hasTopNotch() ? 0.88 : 0.91

            self.updateHeight(shouldExpand,
                              extendedHeight: (height * percentage) - self.bubbleTopConstraint.constant)
        }
    }

    func hasTopNotch() -> Bool {
        if #available(iOS 13.0, *) {
            return UIApplication.shared.windows.filter { $0.isKeyWindow }.first?.safeAreaInsets.top ?? 0 > 20
        } else {
            return UIApplication.shared.delegate?.window??.safeAreaInsets.top ?? 0 > 20
        }
    }
}

extension MessageCellLocationSharing {
    private func setupXButton() {
        self.setUpLocationSharingMessageTextViewInset(expanding: true)

        self.xButton = UIButton()
        let xButton = self.xButton!
        xButton.setBackgroundImage(UIImage(asset: Asset.closeIcon)!, for: UIControl.State.normal)
        xButton.tintColor = UIColor.jamiTextBlue
        self.bubble.addSubview(xButton)

        xButton.translatesAutoresizingMaskIntoConstraints = false
        let constraintX = NSLayoutConstraint(item: xButton,
                                             attribute: NSLayoutConstraint.Attribute.centerX,
                                             relatedBy: NSLayoutConstraint.Relation.equal,
                                             toItem: self.bubble,
                                             attribute: NSLayoutConstraint.Attribute.left,
                                             multiplier: 1,
                                             constant: 24)
        let constraintY = NSLayoutConstraint(item: xButton,
                                             attribute: NSLayoutConstraint.Attribute.centerY,
                                             relatedBy: NSLayoutConstraint.Relation.equal,
                                             toItem: self.bubble,
                                             attribute: NSLayoutConstraint.Attribute.top,
                                             multiplier: 1,
                                             constant: 24)
        let height = NSLayoutConstraint(item: xButton,
                                        attribute: NSLayoutConstraint.Attribute.height,
                                        relatedBy: NSLayoutConstraint.Relation.equal,
                                        toItem: nil,
                                        attribute: NSLayoutConstraint.Attribute.notAnAttribute,
                                        multiplier: 1,
                                        constant: 32)
        let width = NSLayoutConstraint(item: xButton,
                                       attribute: NSLayoutConstraint.Attribute.width,
                                       relatedBy: NSLayoutConstraint.Relation.equal,
                                       toItem: nil,
                                       attribute: NSLayoutConstraint.Attribute.notAnAttribute,
                                       multiplier: 1,
                                       constant: 32)
        NSLayoutConstraint.activate([constraintX, constraintY, height, width])
        xButton.addTarget(self, action: #selector(XButtonAction), for: .touchUpInside)
    }

    private func removeXButton() {
        self.setUpLocationSharingMessageTextViewInset(expanding: false)

        self.xButton?.removeFromSuperview()
        self.xButton = nil
    }

    @objc
    func XButtonAction(sender: UIButton!) {
        self.expandOrShrink()
    }

    func setUpLocationSharingMessageTextViewInset(expanding: Bool) {
        if expanding {
            self.locationSharingMessageTextView.textContainerInset.left = 48
            self.locationSharingMessageTextView.textAlignment = .left
        } else {
            self.locationSharingMessageTextView.textContainerInset.left = self.locationSharingMessageTextView.textContainerInset.right
            self.locationSharingMessageTextView.textAlignment = .center
        }
    }

    func onAnimationCompletion() {
        self.locationSharingMessageTextView.adjustHeightFromContentSize(minHeight: 48)
    }
}

extension MessageCellLocationSharing {
    private func setupMyPositionButton() {
        if self as? MessageCellLocationSharingSent != nil {
            self.myPositionButton = UIButton()
            let myLocation = self.myPositionButton!
            myLocation.setImage(UIImage(asset: Asset.myLocation)!, for: .normal)
            myLocation.tintColor = UIColor.jamiTextBlue
            myLocation.backgroundColor = UIColor.jamiBackgroundColor.withAlphaComponent(0.75)
            myLocation.cornerRadius = 16
            self.bubble.addSubview(myLocation)

            myLocation.translatesAutoresizingMaskIntoConstraints = false
            let constraintX = NSLayoutConstraint(item: myLocation,
                                                 attribute: NSLayoutConstraint.Attribute.centerX,
                                                 relatedBy: NSLayoutConstraint.Relation.equal,
                                                 toItem: self.bubble,
                                                 attribute: NSLayoutConstraint.Attribute.right,
                                                 multiplier: 1,
                                                 constant: -28)
            let constraintY = NSLayoutConstraint(item: myLocation,
                                                 attribute: NSLayoutConstraint.Attribute.centerY,
                                                 relatedBy: NSLayoutConstraint.Relation.equal,
                                                 toItem: self.bubble,
                                                 attribute: NSLayoutConstraint.Attribute.bottom,
                                                 multiplier: 1,
                                                 constant: -70)
            let height = NSLayoutConstraint(item: myLocation,
                                            attribute: NSLayoutConstraint.Attribute.height,
                                            relatedBy: NSLayoutConstraint.Relation.equal,
                                            toItem: nil,
                                            attribute: NSLayoutConstraint.Attribute.notAnAttribute,
                                            multiplier: 1,
                                            constant: 32)
            let width = NSLayoutConstraint(item: myLocation,
                                           attribute: NSLayoutConstraint.Attribute.width,
                                           relatedBy: NSLayoutConstraint.Relation.equal,
                                           toItem: nil,
                                           attribute: NSLayoutConstraint.Attribute.notAnAttribute,
                                           multiplier: 1,
                                           constant: 32)
            NSLayoutConstraint.activate([constraintX, constraintY, height, width])
            myLocation.addTarget(self, action: #selector(myPositionButtonAction), for: .touchUpInside)
        }
    }

    private func removeMyPositionButton() {
        self.myPositionButton?.removeFromSuperview()
        self.myPositionButton = nil
    }

    @objc
    func myPositionButtonAction(sender: UIButton!) {
        fatalError("Must override this function")
    }
}
