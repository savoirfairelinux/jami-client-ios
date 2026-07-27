/*
 * Copyright (C) 2017-2026 Savoir-faire Linux Inc.
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
import RxSwift
import RxRelay
import AVFoundation
import UIKit

/// A frame decoded by libjami for a given sink (media player).
struct VideoFrameInfo {
    let sampleBuffer: CMSampleBuffer?
    let rotation: Int
    let sinkId: String
}

/// libjami media-player metadata.
struct Player {
    var playerId: String
    var duration: String
    var hasAudio: Bool
    var hasVideo: Bool
}

/// Incoming-frame stream holder for the media player.
class FrameStream {
    var frameSubject = PublishSubject<VideoFrameInfo>()
}

/// Camera, media-player and recorder surface over libjami's video API.
/// Owns the video pipeline and stands alone: calls, media messages, the file
/// player and settings are all consumers.
final class VideoService {

    private let pipeline: VideoPipeline

    private var localSubscription: FrameSubscription?
    private var playerSinkSubscriptions: [String: FrameSubscription] = [:]

    convenience init(videoAdapter: VideoAdapter = VideoAdapter()) {
        self.init(video: LibJamiVideoClient(adapter: videoAdapter))
        attachToAdapter()
    }

    init(video: LibJamiVideoAPI) {
        let pipeline = VideoPipeline(video: video)
        self.pipeline = pipeline

        pipeline.onFileOpened = { [weak self] playerId, info in
            self?.playerInfo.onNext(Player(
                                        playerId: playerId,
                                        duration: info["duration"] ?? "0",
                                        hasAudio: (info["audio_stream"].flatMap(Int.init) ?? -1) >= 0,
                                        hasVideo: (info["video_stream"].flatMap(Int.init) ?? -1) >= 0))
        }
    }

    // MARK: - Streams

    let videoInputManager = FrameStream()
    let capturedVideoFrame = PublishSubject<LocalFrameInfo?>()
    let playerInfo = PublishSubject<Player>()

    // MARK: - libjami wiring

    private func attachToAdapter() {
        pipeline.attachToAdapter()
    }

    /// Codec of a decoding sink, supplied by the calls domain for the
    /// software-encoding quality downgrade.
    func setVideoCodec(_ codec: String?, forCallId callId: String) {
        pipeline.setVideoCodec(codec, forCallId: callId)
    }

    /// Reports that capture dropped to a lower-resolution device and the
    /// call must be re-invited with the new source.
    var onSourceDowngraded: ((SinkId, String) -> Void)? {
        get { pipeline.onSourceDowngraded }
        set { pipeline.onSourceDowngraded = newValue }
    }

    // MARK: - Frame sources

    /// Camera frames, for local preview tiles.
    var localFrames: FrameDistributor { pipeline.localFrames }

    /// Transform a preview layer must apply to local frames.
    var localLayerTransform: CGAffineTransform { pipeline.localLayerTransform }

    /// Decoded frames of one remote sink.
    func distributor(for sinkId: SinkId) -> FrameDistributor {
        return pipeline.sinkRegistry.distributor(for: sinkId)
    }

    // MARK: - Capture

    /// Current camera source URI, for libjami media lists.
    func videoSource() -> String {
        return pipeline.videoSource()
    }

    func startPreviewCapture() {
        pipeline.startPreviewCapture()
    }

    func stopPreviewCapture() {
        pipeline.stopPreviewCapture()
    }

    func resetCameraPosition() async {
        await pipeline.resetCameraPosition()
    }

    /// Restores the high-resolution capture device after a downgraded call.
    func restoreDefaultDevice() {
        pipeline.restoreDefaultDevice()
    }

    // MARK: - Camera (media-message recording UI)

    func setupInputs() {
        pipeline.setupDevices()
        // Feed the record-preview stream from the shared local distributor.
        localSubscription = pipeline.localFrames.subscribe { [weak self] frame in
            guard let self = self, let buffer = frame.sampleBuffer else { return }
            self.capturedVideoFrame.onNext(LocalFrameInfo(
                                            sampleBuffer: buffer,
                                            layerTransform: self.pipeline.localLayerTransform,
                                            imageOrientation: self.pipeline.localImageOrientation))
        }
    }

    func startMediumCamera() {
        pipeline.openMediumCameraInput()
    }

    /// On return the local preview transform has been recomputed for the new
    /// camera, so callers can refresh cached transforms immediately.
    func switchCamera() async {
        await pipeline.switchCamera()
    }

    /// Returns whether anything changed, so callers can refresh preview
    /// transforms only when needed.
    @discardableResult
    func setCameraOrientation(_ input: DeviceOrientationInput) -> Bool {
        return pipeline.setOrientation(input)
    }

    // MARK: - Hardware acceleration

    func setHardwareAccelerated(withState state: Bool) {
        pipeline.setHardwareAccelerated(state)
    }

    // MARK: - Local recorder (media messages)

    func startLocalRecorder(audioOnly: Bool, path: String) -> String? {
        return pipeline.startLocalRecorder(audioOnly: audioOnly, path: path)
    }

    func stopLocalRecorder(path: String) {
        pipeline.stopLocalRecorder(path: path)
    }

    func videRecordingFinished() {
        pipeline.closeMediumCameraInput()
        Task { await pipeline.resetCameraPosition() }
    }

    // MARK: - Media player

    func createPlayer(path: String) -> String {
        guard let playerId = pipeline.createPlayer(path: path) else { return "" }
        // Player video arrives as a decoding sink whose id is the playerId.
        let sink = SinkId(raw: playerId)
        playerSinkSubscriptions[playerId] = pipeline.sinkRegistry
            .distributor(for: sink)
            .subscribe { [weak self] frame in
                self?.videoInputManager.frameSubject.onNext(VideoFrameInfo(
                                                                sampleBuffer: frame.sampleBuffer,
                                                                rotation: frame.rotation,
                                                                sinkId: playerId))
            }
        return playerId
    }

    func pausePlayer(playerId: String, pause: Bool) {
        pipeline.pausePlayer(playerId: playerId, pause: pause)
    }

    func closePlayer(playerId: String) {
        playerSinkSubscriptions[playerId] = nil
        pipeline.closePlayer(playerId: playerId)
    }

    func mutePlayerAudio(playerId: String, mute: Bool) {
        pipeline.mutePlayerAudio(playerId: playerId, mute: mute)
    }

    func seekToTime(time: Int, playerId: String) {
        pipeline.seekPlayer(to: time, playerId: playerId)
    }

    func getPlayerPosition(playerId: String) -> Int64 {
        return pipeline.playerPosition(playerId: playerId)
    }
}
