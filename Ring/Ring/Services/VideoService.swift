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
import SwiftyBeaver
import RxSwift
import RxRelay
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

    lazy var permissionGrantedObservable: Observable<Bool> = {
        return self.permissionGranted.asObservable()
    }()

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
                    print("An error occurred while attempting to lock device for configuration: \(error)")
                }
                return
            }
        }
    }

    func observeSystemPressureChanges(captureDevice: AVCaptureDevice) {
        // Restore normal framerate.
        setFrameRateForDevice(captureDevice: captureDevice, framerate: Framerates.high.rawValue, useRange: true)

        // Observe system pressure.
        systemPressureObservation = captureDevice.observe(\.systemPressureState, options: .new) { [weak self, weak captureDevice] _, change in
            guard let self = self, let captureDevice = captureDevice else { return }
            guard let systemPressureState = change.newValue?.level else { return }

            switch systemPressureState {
            case .nominal:
                self.setFrameRateForDevice(captureDevice: captureDevice, framerate: Framerates.high.rawValue, useRange: true)
            case .fair:
                self.setFrameRateForDevice(captureDevice: captureDevice, framerate: Framerates.medium.rawValue, useRange: false)
            case .serious, .critical:
                self.setFrameRateForDevice(captureDevice: captureDevice, framerate: Framerates.low.rawValue, useRange: false)
            case .shutdown:
                self.stopCapturing()
            default:
                break
            }
        }
    }

    func getDeviceInfo(forPosition position: AVCaptureDevice.Position, quality: AVCaptureSession.Preset) throws -> DeviceInfo {
        guard self.permissionGranted.value else {
            throw VideoError.needPermission
        }
        self.captureSession.sessionPreset = quality
        guard let captureDevice = self.selectCaptureDevice(withPosition: position) else {
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
            self.permissionGranted.accept(true)
        case .notDetermined:
            requestPermission()
        default:
            self.permissionGranted.accept(false)
        }
    }

    private func requestPermission() {
        sessionQueue.suspend()
        AVCaptureDevice.requestAccess(for: AVMediaType.video) { [weak self] granted in
            /*
             SessionQueue should be resumed first,
             before permissionGranted triggers device enumeration.
             */
            self?.sessionQueue.resume()
            self?.permissionGranted.accept(granted)
        }
    }

    func configureSession(withPosition position: AVCaptureDevice.Position,
                          withOrientation orientation: AVCaptureVideoOrientation) {
        sessionQueue.sync { [weak self] in
            guard let self = self else { return }
            do {
                try self.performConfiguration(withPosition: position, withOrientation: orientation)
            } catch {
                print("An error occurred while configuring session: \(error)")
            }
        }
    }

    private func performConfiguration(withPosition position: AVCaptureDevice.Position,
                                      withOrientation orientation: AVCaptureVideoOrientation) throws {
        self.captureSession.beginConfiguration()
        defer { self.captureSession.commitConfiguration() }

        guard permissionGranted.value else {
            throw VideoError.needPermission
        }

        self.captureSession.sessionPreset = quality

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

        guard self.captureSession.canAddInput(captureDeviceInput) else {
            throw VideoError.setupInputDeviceFailed
        }
        self.captureSession.addInput(captureDeviceInput)

        let videoOutput = AVCaptureVideoDataOutput()
        let types = videoOutput.availableVideoPixelFormatTypes

        if types.contains(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange) {
            let settings = [kCVPixelBufferPixelFormatTypeKey as NSString: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange]
            videoOutput.videoSettings = settings as [String: Any]
        }

        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)

        guard self.captureSession.canAddOutput(videoOutput) else {
            throw VideoError.setupOutputDeviceFailed
        }
        self.captureSession.addOutput(videoOutput)

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
        let devices = AVCaptureDevice.DiscoverySession.init(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera], mediaType: AVMediaType.video, position: position).devices
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
        self.captureSession.beginConfiguration()
        defer { self.captureSession.commitConfiguration() }

        guard let currentCameraInput = self.captureSession.inputs.first as? AVCaptureDeviceInput else {
            completable(.error(VideoError.switchCameraFailed))
            return
        }

        self.captureSession.removeInput(currentCameraInput)
        guard let newCamera = selectNewCamera(currentCameraInput: currentCameraInput) else {
            completable(.error(VideoError.switchCameraFailed))
            return
        }

        observeSystemPressureChanges(captureDevice: newCamera)
        delegate?.updateDevicePosition(position: newCamera.position)

        do {
            let newVideoInput = try AVCaptureDeviceInput(device: newCamera)
            if self.captureSession.canAddInput(newVideoInput) {
                self.captureSession.addInput(newVideoInput)
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
              connection.isVideoMirroringSupported else {
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

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
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
        self.hardwareAccelerationEnabledByUser = videoAdapter.getEncodingAccelerated()
        camera.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(self.restoreDefaultDevice),
                                               name: NSNotification.Name(rawValue: NotificationName.restoreDefaultVideoDevice.rawValue),
                                               object: nil)
    }

    @objc
    func restoreDefaultDevice() {
        let accelerated = self.videoAdapter.getEncodingAccelerated()
        let device = self.videoAdapter.getDefaultDevice()
        if accelerated && device == camera.mediumCamera {
            self.videoAdapter.setDefaultDevice(camera.highResolutionCamera)
        }
    }

    func setupInputs() {
        self.camera.permissionGrantedObservable
            .subscribe(onNext: { granted in
                if granted {
                    self.enumerateVideoInputDevices()
                }
            })
            .disposed(by: self.disposeBag)
        // Will trigger enumerateVideoInputDevices once permission is granted
        camera.checkPermission()
    }

    func getVideoSource() -> String {
        return "camera://" + self.currentDeviceId
    }

    func getCurrentVideoSource() -> String {
        return self.videoAdapter.getDefaultDevice()
    }

    func enumerateVideoInputDevices() {
        do {
            camera.configureSession(withPosition: AVCaptureDevice.Position.front, withOrientation: camera.getOrientation)
            self.log.debug("Camera configured successfully.")
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
            let accelerated = self.videoAdapter.getEncodingAccelerated()
            if accelerated {
                self.videoAdapter.setDefaultDevice(camera.highResolutionCamera)
            } else {
                self.videoAdapter.setDefaultDevice(camera.mediumCamera)
            }
            self.currentDeviceId = self.videoAdapter.getDefaultDevice()
        } catch let e as VideoError {
            self.log.error("An error occurred while capturing device enumeration: \(e)")
        } catch {
            self.log.error("An unknown error occurred while configuring capture device.")
        }
    }

    func switchCamera() {
        self.camera.switchCamera()
            .subscribe(onCompleted: {
                print("Camera switched successfully.")
            }, onError: { error in
                print(error)
            })
            .disposed(by: self.disposeBag)
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
        if newOrientation == self.currentOrientation && !forceUpdate {
            self.log.warning("No orientation change required.")
            return
        }
        self.angle = self.mapDeviceOrientation(orientation: newOrientation)
        self.currentOrientation = newOrientation
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
        self.requestMediaChange(call: call, mediaLabel: "video_0", source: device)
    }

    func requestMediaChange(call: CallModel, mediaLabel: String, source: String) {
        var mediaList = call.mediaList
        let medias = mediaList.count
        var found = false
        for index in 0..<medias where mediaList[index][MediaAttributeKey.label.rawValue] == mediaLabel {
            mediaList[index][MediaAttributeKey.enabled.rawValue] = "true"
            let muted = mediaList[index][MediaAttributeKey.muted.rawValue]
            // Use "muteSource" to represent a muted camera source.
            // This variable name indicates that the camera is intentionally not real,
            // while keeping the number of inputs consistent.
            var device = source
            if !source.hasPrefix("camera://") {
                device = "camera://" + source
            }
            mediaList[index][MediaAttributeKey.source.rawValue] = muted == "true" ? device : mutedCamera
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
        self.videoAdapter.requestMediaChange(call.callId, accountId: call.accountId, withMedia: mediaList)
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
            self.videoAdapter.setDefaultDevice(camera.highResolutionCamera)
        } else {
            self.videoAdapter.setDefaultDevice(camera.mediumCamera)
        }
    }

    func decodingStarted(withsinkId sinkId: String, withWidth width: Int, withHeight height: Int, withCodec codec: String?, withaAccountId accountId: String, call: CallModel?) {
        // Add debug logging
        print("VIDEO DEBUG: Decoding started for sinkId: \(sinkId), width: \(width), height: \(height), codec: \(codec ?? "none"), call: \(call?.callId ?? "none")")
        
        if let codecId = codec, !codecId.isEmpty {
            // we do not support hardware acceleration with VP8 codec. In this case software
            // encoding will be used. Downgrate resolution if needed. After call finished
            // resolution will be restored in restoreDefaultDevice()
            let codec = VideoCodecs(rawValue: codecId) ?? VideoCodecs.unknown
            if let call = call,
               !supportHardware(codec: codec),
               self.camera.quality == AVCaptureSession.Preset.high {
                self.videoAdapter.setDefaultDevice(camera.mediumCamera)
                self.switchInput(toDevice: "camera://" + camera.mediumCamera, call: call)
            }
        }
        let hasListener = self.videoInputManager.hasListener(sinkId: sinkId)
        print("VIDEO DEBUG: hasListener for sinkId \(sinkId): \(hasListener)")
        videoAdapter.registerSinkTarget(withSinkId: sinkId, withWidth: width, withHeight: height, hasListeners: hasListener)
        self.currentDeviceId = self.videoAdapter.getDefaultDevice()
        renderStarted.accept(sinkId)
    }

    func addListener(withsinkId sinkId: String) {
        self.videoInputManager.addListener(sinkId: sinkId)
        let hasListeners = self.videoInputManager.hasListener(sinkId: sinkId)
        self.videoAdapter.setHasListeners(hasListeners, forSinkId: sinkId)
    }

    func hasListener(withsinkId sinkId: String) -> Bool {
        return self.videoInputManager.hasListener(sinkId: sinkId)
    }

    func removeListener(withsinkId sinkId: String) {
        self.videoInputManager.removeListener(sinkId: sinkId)
        let hasListeners = self.videoInputManager.hasListener(sinkId: sinkId)
        self.videoAdapter.setHasListeners(hasListeners, forSinkId: sinkId)
    }

    func decodingStopped(withsinkId sinkId: String) {
        print("VIDEO DEBUG: Decoding stopped for sinkId: \(sinkId)")
        self.videoInputManager.stop(sinkId: sinkId)
        videoAdapter.removeSinkTarget(withSinkId: sinkId)
        renderStopped.accept(sinkId)
    }

    func writeFrame(withBuffer buffer: CVPixelBuffer?, sinkId: String, rotation: Int) {
        self.videoInputManager.writeFrame(withBuffer: buffer, sinkId: sinkId, rotation: rotation)
    }

    func supportHardware(codec: VideoCodecs) -> Bool {
        return codec == VideoCodecs.H264 || codec == VideoCodecs.H265
    }

    func startCapture(withDevice device: String) {
        self.log.debug("Capture started…")
        if device == camera.highResolutionCamera && self.camera.quality == AVCaptureSession.Preset.medium {
            self.camera.setQuality(quality: AVCaptureSession.Preset.high)
        } else if device == camera.mediumCamera && self.camera.quality == AVCaptureSession.Preset.high {
            self.camera.setQuality(quality: AVCaptureSession.Preset.medium)
        }
        self.angle = self.mapDeviceOrientation(orientation: self.currentOrientation)
        self.camera.startCapturing()
    }

    func startVideoCaptureBeforeCall() {
        self.hardwareAccelerationEnabledByUser = videoAdapter.getEncodingAccelerated()
        self.camera.startCapturing()
    }

    func startMediumCamera() {
        self.videoAdapter.openVideoInput("camera://" + self.camera.mediumCamera)
    }

    func videRecordingFinished() {
        if self.cameraPosition == .back {
            self.switchCamera()
        }
        self.videoAdapter.closeVideoInput("camera://" + self.camera.mediumCamera)
        self.stopAudioDevice()
    }

    func stopCapture(withDevice device: String) {
        if !device.isEmpty && device != mutedCamera {
            self.camera.stopCapturing()
        }
    }

    func getImageOrienation() -> UIImage.Orientation {
        let shouldMirror = cameraPosition == AVCaptureDevice.Position.front
        switch self.currentOrientation {
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
            self.capturedVideoFrame
                .onNext(UIImage(cgImage: cgImage,
                                scale: 1.0,
                                orientation: self.getImageOrienation()))
        }
        videoAdapter.writeOutgoingFrame(with: imageBuffer, angle: Int32(self.angle), videoInputId: self.getVideoSource())
    }

    func updateDevicePosition(position: AVCaptureDevice.Position) {
        self.cameraPosition = position
        self.angle = self.mapDeviceOrientation(orientation: self.currentOrientation)
    }

    func stopAudioDevice() {
        videoAdapter.stopAudioDevice()
    }

    func startLocalRecorder(audioOnly: Bool, path: String) -> String? {
        let device = audioOnly ? "" : "camera://" + camera.mediumCamera
        self.currentDeviceId = camera.mediumCamera
        return self.videoAdapter.startLocalRecording(device, path: path)
    }

    func stopLocalRecorder(path: String) {
        self.videoAdapter.stopLocalRecording(path)
    }

    func getConferenceVideoSize(confId: String) -> CGSize {
        return self.videoAdapter.getRenderSize(confId)
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
        let player = self.videoAdapter.createMediaPlayer(path)
        return player ?? ""
    }

    func pausePlayer(playerId: String, pause: Bool) {
        if !pause {
            self.addListener(withsinkId: playerId)
        } else {
            self.removeListener(withsinkId: playerId)
        }
        self.videoAdapter.pausePlayer(playerId, pause: pause)
    }

    func mutePlayerAudio(playerId: String, mute: Bool) {
        self.videoAdapter.mutePlayerAudio(playerId, mute: mute)
    }

    func seekToTime(time: Int, playerId: String) {
        self.videoAdapter.playerSeek(toTime: Int32(time), playerId: playerId)
    }

    func closePlayer(playerId: String) {
        self.videoAdapter.closePlayer(playerId)
    }

    func fileOpened(for playerId: String, fileInfo: [String: String]) {
        let duration: String = fileInfo[PlayerInfo.duration.rawValue] ?? "0"
        let audioStream: Int = Int(fileInfo[PlayerInfo.audio_stream.rawValue] ?? "-1") ?? -1
        let videoStream: Int = Int(fileInfo[PlayerInfo.video_stream.rawValue] ?? "-1") ?? -1
        let hasAudio = audioStream >= 0
        let hasVideo = videoStream >= 0
        let player = Player(playerId: playerId,
                            duration: duration,
                            hasAudio: hasAudio,
                            hasVideo: hasVideo)
        playerInfo.onNext(player)
    }

    func getPlayerPosition(playerId: String) -> Int64 {
        return self.videoAdapter.getPlayerPosition(playerId)
    }
}
