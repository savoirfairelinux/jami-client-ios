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

/// Codec/sink state used to validate asynchronous quality evaluations.
/// Every mutation advances `generation`; a candidate created before a later
/// mutation cannot reserve a camera downgrade.
struct VideoDowngradeState {
    struct Candidate: Equatable, Sendable {
        let sink: SinkId
        fileprivate let generation: UInt64
    }

    private(set) var currentDeviceId: String
    private var codecByCallId: [String: String] = [:]
    private var decodingSinks: Set<SinkId> = []
    private var generation: UInt64 = 0

    init(currentDeviceId: String = "") {
        self.currentDeviceId = currentDeviceId
    }

    @discardableResult
    mutating func setCodec(_ codec: String?, forCallId callId: String) -> [Candidate] {
        generation &+= 1
        guard let codec = codec, !codec.isEmpty else {
            codecByCallId[callId] = nil
            return candidatesForCurrentState()
        }
        codecByCallId[callId] = codec
        return candidatesForCurrentState()
    }

    mutating func decodingStarted(_ sink: SinkId) -> [Candidate] {
        generation &+= 1
        decodingSinks.insert(sink)
        return candidatesForCurrentState()
    }

    @discardableResult
    mutating func decodingStopped(_ sink: SinkId) -> [Candidate] {
        generation &+= 1
        decodingSinks.remove(sink)
        return candidatesForCurrentState()
    }

    mutating func setCurrentDevice(_ identifier: String) {
        generation &+= 1
        currentDeviceId = identifier
    }

    mutating func reserveDowngrade(_ candidate: Candidate,
                                   cameraQuality: AVCaptureSession.Preset) -> Bool {
        guard candidate.generation == generation,
              cameraQuality == .high,
              currentDeviceId != CameraDevice.medium,
              decodingSinks.contains(candidate.sink),
              let codec = codecByCallId[candidate.sink.baseId],
              Self.isSoftwareEncoded(codec) else { return false }
        currentDeviceId = CameraDevice.medium
        return true
    }

    private static func isSoftwareEncoded(_ codec: String) -> Bool {
        return codec != "H264" && codec != "H265"
    }

    private func candidatesForCurrentState() -> [Candidate] {
        return decodingSinks.compactMap { sink in
            guard let codec = codecByCallId[sink.baseId],
                  Self.isSoftwareEncoded(codec) else { return nil }
            return Candidate(sink: sink, generation: generation)
        }
    }
}

/// Coordinates the video path: camera capture toward libjami, decoded
/// sinks toward renderers, hardware-acceleration setup
final class VideoPipeline: NSObject {

    let capturer = CameraCapturer()
    let sinkRegistry = VideoSinkRegistry()
    private let video: LibJamiVideoAPI

    let localFrames = FrameDistributor(sinkId: SinkId(raw: "local"))
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
    private var downgradeState = VideoDowngradeState()

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
        return locked { Self.cameraSourceURI(from: downgradeState.currentDeviceId) }
    }

    private func setCurrentDeviceId(_ identifier: String) {
        locked { downgradeState.setCurrentDevice(identifier) }
    }

    func setVideoCodec(_ codec: String?, forCallId callId: String) {
        let candidates = locked { downgradeState.setCodec(codec, forCallId: callId) }
        candidates.forEach(evaluateCaptureDowngrade)
    }

    private func evaluateCaptureDowngrade(_ candidate: VideoDowngradeState.Candidate) {
        Task {
            let quality = await capturer.currentQuality()
            guard locked({ downgradeState.reserveDowngrade(candidate,
                                                            cameraQuality: quality) }) else {
                return
            }
            video.setDefaultDevice(CameraDevice.medium)
            let actualDevice = video.defaultDevice()
            setCurrentDeviceId(actualDevice)
            guard actualDevice == CameraDevice.medium else { return }
            onSourceDowngraded?(candidate.sink,
                                Self.cameraSourceURI(from: CameraDevice.medium))
        }
    }

    static func cameraSourceURI(from source: String) -> String {
        return source.hasPrefix("camera://") ? source : "camera://" + source
    }

    func startPreviewCapture() {
        localFrames.clearCachedFrame()
        let quality: AVCaptureSession.Preset = locked {
            downgradeState.currentDeviceId == CameraDevice.medium ? .medium : .high
        }
        capturer.setPreviewCapture(active: true, quality: quality)
    }

    func stopPreviewCapture() {
        capturer.setPreviewCapture(active: false)
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
                (orientationState.outgoingAngle,
                 Self.cameraSourceURI(from: downgradeState.currentDeviceId))
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
        // Quality and start are one session-queue intent, so a later stop
        // cannot be overtaken by a suspended quality lookup.
        let quality: AVCaptureSession.Preset = device == CameraDevice.medium ? .medium : .high
        capturer.setDaemonCapture(active: true, quality: quality)
    }

    func stopCapture(withDevice device: String) {
        guard !device.isEmpty && device != MediaNegotiator.mutedCameraSource else { return }
        capturer.setDaemonCapture(active: false)
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
        let candidates = locked { downgradeState.decodingStarted(sink) }
        candidates.forEach(evaluateCaptureDowngrade)

        video.registerSink(sink, width: width, height: height,
                           hasListeners: sinkRegistry.hasListeners(sink))
    }

    func decodingStopped(withSinkId sinkId: String) {
        let sink = SinkId(raw: sinkId)
        sinkRegistry.handleDecodingStopped(sinkId: sink)
        let candidates = locked { downgradeState.decodingStopped(sink) }
        candidates.forEach(evaluateCaptureDowngrade)
        video.removeSink(sink)
    }
}
