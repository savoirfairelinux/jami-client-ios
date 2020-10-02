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
import UIKit
import AVFoundation

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

protocol FrameExtractorDelegate: class {
    func captured(imageBuffer: CVImageBuffer?, image: UIImage)
    func updateDevicePisition(position: AVCaptureDevice.Position)
}

class FrameExtractor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    let namePortrait = "mediumCamera"
    let nameDevice1280_720 = "1280_720Camera"

    private let log = SwiftyBeaver.self

    var quality = AVCaptureSession.Preset.hd1280x720
    private var orientation = AVCaptureVideoOrientation.portrait

    func setQuality(quality: AVCaptureSession.Preset) {
        self.quality = quality
    }

    var getOrientation: AVCaptureVideoOrientation {
        return orientation
    }

    var permissionGranted = Variable<Bool>(false)

    lazy var permissionGrantedObservable: Observable<Bool> = {
        return self.permissionGranted.asObservable()
    }()

    private let sessionQueue = DispatchQueue(label: "session queue")
    private let captureSession = AVCaptureSession()
    private let context = CIContext()

    weak var delegate: FrameExtractorDelegate?

    override init() {
        super.init()
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
                                   "width": String(dimensions.height),
                                   "height": String(dimensions.width),
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
            } else if self.captureSession.canSetSessionPreset(AVCaptureSession.Preset.medium) {
                self.quality = AVCaptureSession.Preset.medium
                self.captureSession.beginConfiguration()
                self.captureSession.sessionPreset = self.quality
                self.captureSession.commitConfiguration()
            }
            self.captureSession.startRunning()
        }
    }

    func stopCapturing() {
        sessionQueue.async { [weak self] in
            self?.captureSession.stopRunning()
        }
    }

    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: AVMediaType.video) {
        case .authorized:
            self.permissionGranted.value = true
        case .notDetermined:
            requestPermission()
        default:
            self.permissionGranted.value = false
        }
    }

    private func requestPermission() {
        sessionQueue.suspend()
        AVCaptureDevice.requestAccess(for: AVMediaType.video) { [weak self] granted in
            self?.permissionGranted.value = granted
            self?.sessionQueue.resume()
        }
    }

    func configureSession(withPosition position: AVCaptureDevice.Position,
                          withOrientation orientation: AVCaptureVideoOrientation) throws {
        captureSession.beginConfiguration()
        guard self.permissionGranted.value else {
            throw VideoError.needPermission
        }
        captureSession.sessionPreset = quality
        guard let captureDevice = selectCaptureDevice(withPosition: position) else {
            throw VideoError.selectDeviceFailed
        }
        let captureDeviceInput = try AVCaptureDeviceInput(device: captureDevice)
        guard captureSession.canAddInput(captureDeviceInput) else {
            throw VideoError.setupInputDeviceFailed
        }
        captureSession.addInput(captureDeviceInput)
        let videoOutput = AVCaptureVideoDataOutput()
        let types = videoOutput.availableVideoPixelFormatTypes
        if types.contains(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange) {
            let settings = [kCVPixelBufferPixelFormatTypeKey as NSString: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange]
            videoOutput.videoSettings = settings as [String: Any]
        }
        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        guard captureSession.canAddOutput(videoOutput) else {
            throw VideoError.setupOutputDeviceFailed
        }
        captureSession.addOutput(videoOutput)
        guard let connection = videoOutput.connection(with: AVFoundation.AVMediaType.video) else {
            throw VideoError.getConnectionFailed
        }
        guard connection.isVideoOrientationSupported else {
            throw VideoError.unsupportedParameter
        }
        guard connection.isVideoMirroringSupported else {
            throw VideoError.unsupportedParameter
        }
        connection.videoOrientation = orientation
        captureSession.commitConfiguration()
    }

    func selectCaptureDevice(withPosition position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let devices = AVCaptureDevice.DiscoverySession.init(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera], mediaType: AVMediaType.video, position: position).devices
        return devices.first
    }

    func switchCamera() -> Completable {
        return Completable.create { [weak self] completable in
            guard let self = self else { return Disposables.create { } }
            self.captureSession.beginConfiguration()
            guard let currentCameraInput: AVCaptureInput = self.captureSession.inputs.first else {
                completable(.error(VideoError.switchCameraFailed))
                return Disposables.create {}
            }
            self.captureSession.removeInput(currentCameraInput)
            var newCamera: AVCaptureDevice! = nil
            if let input = currentCameraInput as? AVCaptureDeviceInput {
                if input.device.position == .back {
                    newCamera = self.selectCaptureDevice(withPosition: .front)
                } else {
                    newCamera = self.selectCaptureDevice(withPosition: .back)
                }
                self.delegate!.updateDevicePisition(position: newCamera.position)
            }
            var newVideoInput: AVCaptureDeviceInput!
            do {
                newVideoInput = try AVCaptureDeviceInput(device: newCamera)
            } catch {
                completable(.error(VideoError.switchCameraFailed))
                return Disposables.create { }
            }
            if self.captureSession.canAddInput(newVideoInput) {
                self.captureSession.addInput(newVideoInput)
                guard let currentCameraOutput: AVCaptureOutput = self.captureSession.outputs.first else {
                    completable(.error(VideoError.switchCameraFailed))
                    return Disposables.create {}
                }
                guard let connection = currentCameraOutput.connection(with: AVFoundation.AVMediaType.video) else {
                    completable(.error(VideoError.switchCameraFailed))
                    return Disposables.create {}
                }
                guard connection.isVideoOrientationSupported else {
                    completable(.error(VideoError.switchCameraFailed))
                    return Disposables.create {}
                }
                guard connection.isVideoMirroringSupported else {
                    completable(.error(VideoError.switchCameraFailed))
                    return Disposables.create {}
                }
                connection.videoOrientation = self.orientation
                self.captureSession.commitConfiguration()
                completable(.completed)
            } else {
                completable(.error(VideoError.switchCameraFailed))
            }
            return Disposables.create { }
        }
    }

    func rotateCamera(orientation: AVCaptureVideoOrientation) -> Completable {
        return Completable.create { [weak self] completable in
            guard let self = self else { return Disposables.create { } }
            guard self.permissionGranted.value else {
                completable(.error(VideoError.needPermission))
                return Disposables.create {}
            }
            self.captureSession.beginConfiguration()
            let videoOutput = self.captureSession.outputs[0]
            guard let connection = videoOutput.connection(with: AVFoundation.AVMediaType.video) else {
                completable(.error(VideoError.getConnectionFailed))
                return Disposables.create {}
            }
            guard connection.isVideoOrientationSupported else {
                completable(.error(VideoError.unsupportedParameter))
                return Disposables.create {}
            }
            self.orientation = orientation
            connection.videoOrientation = orientation
            self.captureSession.commitConfiguration()
            completable(.completed)
            return Disposables.create { }
        }
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

typealias RendererTuple = (rendererId: String, data: UIImage?)

// swiftlint:disable file_length
class VideoService: FrameExtractorDelegate {

    private let videoAdapter: VideoAdapter
    private let camera = FrameExtractor()

    var cameraPosition = AVCaptureDevice.Position.front
    let incomingVideoFrame = PublishSubject<RendererTuple?>()
    let capturedVideoFrame = PublishSubject<UIImage?>()
    let playerInfo = PublishSubject<Player>()
    var currentOrientation: AVCaptureVideoOrientation

    private let log = SwiftyBeaver.self
    // acceleration for current session(may be different from setted by user
    // for conference or when not supported by codec)
    private var hardwareAcceleratedForCurrentSession = true
    // taken from settings set by user
    private var hardwareAccelerationEnabledByUser = true
    var angle: Int = 0
    var switchInputRequested: Bool = false

    private let disposeBag = DisposeBag()

    var recording = false

    var codec = VideoCodecs.unknown

    init(withVideoAdapter videoAdapter: VideoAdapter) {
        self.videoAdapter = videoAdapter
        currentOrientation = camera.getOrientation
        VideoAdapter.delegate = self
        self.hardwareAcceleratedForCurrentSession = videoAdapter.getEncodingAccelerated()
        self.hardwareAccelerationEnabledByUser = videoAdapter.getEncodingAccelerated()
        camera.delegate = self
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

    func enumerateVideoInputDevices() {
        do {
            try camera.configureSession(withPosition: AVCaptureDevice.Position.front, withOrientation: AVCaptureVideoOrientation.portrait)
            self.log.debug("Camera successfully configured")
            let hd1280x720Device: [String: String] = try camera
                .getDeviceInfo(forPosition: AVCaptureDevice.Position.front,
                               quality: AVCaptureSession.Preset.hd1280x720)
            let frontPortraitCameraDevInfo: [String: String] = try camera
                    .getDeviceInfo(forPosition: AVCaptureDevice.Position.front,
                                   quality: AVCaptureSession.Preset.medium)
            if self.hardwareAccelerationEnabledByUser {
                self.camera.setQuality(quality: AVCaptureSession.Preset.hd1280x720)
                videoAdapter.addVideoDevice(withName: camera.namePortrait,
                                            withDevInfo: frontPortraitCameraDevInfo)
                videoAdapter.addVideoDevice(withName: camera.nameDevice1280_720,
                                            withDevInfo: hd1280x720Device)
                return
            }
            self.camera.setQuality(quality: AVCaptureSession.Preset.medium)
            videoAdapter.addVideoDevice(withName: camera.nameDevice1280_720,
                                        withDevInfo: hd1280x720Device)
            videoAdapter.addVideoDevice(withName: camera.namePortrait,
                                        withDevInfo: frontPortraitCameraDevInfo)

        } catch let e as VideoError {
            self.log.error("Error during capture device enumeration: \(e)")
        } catch {
            self.log.error("Unkonwn error configuring capture device")
        }
    }

    func switchCamera() {
        self.camera.switchCamera()
            .subscribe(onCompleted: {
                print("camera switched")
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
            self.log.warning("no orientation change required")
            return
        }
        self.angle = self.mapDeviceOrientation(orientation: newOrientation)
        self.currentOrientation = newOrientation
    }

    func mapDeviceOrientation(orientation: AVCaptureVideoOrientation) -> Int {
        switch orientation {
        case AVCaptureVideoOrientation.landscapeRight:
            return cameraPosition == AVCaptureDevice.Position.front ? 90 : 270
        case AVCaptureVideoOrientation.landscapeLeft:
            return cameraPosition == AVCaptureDevice.Position.front ? 270 : 90
        default:
            return 0
        }
    }

    func disableHardwareForConference() {
        if !hardwareAccelerationEnabledByUser {
            return
        }
        videoAdapter.setEncodingAccelerated(false)
        videoAdapter.setDecodingAccelerated(false)
        self.camera.setQuality(quality: AVCaptureSession.Preset.medium)
        self.videoAdapter.setDefaultDevice(camera.namePortrait)
        self.hardwareAcceleratedForCurrentSession = false
    }

    func restoreStateAfterconference() {
        videoAdapter.setEncodingAccelerated(hardwareAccelerationEnabledByUser)
        videoAdapter.setDecodingAccelerated(hardwareAccelerationEnabledByUser)
        self.hardwareAcceleratedForCurrentSession = hardwareAccelerationEnabledByUser
        if hardwareAccelerationEnabledByUser {
            self.camera.setQuality(quality: AVCaptureSession.Preset.hd1280x720)
            self.videoAdapter.setDefaultDevice(camera.nameDevice1280_720)
        } else {
            self.camera.setQuality(quality: AVCaptureSession.Preset.medium)
            self.videoAdapter.setDefaultDevice(camera.namePortrait)
        }
    }
}

extension VideoService: VideoAdapterDelegate {
    func switchInput(toDevice device: String, callID: String?) {
        if let call = callID {
            videoAdapter.switchInput(device, forCall: call)
            return
        }
        videoAdapter.switchInput(device)
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
        hardwareAcceleratedForCurrentSession = state
        if state {
            self.camera.setQuality(quality: AVCaptureSession.Preset.hd1280x720)
            self.videoAdapter.setDefaultDevice(camera.nameDevice1280_720)
        } else {
            self.camera.setQuality(quality: AVCaptureSession.Preset.medium)
            self.videoAdapter.setDefaultDevice(camera.namePortrait)
        }
    }

    func decodingStarted(withRendererId rendererId: String, withWidth width: Int, withHeight height: Int, withCodec codecId: String) {
        if !codecId.isEmpty {
            self.codec = VideoCodecs(rawValue: codecId) ?? VideoCodecs.unknown
        }
        if !supportHardware() && self.camera.quality == AVCaptureSession.Preset.hd1280x720 {
            self.camera.setQuality(quality: AVCaptureSession.Preset.medium)
            self.videoAdapter.switchInput("camera://" + camera.namePortrait, forCall: rendererId)
            switchInputRequested = !codecId.isEmpty
        }
        self.log.debug("Decoding started...")
        let withHardware = !codecId.isEmpty ? (supportHardware() && self.hardwareAcceleratedForCurrentSession) : false
        videoAdapter.registerSinkTarget(withSinkId: rendererId, withWidth: width, withHeight: height, withHardwareSupport: withHardware)
    }

    func supportHardware() -> Bool {
        return self.codec == VideoCodecs.H264 || self.codec == VideoCodecs.H265
    }

    func decodingStopped(withRendererId rendererId: String) {
        self.log.debug("Decoding stopped...")
        videoAdapter.removeSinkTarget(withSinkId: rendererId)
        self.codec = VideoCodecs.unknown
    }

    func startCapture(withDevice device: String) {
        self.log.debug("Capture started...")
        if switchInputRequested {
            switchInputRequested = false
            self.camera.startCapturing()
            return
        }
        self.hardwareAccelerationEnabledByUser = videoAdapter.getEncodingAccelerated()
        self.hardwareAcceleratedForCurrentSession = hardwareAccelerationEnabledByUser
        if hardwareAccelerationEnabledByUser {
            self.camera.setQuality(quality: AVCaptureSession.Preset.hd1280x720)
            self.videoAdapter.setDefaultDevice(camera.nameDevice1280_720)
        } else {
            self.camera.setQuality(quality: AVCaptureSession.Preset.medium)
            self.videoAdapter.setDefaultDevice(camera.namePortrait)
        }
        self.camera.startCapturing()
    }

    func startVideoCaptureBeforeCall() {
        self.hardwareAccelerationEnabledByUser = videoAdapter.getEncodingAccelerated()
        self.camera.startCapturing()
    }

    func startCamera() {
        self.videoAdapter.startCamera()
    }

    func updateEncodongPreferences() {
        self.setEncodingAccelerated(withState: hardwareAccelerationEnabledByUser)
    }

    func videRecordingFinished() {
        if self.cameraPosition == .back {
            self.switchCamera()
        }
        self.videoAdapter.stopCamera()
        self.stopAudioDevice()
    }

    func stopCapture() {
        self.log.debug("Capture stopped...")
        self.camera.stopCapturing()
    }

    func writeFrame(withImage image: UIImage?, forCallId: String) {
        self.incomingVideoFrame.onNext(RendererTuple(forCallId, image))
    }

    func getImageOrienation() -> UIImage.Orientation {
        let shouldMirror = cameraPosition == AVCaptureDevice.Position.front
        switch self.currentOrientation {
        case AVCaptureVideoOrientation.portrait:
            return shouldMirror ? UIImage.Orientation.upMirrored :
                UIImage.Orientation.up
        case AVCaptureVideoOrientation.portraitUpsideDown:
            return shouldMirror ? UIImage.Orientation.downMirrored :
                UIImage.Orientation.down
        case AVCaptureVideoOrientation.landscapeRight:
            return shouldMirror ? UIImage.Orientation.rightMirrored :
                UIImage.Orientation.right
        case AVCaptureVideoOrientation.landscapeLeft:
            return shouldMirror ? UIImage.Orientation.leftMirrored :
                UIImage.Orientation.left
        @unknown default:
            return UIImage.Orientation.up
        }
    }

    func captured(imageBuffer: CVImageBuffer?, image: UIImage) {
        if let cgImage = image.cgImage {
            self.capturedVideoFrame
                .onNext(UIImage(cgImage: cgImage,
                                scale: 1.0 ,
                                orientation: self.getImageOrienation()))
        }
        videoAdapter.writeOutgoingFrame(with: imageBuffer,
                                        angle: Int32(self.angle),
                                        useHardwareAcceleration: (self.hardwareAcceleratedForCurrentSession && self.codec != .VP8),
                                        recording: self.recording)
    }

    func updateDevicePisition(position: AVCaptureDevice.Position) {
        self.cameraPosition = position
    }

    func stopAudioDevice() {
        videoAdapter.stopAudioDevice()
    }

    func startLocalRecorder(audioOnly: Bool, path: String) -> String? {
        self.recording = true
        return self.videoAdapter.startLocalRecording(path, audioOnly: audioOnly)
    }

    func stopLocalRecorder(path: String) {
        self.videoAdapter.stopLocalRecording(path)
        self.recording = false
    }

    func getConferenceVideoSize() -> (width: CGFloat, height: CGFloat) {
        var width: CGFloat = 0
        var height: CGFloat = 0
        if let deviceInfo: [String: String] = try? camera
            .getDeviceInfo(forPosition: AVCaptureDevice.Position.front,
                           quality: AVCaptureSession.Preset.medium),
            let widthString = deviceInfo["width"],
            let heightString = deviceInfo["height"] {
            width = CGFloat((widthString as NSString).doubleValue)
            height = CGFloat((heightString as NSString).doubleValue)

        }
        return (width, height)
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
