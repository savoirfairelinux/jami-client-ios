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

struct OpenedMediaFile {
    let path: String
    let preview: MediaPreview
}

enum MediaPlayerError: Error {
    case unavailable
}

/// Camera, media-player and recorder surface over libjami's video API.
/// Owns the video pipeline and stands alone: calls, media messages, the file
/// player and settings are all consumers.
final class VideoService {

    static let thumbnailMaxPixelSize = 1024
    static let temporaryThumbnailDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("media_previews")

    let pipeline: VideoPipeline

    private var localSubscription: FrameSubscription?
    private let playerQueue: DispatchQueue
    private let previewQueue = DispatchQueue(label: "com.savoirfairelinux.jami.mediaPreview")
    private let previewCache: MediaPreviewCache?
    private lazy var thumbnailContext = CIContext()

    convenience init(videoAdapter: VideoAdapter = VideoAdapter()) {
        self.init(video: LibJamiVideoClient(adapter: videoAdapter))
        attachToAdapter()
    }

    init(video: LibJamiVideoAPI,
         playerQueue: DispatchQueue = DispatchQueue(label: "com.savoirfairelinux.jami.mediaPlayer", qos: .userInitiated),
         previewCache: MediaPreviewCache? = MediaPreviewCache.standard) {
        let pipeline = VideoPipeline(video: video)
        self.pipeline = pipeline
        self.playerQueue = playerQueue
        self.previewCache = previewCache

        pipeline.onFileOpened = { [weak self] path, info in
            self?.fileOpened.onNext(OpenedMediaFile(path: path, preview: MediaPreview(libJamiInfo: info)))
        }
        previewQueue.async {
            try? FileManager.default.removeItem(at: Self.temporaryThumbnailDirectory)
        }
    }

    // MARK: - Streams

    let capturedVideoFrame = PublishSubject<LocalFrameInfo?>()
    let fileOpened = PublishSubject<OpenedMediaFile>()

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

    func openPlayer(path: String) -> Single<String> {
        let pipeline = self.pipeline
        let queue = playerQueue
        return Single.create { observer in
            queue.async {
                let playerId = pipeline.createPlayer(path: path)
                DispatchQueue.main.async {
                    if let playerId = playerId {
                        observer(.success(playerId))
                    } else {
                        observer(.failure(MediaPlayerError.unavailable))
                    }
                }
            }
            return Disposables.create()
        }
    }

    func playerFrames(playerId: String) -> FrameDistributor {
        return pipeline.sinkRegistry.distributor(for: SinkId(raw: playerId))
    }

    func pausePlayer(playerId: String, pause: Bool) {
        let pipeline = self.pipeline
        playerQueue.async { pipeline.pausePlayer(playerId: playerId, pause: pause) }
    }

    func closePlayer(playerId: String) {
        playerFrames(playerId: playerId).clearCachedFrame()
        let pipeline = self.pipeline
        playerQueue.async { pipeline.closePlayer(playerId: playerId) }
    }

    func mutePlayerAudio(playerId: String, mute: Bool) {
        let pipeline = self.pipeline
        playerQueue.async { pipeline.mutePlayerAudio(playerId: playerId, mute: mute) }
    }

    func seekPlayer(playerId: String, to time: Int64) {
        let pipeline = self.pipeline
        playerQueue.async { pipeline.seekPlayer(to: Int(time), playerId: playerId) }
    }

    func getPlayerPosition(playerId: String) -> Int64 {
        return pipeline.playerPosition(playerId: playerId)
    }

    // MARK: - Media preview

    func mediaPreview(for fileURL: URL, in scope: MediaPreviewScope?) -> Single<MediaPreview> {
        return Single.create { [weak self] observer in
            let request = BooleanDisposable()
            self?.previewQueue.async {
                guard !request.isDisposed, let preview = self?.resolvePreview(for: fileURL, in: scope) else { return }
                DispatchQueue.main.async { observer(.success(preview)) }
            }
            return request
        }
    }

    private func resolvePreview(for fileURL: URL, in scope: MediaPreviewScope?) -> MediaPreview {
        if let scope = scope, let stored = previewCache?.load(for: fileURL, in: scope) {
            return stored
        }
        let result = pipeline.mediaPreview(path: fileURL.path)
        guard let pixelBuffer = result.pixelBuffer else {
            return store(MediaPreview(libJamiInfo: result.info), for: fileURL, in: scope)
        }
        let image = CIImage(cvPixelBuffer: pixelBuffer).oriented(result.orientation)
        let size = image.extent.size
        let thumbnail = jpegThumbnail(of: image).flatMap { data in
            scope.flatMap { previewCache?.storeThumbnail(data, for: fileURL, in: $0) }
                ?? temporaryThumbnail(data)
        }
        return store(MediaPreview(libJamiInfo: result.info, size: size, thumbnailURL: thumbnail),
                     for: fileURL, in: scope)
    }

    private func store(_ preview: MediaPreview, for fileURL: URL, in scope: MediaPreviewScope?) -> MediaPreview {
        if let scope = scope {
            previewCache?.store(preview, for: fileURL, in: scope)
        }
        return preview
    }

    private func jpegThumbnail(of image: CIImage) -> Data? {
        let longest = max(image.extent.width, image.extent.height)
        guard longest > 0 else { return nil }
        let scale = min(1, CGFloat(Self.thumbnailMaxPixelSize) / longest)
        let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        return thumbnailContext.jpegRepresentation(of: scaled, colorSpace: colorSpace,
                                                   options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.8])
    }

    private func temporaryThumbnail(_ data: Data) -> URL? {
        let directory = Self.temporaryThumbnailDirectory
        let url = directory.appendingPathComponent(UUID().uuidString + ".jpg")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
