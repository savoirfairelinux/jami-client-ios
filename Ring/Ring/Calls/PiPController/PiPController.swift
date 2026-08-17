/*
 * Copyright (C) 2022-2026 Savoir-faire Linux Inc.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 */

import Foundation
import AVKit

typealias PiPRestoreCompletion = (Bool) -> Void
typealias PiPRestoreHandler = (@escaping PiPRestoreCompletion) -> Void

protocol PiPControlling: AnyObject {
    var onDidFailToStart: (() -> Void)? { get set }
    var onDidStop: (() -> Void)? { get set }
    var onRestoreRequested: PiPRestoreHandler? { get set }
    var sourceView: PiPSourceLayerView { get }
    var isSupported: Bool { get }

    func start()
    func update(distributor: FrameDistributor?)
    func stop()
}

final class PiPController: NSObject, PiPControlling {

    var onDidFailToStart: (() -> Void)?
    var onDidStop: (() -> Void)?
    var onRestoreRequested: PiPRestoreHandler?

    let sourceView = PiPSourceLayerView()

    private enum StopCause {
        case restore
        case sourceRetired
    }

    private var pipController: AVPictureInPictureController?
    private weak var distributor: FrameDistributor?
    private var stopCause: StopCause?

    var isSupported: Bool {
        AVPictureInPictureController.isPictureInPictureSupported()
    }

    func start() {
        guard let controller = pipController,
              !controller.isPictureInPictureActive else { return }
        controller.startPictureInPicture()
    }

    func update(distributor nextDistributor: FrameDistributor?) {
        guard let nextDistributor = nextDistributor else {
            clearSource()
            stop()
            return
        }
        if distributor !== nextDistributor {
            clearSource()
            distributor = nextDistributor
            sourceView.attach(to: nextDistributor)
        }
        bindController()
    }

    func stop() {
        guard let controller = pipController else { return }
        guard controller.isPictureInPictureActive else {
            pipController = nil
            return
        }
        stopCause = .sourceRetired
        controller.stopPictureInPicture()
    }

    private func clearSource() {
        distributor = nil
        sourceView.attach(to: nil)
        sourceView.clear()
    }

    private func bindController() {
        guard isSupported, pipController == nil else { return }
        let contentSource = AVPictureInPictureController.ContentSource(
            sampleBufferDisplayLayer: sourceView.displayLayer, playbackDelegate: self)
        let controller = AVPictureInPictureController(contentSource: contentSource)
        controller.delegate = self
        controller.requiresLinearPlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        controller.setValue(true, forKey: "controlsStyle")
        pipController = controller
    }
}

// MARK: - AVPictureInPictureControllerDelegate

extension PiPController: AVPictureInPictureControllerDelegate {

    func pictureInPictureControllerDidStartPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController) {
        stopCause = nil
    }

    func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        failedToStartPictureInPictureWithError error: Error) {
        onDidFailToStart?()
    }

    func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler
            completionHandler: @escaping (Bool) -> Void) {
        stopCause = .restore
        guard let onRestoreRequested = onRestoreRequested else {
            completionHandler(false)
            return
        }
        onRestoreRequested(completionHandler)
    }

    func pictureInPictureControllerDidStopPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController) {
        let cause = stopCause
        stopCause = nil
        onDidStop?()
        switch cause {
        case .sourceRetired:
            pipController = nil
            if distributor != nil {
                bindController()
            }
        case .restore:
            break
        case nil:
            onRestoreRequested?({ _ in })
        }
    }
}

// MARK: - AVPictureInPictureSampleBufferPlaybackDelegate

extension PiPController: AVPictureInPictureSampleBufferPlaybackDelegate {

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController,
                                    setPlaying playing: Bool) {}

    func pictureInPictureControllerTimeRangeForPlayback(
        _ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange {
        return CMTimeRange(start: .zero,
                           duration: CMTimeMake(value: 3600 * 24, timescale: 1))
    }

    func pictureInPictureControllerIsPlaybackPaused(
        _ pictureInPictureController: AVPictureInPictureController) -> Bool {
        return false
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController,
                                    didTransitionToRenderSize newRenderSize: CMVideoDimensions) {}

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController,
                                    skipByInterval skipInterval: CMTime,
                                    completion completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}
