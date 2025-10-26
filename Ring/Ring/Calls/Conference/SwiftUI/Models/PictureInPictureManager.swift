/*
 *  Copyright (C) 2023 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
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

protocol PictureInPictureManagerDelegate: AnyObject {
    func reopenCurrentCall()
}

class PictureInPictureManager: NSObject, AVPictureInPictureControllerDelegate {

    var pipController: AVPictureInPictureController! = nil
    let delegate: PictureInPictureManagerDelegate
    private let serialQueue = DispatchQueue(label: "com.jami.pipmanager", qos: .userInitiated)
    private var isRestoring = false

    init(delegate: PictureInPictureManagerDelegate) {
        self.delegate = delegate
    }

    func updatePIP(layer: AVSampleBufferDisplayLayer) {
        if #available(iOS 15.0, *) {
            guard AVPictureInPictureController.isPictureInPictureSupported() else { return }
            let contentSource = AVPictureInPictureController.ContentSource(sampleBufferDisplayLayer: layer, playbackDelegate: self)
            if pipController == nil {
                pipController = AVPictureInPictureController(contentSource: contentSource)
                pipController.delegate = self
                // Set requiresLinearPlayback to true to hide buttons from Picture in Picture except cancel and restoreView
                pipController.requiresLinearPlayback = true
                pipController.canStartPictureInPictureAutomaticallyFromInline = true
                // Hide the overlay text and controls except for the cancel and restore view buttons
                pipController.setValue(true, forKey: "controlsStyle")
            } else {
                pipController.contentSource = contentSource
            }
        }
    }
    func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        serialQueue.async { [weak self] in
            guard let self = self, !self.isRestoring else { return }
            self.isRestoring = true

            DispatchQueue.main.async {
                self.delegate.reopenCurrentCall()
                // Reset the flag after a delay to allow the presentation to complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.isRestoring = false
                }
            }
        }
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController,
                                    restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        pipController.stopPictureInPicture()
        completionHandler(true)
    }

    func callStopped() {
        serialQueue.async { [weak self] in
            guard let self = self else { return }
            if #available(iOS 15.0, *) {
                if self.pipController != nil {
                    DispatchQueue.main.async {
                        self.pipController.stopPictureInPicture()
                        self.pipController = nil
                    }
                }
            }
        }
    }

    func showPiP() {
        serialQueue.async { [weak self] in
            guard let self = self else { return }
            if #available(iOS 15.0, *) {
                if self.pipController != nil {
                    DispatchQueue.main.async {
                        self.pipController.startPictureInPicture()
                    }
                }
            }
        }
    }
}

extension PictureInPictureManager: AVPictureInPictureSampleBufferPlaybackDelegate {

    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {}
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool) {}

    func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange {
        return CMTimeRange(start: .zero, duration: CMTimeMake(value: 3600 * 24, timescale: 1))
    }

    func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool {
        return false
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions) {}

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, skipByInterval skipInterval: CMTime, completion completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}
