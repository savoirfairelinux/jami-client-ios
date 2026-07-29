/*
 * Copyright (C) 2018-2026 Savoir-faire Linux Inc.
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
import AVFoundation
import UIKit

/// Coordinates the video path: camera capture toward libjami, decoded
/// sinks toward renderers, hardware-acceleration setup
final class VideoPipeline: NSObject {

    let capturer = CameraCapturer()
    let sinkRegistry = VideoSinkRegistry()
    private let video: LibJamiVideoAPI

    let localFrames = FrameDistributor(source: .localCamera)
    /// Transform preview layers must apply to local frames (orientation
    /// + front-camera mirroring), updated on rotation/camera switch.
    var localLayerTransform: CGAffineTransform { locked { orientationState.layerTransform } }
    var localImageOrientation: UIImage.Orientation { locked { orientationState.imageOrientation } }

    /// Asks the call layer to re-invite with a new video source after a
    /// quality downgrade
    var onSourceDowngraded: ((SinkId, String) -> Void)?
    /// libjami media player reported a file opened (media messages).
    var onFileOpened: ((String, [String: String]) -> Void)?

    private let stateLock = NSLock()
    private var orientationState = CameraOrientationState.make(orientation: .portrait,
                                                               cameraPosition: .front)
    private var currentDeviceId = ""
    private var codecByCallId: [String: String] = [:]
    private var decodingSinks: Set<SinkId> = []

    private func locked<T>(_ body: () -> T) -> T {
        stateLock.lock()
        defer { stateLock.unlock() }
        return body()
    }

    init(video: LibJamiVideoAPI) {
        self.video = video
        super.init()

        capturer.onFrame = { [weak self] imageBuffer, sampleBuffer in
            self?.handleCapturedFrame(imageBuffer: imageBuffer, sampleBuffer: sampleBuffer)
        }
        capturer.onPositionChanged = { [weak self] position in
            guard let self = self else { return }
            self.locked {
                self.orientationState = .make(orientation: self.orientationState.orientation,
                                              cameraPosition: position)
            }
        }
        sinkRegistry.onListenersChanged = { [weak self] sinkId, hasListeners in
            self?.video.setHasListeners(hasListeners, sinkId: sinkId)
        }
    }

    func attachToAdapter() {
        VideoAdapter.videoDelegate = self
        VideoAdapter.decodingDelegate = self
    }

    // MARK: - Device setup

    /// Requests camera permission and registers our capture devices with
    /// libjami (medium + high presets of the front camera), then
    /// applies the stored hardware-acceleration preference.
    func setupDevices() {
        Task {
            guard await capturer.ensurePermission() else { return }
            do {
                try await capturer.configure()
                let high = try await capturer.deviceInfo(quality: .high)
                let medium = try await capturer.deviceInfo(quality: .medium)
                video.addVideoDevice(name: CameraDevice.medium, info: medium)
                video.addVideoDevice(name: CameraDevice.high, info: high)
                applyStoredAccelerationPreference()
                setCurrentDeviceId(video.defaultDevice())
            } catch {
                NSLog("VideoPipeline: device setup failed: %@", error.localizedDescription)
            }
        }
    }

    /// Hardware acceleration defaults to on unless the user disabled it.
    private func applyStoredAccelerationPreference() {
        let keyExists = UserDefaults.standard.object(forKey: hardareAccelerationKey) != nil
        let enable = keyExists ? UserDefaults.standard.bool(forKey: hardareAccelerationKey) : true
        setHardwareAccelerated(enable)
    }

    func setHardwareAccelerated(_ enabled: Bool) {
        video.setDecodingAccelerated(enabled)
        video.setEncodingAccelerated(enabled)
        video.setDefaultDevice(enabled ? CameraDevice.high : CameraDevice.medium)
        setCurrentDeviceId(video.defaultDevice())
    }

    /// After a VP8 call downgraded capture quality, restore the high-
    /// resolution device for the next call.
    func restoreDefaultDevice() {
        if video.encodingAccelerated() && video.defaultDevice() == CameraDevice.medium {
            video.setDefaultDevice(CameraDevice.high)
        }
        setCurrentDeviceId(video.defaultDevice())
    }

    // MARK: - Capture

    /// Current video source URI for media lists ("camera://<device>").
    func videoSource() -> String {
        return locked { Self.cameraSourceURI(from: currentDeviceId) }
    }

    private func setCurrentDeviceId(_ identifier: String) {
        locked { currentDeviceId = identifier }
    }

    func setVideoCodec(_ codec: String?, forCallId callId: String) {
        let sinks: [SinkId] = locked {
            guard let codec = codec, !codec.isEmpty else {
                codecByCallId[callId] = nil
                return []
            }
            codecByCallId[callId] = codec
            return decodingSinks.filter { $0.baseId == callId }
        }
        sinks.forEach(downgradeCaptureIfSoftwareEncoded)
    }

    private func downgradeCaptureIfSoftwareEncoded(_ sink: SinkId) {
        let codec = locked { codecByCallId[sink.baseId] }
        guard let codec = codec, !codec.isEmpty,
              codec != "H264", codec != "H265" else { return }
        Task {
            guard await capturer.currentQuality() == .high else { return }
            video.setDefaultDevice(CameraDevice.medium)
            setCurrentDeviceId(video.defaultDevice())
            onSourceDowngraded?(sink, Self.cameraSourceURI(from: CameraDevice.medium))
        }
    }

    static func cameraSourceURI(from source: String) -> String {
        return source.hasPrefix("camera://") ? source : "camera://" + source
    }

    func startPreviewCapture() {
        localFrames.clearCachedFrame()
        capturer.start()
    }

    func stopPreviewCapture() {
        capturer.stop()
        localFrames.clearCachedFrame()
    }

    /// Switches the capture device. On return the local preview transform
    /// (`localLayerTransform`/`localImageOrientation`) has already been
    /// recomputed for the new camera position, so callers can refresh any
    /// cached transform (e.g. the canvas preview tile) immediately after.
    func switchCamera() async {
        do {
            _ = try await capturer.switchCamera()
        } catch {
            NSLog("VideoPipeline: camera switch failed: %@", error.localizedDescription)
        }
    }

    func resetCameraPosition() async {
        await capturer.resetToFrontCamera()
    }

    @discardableResult
    func setOrientation(_ input: DeviceOrientationInput) -> Bool {
        guard let orientation = AVCaptureVideoOrientation.resolve(input) else { return false }
        return locked {
            guard orientation != orientationState.orientation else { return false }
            orientationState = .make(orientation: orientation,
                                     cameraPosition: orientationState.cameraPosition)
            return true
        }
    }

    private func handleCapturedFrame(imageBuffer: CVImageBuffer?, sampleBuffer: CMSampleBuffer) {
        sampleBuffer.markForImmediateDisplay()
        localFrames.distribute(VideoFrame(sampleBuffer: sampleBuffer, rotation: 0))
        if let imageBuffer = imageBuffer {
            let (angle, source) = locked {
                (orientationState.outgoingAngle, Self.cameraSourceURI(from: currentDeviceId))
            }
            video.writeOutgoingFrame(imageBuffer, angle: angle, videoInputId: source)
        }
    }

    // MARK: - Local recorder / player passthroughs (media messages)

    func startLocalRecorder(audioOnly: Bool, path: String) -> String? {
        let input = audioOnly ? "" : Self.cameraSourceURI(from: CameraDevice.medium)
        return video.startLocalRecording(videoInputId: input, path: path)
    }

    func stopLocalRecorder(path: String) {
        video.stopLocalRecording(path: path)
    }

    func openMediumCameraInput() {
        video.openVideoInput(Self.cameraSourceURI(from: CameraDevice.medium))
    }

    func closeMediumCameraInput() {
        video.closeVideoInput(Self.cameraSourceURI(from: CameraDevice.medium))
    }

    func createPlayer(path: String) -> String? {
        return video.createMediaPlayer(path: path)
    }

    func pausePlayer(playerId: String, pause: Bool) {
        video.pausePlayer(playerId: playerId, pause: pause)
    }

    func closePlayer(playerId: String) {
        video.closePlayer(playerId: playerId)
    }

    func mutePlayerAudio(playerId: String, mute: Bool) {
        video.mutePlayerAudio(playerId: playerId, mute: mute)
    }

    func seekPlayer(to time: Int, playerId: String) {
        video.playerSeek(to: time, playerId: playerId)
    }

    func playerPosition(playerId: String) -> Int64 {
        return video.playerPosition(playerId: playerId)
    }
}

// MARK: - VideoAdapterDelegate (libjami → capture control)

extension VideoPipeline: VideoAdapterDelegate {

    func startCapture(withDevice device: String) {
        Task {
            // The libjami names the device it wants; adjust preset quality.
            let quality = await capturer.currentQuality()
            if device == CameraDevice.high && quality == .medium {
                capturer.setQuality(.high)
            } else if device == CameraDevice.medium && quality == .high {
                capturer.setQuality(.medium)
            }
            capturer.start()
        }
    }

    func stopCapture(withDevice device: String) {
        guard !device.isEmpty && device != MediaNegotiator.mutedCameraSource else { return }
        capturer.stop()
    }

    func setDecodingAccelerated(withState state: Bool) {
        video.setDecodingAccelerated(state)
    }

    func fileOpened(for playerId: String, fileInfo: [String: String]) {
        onFileOpened?(playerId, fileInfo)
    }

    func writeFrame(withBuffer buffer: CVPixelBuffer?, sinkId: String, rotation: Int) {
        sinkRegistry.handleFrame(buffer: buffer, sinkId: SinkId(raw: sinkId),
                                 rotation: rotation)
    }
}

// MARK: - DecodingAdapterDelegate (libjami → sinks)

extension VideoPipeline: DecodingAdapterDelegate {

    func decodingStarted(withSinkId sinkId: String, withWidth width: Int, withHeight height: Int) {
        let sink = SinkId(raw: sinkId)
        sinkRegistry.handleDecodingStarted(sinkId: sink)
        locked { _ = decodingSinks.insert(sink) }
        downgradeCaptureIfSoftwareEncoded(sink)

        video.registerSink(sink, width: width, height: height,
                           hasListeners: sinkRegistry.hasListeners(sink))
        publishListenerState(for: sink)
    }

    private func publishListenerState(for sink: SinkId) {
        video.setHasListeners(sinkRegistry.hasListeners(sink), sinkId: sink)
    }

    func decodingStopped(withSinkId sinkId: String) {
        let sink = SinkId(raw: sinkId)
        sinkRegistry.handleDecodingStopped(sinkId: sink)
        locked { decodingSinks.remove(sink) }
        video.removeSink(sink)
    }
}
