/*
 *  Copyright (C) 2018-2019 Savoir-faire Linux Inc.
 *
 *  Author: Andreas Traczyk <andreas.traczyk@savoirfairelinux.com>
 *  Author: Quentin Muret <quentin.muret@savoirfairelinux.com>
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
import RxRelay
import RxSwift
import SwiftyBeaver
import UIKit

// swiftlint:disable identifier_name

typealias DeviceInfo = [String: String]

enum VideoError: Error {
    case getPermissionFailed
    case needPermission
    case selectDeviceFailed
    case setupInputDeviceFailed
    case setupOutputDeviceFailed
    case getConnectionFailed
    case unsupportedParameter
    case startCaptureFailed
    case switchCameraFailed
}

enum VideoCodecs: String {
    case H264
    case H265
    case VP8
    case unknown
}

protocol FrameExtractorDelegate: AnyObject {
    func captured(imageBuffer: CVImageBuffer?, image: UIImage)
    func updateDevicePosition(position: AVCaptureDevice.Position)
}

enum Framerates: CGFloat {
    case high = 30
    case medium = 20
    case low = 15
}

class FrameExtractor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let mediumCamera = "mediumCamera"
    let highResolutionCamera = "1280_720Camera"

    private let log = SwiftyBeaver.self

    var quality = AVCaptureSession.Preset.high
    private let orientation = AVCaptureVideoOrientation.landscapeLeft

    func setQuality(quality: AVCaptureSession.Preset) {
        self.quality = quality
    }

    var getOrientation: AVCaptureVideoOrientation {
        return orientation
    }

    var permissionGranted = BehaviorRelay<Bool>(value: false)

    lazy var permissionGrantedObservable: Observable<Bool> = self.permissionGranted.asObservable()

    private let sessionQueue = DispatchQueue(label: "session queue")
    private let captureSession = AVCaptureSession()
    private let context = CIContext()
    private var systemPressureObservation: NSKeyValueObservation?

    weak var delegate: FrameExtractorDelegate?

    override init() {
        super.init()
    }

    func setFrameRateForDevice(captureDevice: AVCaptureDevice, framerate: CGFloat, useRange: Bool) {
        let ranges = captureDevice.activeFormat.videoSupportedFrameRateRanges as [AVFrameRateRange]
        var maxFrameRate = framerate
        var minFrameRate = framerate

        for range in ranges {
            if range.maxFrameRate >= framerate && range.minFrameRate <= framerate {
                if useRange {
                    maxFrameRate = range.maxFrameRate
                    minFrameRate = range.minFrameRate
                }

                let newMinFrameDuration = CMTimeMake(value: 1, timescale: Int32(minFrameRate))
                let newMaxFrameDuration = CMTimeMake(value: 1, timescale: Int32(maxFrameRate))
                if captureDevice.activeVideoMinFrameDuration == newMinFrameDuration &&
                    captureDevice.activeVideoMaxFrameDuration == newMaxFrameDuration {
                    return
                }

                do {
                    try captureDevice.lockForConfiguration()
                    captureDevice.activeVideoMinFrameDuration = newMinFrameDuration
                    captureDevice.activeVideoMaxFrameDuration = newMaxFrameDuration
                    captureDevice.unlockForConfiguration()
                } catch {
                    print("Could not lock device for configuration: \(error)")
                }
                return
            }
        }
    }

    func observeSystemPressureChanges(captureDevice: AVCaptureDevice) {
        // Restore normal framerate.
        setFrameRateForDevice(
            captureDevice: captureDevice,
            framerate: Framerates.high.rawValue,
            useRange: true
        )

        // Observe system pressure.
        systemPressureObservation = captureDevice.observe(\.systemPressureState, options: .new) { [
            weak self,
            weak captureDevice
        ] _, change in
            guard let self = self, let captureDevice = captureDevice else { return }
            guard let systemPressureState = change.newValue?.level else { return }

            switch systemPressureState {
            case .nominal:
                self.setFrameRateForDevice(
                    captureDevice: captureDevice,
                    framerate: Framerates.high.rawValue,
                    useRange: true
                )
            case .fair:
                self.setFrameRateForDevice(
                    captureDevice: captureDevice,
                    framerate: Framerates.medium.rawValue,
                    useRange: false
                )
            case .serious, .critical:
                self.setFrameRateForDevice(
                    captureDevice: captureDevice,
                    framerate: Framerates.low.rawValue,
                    useRange: false
                )
            case .shutdown:
                self.stopCapturing()
            default:
                break
            }
        }
    }

    func getDeviceInfo(
        forPosition position: AVCaptureDevice.Position,
        quality: AVCaptureSession.Preset
    ) throws -> DeviceInfo {
        guard permissionGranted.value else {
            throw VideoError.needPermission
        }
        captureSession.sessionPreset = quality
        guard let captureDevice = selectCaptureDevice(withPosition: position) else {
            throw VideoError.selectDeviceFailed
        }
        let formatDescription = captureDevice.activeFormat.formatDescription
        let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
        var bestRate = 30.0
        for vFormat in captureDevice.formats {
            let ranges = vFormat.videoSupportedFrameRateRanges as [AVFrameRateRange]
            let frameRates = ranges[0]
            if frameRates.maxFrameRate > bestRate {
                bestRate = frameRates.maxFrameRate
            }
        }
        let devInfo: DeviceInfo = ["format": "BGRA",
                                   "width": String(dimensions.width),
                                   "height": String(dimensions.height),
                                   "rate": String(bestRate)]
        return devInfo
    }

    func startCapturing() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.captureSession.canSetSessionPreset(self.quality) {
                self.captureSession.beginConfiguration()
                self.captureSession.sessionPreset = self.quality
                self.captureSession.commitConfiguration()
            }
            self.captureSession.startRunning()
        }
    }

    func stopCapturing() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.captureSession.stopRunning()
        }
    }

    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: AVMediaType.video) {
        case .authorized:
            permissionGranted.accept(true)
        case .notDetermined:
            requestPermission()
        default:
            permissionGranted.accept(false)
        }
    }

    private func requestPermission() {
        sessionQueue.suspend()
        AVCaptureDevice.requestAccess(for: AVMediaType.video) { [weak self] granted in
            self?.permissionGranted.accept(granted)
            self?.sessionQueue.resume()
        }
    }

    func configureSession(withPosition position: AVCaptureDevice.Position,
                          withOrientation orientation: AVCaptureVideoOrientation) {
        sessionQueue.sync { [weak self] in
            guard let self = self else { return }
            do {
                try self.performConfiguration(withPosition: position, withOrientation: orientation)
            } catch {
                print("Error configuring session: \(error)")
            }
        }
    }

    private func performConfiguration(withPosition position: AVCaptureDevice.Position,
                                      withOrientation orientation: AVCaptureVideoOrientation) throws {
        captureSession.beginConfiguration()
        defer { self.captureSession.commitConfiguration() }

        guard permissionGranted.value else {
            throw VideoError.needPermission
        }

        captureSession.sessionPreset = quality

        guard let captureDevice = selectCaptureDevice(withPosition: position) else {
            throw VideoError.selectDeviceFailed
        }

        observeSystemPressureChanges(captureDevice: captureDevice)

        if #available(iOS 16.0, *) {
            if self.captureSession.isMultitaskingCameraAccessSupported {
                self.captureSession.isMultitaskingCameraAccessEnabled = true
            }
        }

        let captureDeviceInput = try AVCaptureDeviceInput(device: captureDevice)

        guard captureSession.canAddInput(captureDeviceInput) else {
            throw VideoError.setupInputDeviceFailed
        }
        captureSession.addInput(captureDeviceInput)

        let videoOutput = AVCaptureVideoDataOutput()
        let types = videoOutput.availableVideoPixelFormatTypes

        if types.contains(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange) {
            let settings =
                [
                    kCVPixelBufferPixelFormatTypeKey as NSString: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
                ]
            videoOutput.videoSettings = settings as [String: Any]
        }

        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)

        guard captureSession.canAddOutput(videoOutput) else {
            throw VideoError.setupOutputDeviceFailed
        }
        captureSession.addOutput(videoOutput)

        guard let connection = videoOutput.connection(with: .video) else {
            throw VideoError.getConnectionFailed
        }

        guard connection.isVideoOrientationSupported else {
            throw VideoError.unsupportedParameter
        }

        guard connection.isVideoMirroringSupported else {
            throw VideoError.unsupportedParameter
        }

        connection.videoOrientation = orientation
    }

    func selectCaptureDevice(withPosition position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let devices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera],
            mediaType: AVMediaType.video,
            position: position
        ).devices
        return devices.first
    }

    func switchCamera() -> Completable {
        return Completable.create { [weak self] completable in
            self?.sessionQueue.async { [weak self] in
                guard let self = self else {
                    completable(.error(VideoError.switchCameraFailed))
                    return
                }
                self.performSwitchCamera(completable: completable)
            }
            return Disposables.create()
        }
    }

    private func performSwitchCamera(completable: @escaping (CompletableEvent) -> Void) {
        captureSession.beginConfiguration()
        defer { self.captureSession.commitConfiguration() }

        guard let currentCameraInput = captureSession.inputs.first as? AVCaptureDeviceInput else {
            completable(.error(VideoError.switchCameraFailed))
            return
        }

        captureSession.removeInput(currentCameraInput)
        guard let newCamera = selectNewCamera(currentCameraInput: currentCameraInput) else {
            completable(.error(VideoError.switchCameraFailed))
            return
        }

        observeSystemPressureChanges(captureDevice: newCamera)
        delegate?.updateDevicePosition(position: newCamera.position)

        do {
            let newVideoInput = try AVCaptureDeviceInput(device: newCamera)
            if captureSession.canAddInput(newVideoInput) {
                captureSession.addInput(newVideoInput)
            } else {
                completable(.error(VideoError.switchCameraFailed))
                return
            }
        } catch {
            completable(.error(VideoError.switchCameraFailed))
            return
        }

        guard configureOutputConnection() else {
            completable(.error(VideoError.switchCameraFailed))
            return
        }

        completable(.completed)
    }

    private func selectNewCamera(currentCameraInput: AVCaptureDeviceInput) -> AVCaptureDevice? {
        if currentCameraInput.device.position == .back {
            return selectCaptureDevice(withPosition: .front)
        } else {
            return selectCaptureDevice(withPosition: .back)
        }
    }

    private func configureOutputConnection() -> Bool {
        guard let currentCameraOutput = captureSession.outputs.first,
              let connection = currentCameraOutput.connection(with: .video),
              connection.isVideoOrientationSupported,
              connection.isVideoMirroringSupported
        else {
            return false
        }

        connection.videoOrientation = orientation
        return true
    }

    // MARK: Sample buffer to UIImage conversion

    private func imageFromSampleBuffer(sampleBuffer: CMSampleBuffer) -> UIImage? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    func captureOutput(
        _: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from _: AVCaptureConnection
    ) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        guard let uiImage = imageFromSampleBuffer(sampleBuffer: sampleBuffer) else { return }
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.captured(imageBuffer: imageBuffer, image: uiImage)
        }
    }
}

typealias RendererTuple = (sinkId: String, buffer: CMSampleBuffer?, running: Bool)

class VideoService: FrameExtractorDelegate {
    private let videoAdapter: VideoAdapter
    private let camera = FrameExtractor()

    var cameraPosition = AVCaptureDevice.Position.front
    let capturedVideoFrame = PublishSubject<UIImage?>()
    let playerInfo = PublishSubject<Player>()
    var renderStarted = BehaviorRelay(value: "")
    var renderStopped = BehaviorRelay(value: "")
    var currentOrientation: AVCaptureVideoOrientation

    private let log = SwiftyBeaver.self
    private var hardwareAccelerationEnabledByUser = true
    var angle: Int = 0
    var switchInputRequested: Bool = false
    var currentDeviceId = ""
    var videoInputManager = VideoInputsManager()

    let mutedCamera = "mutedCamera"

    private let disposeBag = DisposeBag()

    init(withVideoAdapter videoAdapter: VideoAdapter) {
        self.videoAdapter = videoAdapter
        currentOrientation = camera.getOrientation
        VideoAdapter.videoDelegate = self
        hardwareAccelerationEnabledByUser = videoAdapter.getEncodingAccelerated()
        camera.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(restoreDefaultDevice),
                                               name: NSNotification
                                                .Name(rawValue: NotificationName
                                                        .restoreDefaultVideoDevice.rawValue),
                                               object: nil)
    }

    @objc
    func restoreDefaultDevice() {
        let accelerated = videoAdapter.getEncodingAccelerated()
        let device = videoAdapter.getDefaultDevice()
        if accelerated && device == camera.mediumCamera {
            videoAdapter.setDefaultDevice(camera.highResolutionCamera)
        }
    }

    func setupInputs() {
        camera.permissionGrantedObservable
            .subscribe(onNext: { granted in
                if granted {
                    self.enumerateVideoInputDevices()
                }
            })
            .disposed(by: disposeBag)
        // Will trigger enumerateVideoInputDevices once permission is granted
        camera.checkPermission()
    }

    func getVideoSource() -> String {
        return "camera://" + currentDeviceId
    }

    func getCurrentVideoSource() -> String {
        return videoAdapter.getDefaultDevice()
    }

    func enumerateVideoInputDevices() {
        do {
            camera.configureSession(
                withPosition: AVCaptureDevice.Position.front,
                withOrientation: camera.getOrientation
            )
            log.debug("Camera successfully configured")
            let highResolutionDevice: [String: String] = try camera
                .getDeviceInfo(forPosition: AVCaptureDevice.Position.front,
                               quality: AVCaptureSession.Preset.high)
            let mediumDevice: [String: String] = try camera
                .getDeviceInfo(forPosition: AVCaptureDevice.Position.front,
                               quality: AVCaptureSession.Preset.medium)
            videoAdapter.addVideoDevice(withName: camera.mediumCamera,
                                        withDevInfo: mediumDevice)
            videoAdapter.addVideoDevice(withName: camera.highResolutionCamera,
                                        withDevInfo: highResolutionDevice)
            let accelerated = videoAdapter.getEncodingAccelerated()
            if accelerated {
                videoAdapter.setDefaultDevice(camera.highResolutionCamera)
            } else {
                videoAdapter.setDefaultDevice(camera.mediumCamera)
            }
            currentDeviceId = videoAdapter.getDefaultDevice()
        } catch let e as VideoError {
            self.log.error("Error during capture device enumeration: \(e)")
        } catch {
            log.error("Unkonwn error configuring capture device")
        }
    }

    func switchCamera() {
        camera.switchCamera()
            .subscribe(onCompleted: {
                print("camera switched")
            }, onError: { error in
                print(error)
            })
            .disposed(by: disposeBag)
    }

    func setCameraOrientation(orientation: UIDeviceOrientation, forceUpdate: Bool = false) {
        var newOrientation: AVCaptureVideoOrientation
        switch orientation {
        case .portrait:
            newOrientation = AVCaptureVideoOrientation.portrait
        case .portraitUpsideDown:
            newOrientation = AVCaptureVideoOrientation.portraitUpsideDown
        case .landscapeLeft:
            newOrientation = AVCaptureVideoOrientation.landscapeLeft
        case .landscapeRight:
            newOrientation = AVCaptureVideoOrientation.landscapeRight
        default:
            newOrientation = AVCaptureVideoOrientation.portrait
        }
        if newOrientation == currentOrientation && !forceUpdate {
            log.warning("no orientation change required")
            return
        }
        angle = mapDeviceOrientation(orientation: newOrientation)
        currentOrientation = newOrientation
    }

    func mapDeviceOrientation(orientation: AVCaptureVideoOrientation) -> Int {
        switch orientation {
        case AVCaptureVideoOrientation.portrait:
            return cameraPosition == AVCaptureDevice.Position.front ? 270 : 90
        case AVCaptureVideoOrientation.landscapeLeft:
            return 180
        default:
            return 0
        }
    }
}

extension VideoService: VideoAdapterDelegate {
    func switchInput(toDevice device: String, call: CallModel) {
        requestMediaChange(call: call, mediaLabel: "video_0", source: device)
    }

    func requestMediaChange(call: CallModel, mediaLabel: String, source: String) {
        var mediaList = call.mediaList
        let medias = mediaList.count
        var found = false
        for index in 0 ..< medias
        where mediaList[index][MediaAttributeKey.label.rawValue] == mediaLabel {
            mediaList[index][MediaAttributeKey.enabled.rawValue] = "true"
            let muted = mediaList[index][MediaAttributeKey.muted.rawValue]
            // Use "muteSource" to represent a muted camera source.
            // This variable name indicates that the camera is intentionally not real,
            // while keeping the number of inputs consistent.
            var device = source
            if !source.hasPrefix("camera://") {
                device = "camera://" + source
            }
            mediaList[index][MediaAttributeKey.source.rawValue] = muted == "true" ? device :
                mutedCamera
            mediaList[index][MediaAttributeKey.muted.rawValue] = muted == "true" ? "false" : "true"
            found = true
            break
        }

        if !found && mediaLabel == "video_0" {
            var media = [String: String]()
            media[MediaAttributeKey.mediaType.rawValue] = MediaAttributeValue.video.rawValue
            media[MediaAttributeKey.enabled.rawValue] = "true"
            media[MediaAttributeKey.muted.rawValue] = "false"
            media[MediaAttributeKey.source.rawValue] = ""
            media[MediaAttributeKey.label.rawValue] = mediaLabel
            mediaList.append(media)
        }
        videoAdapter.requestMediaChange(
            call.callId,
            accountId: call.accountId,
            withMedia: mediaList
        )
    }

    func setDecodingAccelerated(withState state: Bool) {
        videoAdapter.setDecodingAccelerated(state)
    }

    func setEncodingAccelerated(withState state: Bool) {
        videoAdapter.setEncodingAccelerated(state)
    }

    func getDecodingAccelerated() -> Bool {
        return videoAdapter.getDecodingAccelerated()
    }

    func getEncodingAccelerated() -> Bool {
        return videoAdapter.getEncodingAccelerated()
    }

    func setHardwareAccelerated(withState state: Bool) {
        videoAdapter.setDecodingAccelerated(state)
        videoAdapter.setEncodingAccelerated(state)
        hardwareAccelerationEnabledByUser = state
        if state {
            videoAdapter.setDefaultDevice(camera.highResolutionCamera)
        } else {
            videoAdapter.setDefaultDevice(camera.mediumCamera)
        }
    }

    func decodingStarted(
        withsinkId sinkId: String,
        withWidth width: Int,
        withHeight height: Int,
        withCodec codec: String?,
        withaAccountId _: String,
        call: CallModel?
    ) {
        if let codecId = codec, !codecId.isEmpty {
            // we do not support hardware acceleration with VP8 codec. In this case software
            // encoding will be used. Downgrate resolution if needed. After call finished
            // resolution will be restored in restoreDefaultDevice()
            let codec = VideoCodecs(rawValue: codecId) ?? VideoCodecs.unknown
            if let call = call,
               !supportHardware(codec: codec),
               camera.quality == AVCaptureSession.Preset.high {
                videoAdapter.setDefaultDevice(camera.mediumCamera)
                switchInput(toDevice: "camera://" + camera.mediumCamera, call: call)
            }
        }
        let hasListener = videoInputManager.hasListener(sinkId: sinkId)
        videoAdapter.registerSinkTarget(
            withSinkId: sinkId,
            withWidth: width,
            withHeight: height,
            hasListeners: hasListener
        )
        currentDeviceId = videoAdapter.getDefaultDevice()
        renderStarted.accept(sinkId)
    }

    func addListener(withsinkId sinkId: String) {
        videoInputManager.addListener(sinkId: sinkId)
        let hasListeners = videoInputManager.hasListener(sinkId: sinkId)
        videoAdapter.setHasListeners(hasListeners, forSinkId: sinkId)
    }

    func hasListener(withsinkId sinkId: String) -> Bool {
        return videoInputManager.hasListener(sinkId: sinkId)
    }

    func removeListener(withsinkId sinkId: String) {
        videoInputManager.removeListener(sinkId: sinkId)
        let hasListeners = videoInputManager.hasListener(sinkId: sinkId)
        videoAdapter.setHasListeners(hasListeners, forSinkId: sinkId)
    }

    func decodingStopped(withsinkId sinkId: String) {
        videoInputManager.stop(sinkId: sinkId)
        videoAdapter.removeSinkTarget(withSinkId: sinkId)
    }

    func writeFrame(withBuffer buffer: CVPixelBuffer?, sinkId: String, rotation: Int) {
        videoInputManager.writeFrame(withBuffer: buffer, sinkId: sinkId, rotation: rotation)
    }

    func supportHardware(codec: VideoCodecs) -> Bool {
        return codec == VideoCodecs.H264 || codec == VideoCodecs.H265
    }

    func startCapture(withDevice device: String) {
        log.debug("Capture started...")
        if device == camera.highResolutionCamera && camera.quality == AVCaptureSession.Preset
            .medium {
            camera.setQuality(quality: AVCaptureSession.Preset.high)
        } else if device == camera.mediumCamera && camera.quality == AVCaptureSession.Preset.high {
            camera.setQuality(quality: AVCaptureSession.Preset.medium)
        }
        angle = mapDeviceOrientation(orientation: currentOrientation)
        camera.startCapturing()
    }

    func startVideoCaptureBeforeCall() {
        hardwareAccelerationEnabledByUser = videoAdapter.getEncodingAccelerated()
        camera.startCapturing()
    }

    func startMediumCamera() {
        videoAdapter.openVideoInput("camera://" + camera.mediumCamera)
    }

    func videRecordingFinished() {
        if cameraPosition == .back {
            switchCamera()
        }
        videoAdapter.closeVideoInput("camera://" + camera.mediumCamera)
        stopAudioDevice()
    }

    func stopCapture(withDevice device: String) {
        if !device.isEmpty && device != mutedCamera {
            camera.stopCapturing()
        }
    }

    func getImageOrienation() -> UIImage.Orientation {
        let shouldMirror = cameraPosition == AVCaptureDevice.Position.front
        switch currentOrientation {
        case AVCaptureVideoOrientation.portrait:
            return shouldMirror ? UIImage.Orientation.leftMirrored :
                UIImage.Orientation.left
        case AVCaptureVideoOrientation.portraitUpsideDown:
            return shouldMirror ? UIImage.Orientation.rightMirrored :
                UIImage.Orientation.right
        case AVCaptureVideoOrientation.landscapeRight:
            return shouldMirror ? UIImage.Orientation.upMirrored :
                UIImage.Orientation.up
        case AVCaptureVideoOrientation.landscapeLeft:
            return shouldMirror ? UIImage.Orientation.downMirrored :
                UIImage.Orientation.down
        @unknown default:
            return UIImage.Orientation.up
        }
    }

    func captured(imageBuffer: CVImageBuffer?, image: UIImage) {
        if let cgImage = image.cgImage {
            capturedVideoFrame
                .onNext(UIImage(cgImage: cgImage,
                                scale: 1.0,
                                orientation: getImageOrienation()))
        }
        videoAdapter.writeOutgoingFrame(
            with: imageBuffer,
            angle: Int32(angle),
            videoInputId: getVideoSource()
        )
    }

    func updateDevicePosition(position: AVCaptureDevice.Position) {
        cameraPosition = position
        angle = mapDeviceOrientation(orientation: currentOrientation)
    }

    func stopAudioDevice() {
        videoAdapter.stopAudioDevice()
    }

    func startLocalRecorder(audioOnly: Bool, path: String) -> String? {
        let device = audioOnly ? "" : "camera://" + camera.mediumCamera
        currentDeviceId = camera.mediumCamera
        return videoAdapter.startLocalRecording(device, path: path)
    }

    func stopLocalRecorder(path: String) {
        videoAdapter.stopLocalRecording(path)
    }

    func getConferenceVideoSize(confId: String) -> CGSize {
        return videoAdapter.getRenderSize(confId)
    }
}

// MARK: media player

struct Player {
    var playerId: String
    var duration: String
    var hasAudio: Bool
    var hasVideo: Bool
}

enum PlayerInfo: String {
    case duration
    case audio_stream
    case video_stream
}

extension VideoService {
    func createPlayer(path: String) -> String {
        let player = videoAdapter.createMediaPlayer(path)
        return player ?? ""
    }

    func pausePlayer(playerId: String, pause: Bool) {
        if !pause {
            addListener(withsinkId: playerId)
        } else {
            removeListener(withsinkId: playerId)
        }
        videoAdapter.pausePlayer(playerId, pause: pause)
    }

    func mutePlayerAudio(playerId: String, mute: Bool) {
        videoAdapter.mutePlayerAudio(playerId, mute: mute)
    }

    func seekToTime(time: Int, playerId: String) {
        videoAdapter.playerSeek(toTime: Int32(time), playerId: playerId)
    }

    func closePlayer(playerId: String) {
        videoAdapter.closePlayer(playerId)
    }

    func fileOpened(for playerId: String, fileInfo: [String: String]) {
        let duration: String = fileInfo[PlayerInfo.duration.rawValue] ?? "0"
        let audioStream = Int(fileInfo[PlayerInfo.audio_stream.rawValue] ?? "-1") ?? -1
        let videoStream = Int(fileInfo[PlayerInfo.video_stream.rawValue] ?? "-1") ?? -1
        let hasAudio = audioStream >= 0
        let hasVideo = videoStream >= 0
        let player = Player(playerId: playerId,
                            duration: duration,
                            hasAudio: hasAudio,
                            hasVideo: hasVideo)
        playerInfo.onNext(player)
    }

    func getPlayerPosition(playerId: String) -> Int64 {
        return videoAdapter.getPlayerPosition(playerId)
    }
}
