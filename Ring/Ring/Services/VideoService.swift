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

protocol FrameExtractorDelegate: class {
    func captured(imageBuffer: CVImageBuffer?, image: UIImage)
}

class FrameExtractor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    let nameLandscape = "frontCameraLanscape"
    let namePortrait = "frontCameraPortrait"
    let nameCamera = "camera://"

    private let log = SwiftyBeaver.self

    private let quality = AVCaptureSession.Preset.medium
    private var orientation = AVCaptureVideoOrientation.portrait
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

    func getDeviceInfo(forPosition position: AVCaptureDevice.Position, orientation: UIDeviceOrientation) throws -> DeviceInfo {
        guard self.permissionGranted.value else {
            throw VideoError.needPermission
        }
        self.captureSession.sessionPreset = self.quality
        guard let captureDevice = self.selectCaptureDevice(withPosition: position) else {
            throw VideoError.selectDeviceFailed
        }
        let formatDescription = captureDevice.activeFormat.formatDescription
        let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
        var bestRate = 30.0
        for vFormat in captureDevice.formats {
            var ranges = vFormat.videoSupportedFrameRateRanges as [AVFrameRateRange]
            let frameRates = ranges[0]
            if frameRates.maxFrameRate > bestRate {
                bestRate = frameRates.maxFrameRate
            }
        }
        if  orientation == .portrait ||
            orientation == .portraitUpsideDown {
            let devInfo: DeviceInfo = ["format": "BGRA",
                                       "width": String(dimensions.height),
                                       "height": String(dimensions.width),
                                       "rate": String(bestRate)]
            return devInfo
        } else {
            let devInfo: DeviceInfo = ["format": "BGRA",
                                       "width": String(dimensions.width),
                                       "height": String(dimensions.height),
                                       "rate": String(bestRate)]
            return devInfo
        }
    }

    func startCapturing() {
        sessionQueue.async { [unowned self] in
            if self.captureSession.canSetSessionPreset(self.quality) {
                self.captureSession.beginConfiguration()
                self.captureSession.sessionPreset = self.quality
                self.captureSession.commitConfiguration()
            }
            self.captureSession.startRunning()
        }
    }

    func stopCapturing() {
        sessionQueue.async { [unowned self] in
            self.captureSession.stopRunning()
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
        AVCaptureDevice.requestAccess(for: AVMediaType.video) { [unowned self] granted in
            self.permissionGranted.value = granted
            self.sessionQueue.resume()
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
        connection.isVideoMirrored = position == .front
        captureSession.commitConfiguration()
    }

    func selectCaptureDevice(withPosition position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let devices = AVCaptureDevice.devices(for: AVMediaType.video)
        for device in devices where device.position == position {
            return device
        }
        return nil
    }

    func switchCamera() -> Completable {
        return Completable.create { [unowned self] completable in
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
        return Completable.create { [unowned self] completable in
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
        DispatchQueue.main.async { [unowned self] in
            self.delegate?.captured(imageBuffer: imageBuffer, image: uiImage)
        }
    }
}

class VideoService: FrameExtractorDelegate {

    fileprivate let videoAdapter: VideoAdapter
    fileprivate let camera = FrameExtractor()

    var cameraPosition = AVCaptureDevice.Position.front
    let incomingVideoFrame = PublishSubject<UIImage?>()
    let capturedVideoFrame = PublishSubject<UIImage?>()

    private let log = SwiftyBeaver.self
    private var blockOutgoingFrame = true
    private var hardwareAccelerated = true

    fileprivate let disposeBag = DisposeBag()

    init(withVideoAdapter videoAdapter: VideoAdapter) {
        self.videoAdapter = videoAdapter
        VideoAdapter.delegate = self
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

    private func enumerateVideoInputDevices() {
        do {
            try camera.configureSession(withPosition: AVCaptureDevice.Position.front, withOrientation: AVCaptureVideoOrientation.portrait)
            self.log.debug("Camera successfully configured")
            let frontLandscapeCameraDevInfo: [String: String] = try camera.getDeviceInfo(forPosition: AVCaptureDevice.Position.front, orientation: .landscapeLeft)
            let frontPortraitCameraDevInfo: [String: String] = try camera.getDeviceInfo(forPosition: AVCaptureDevice.Position.front, orientation: .portrait)
            videoAdapter.addVideoDevice(withName: camera.nameLandscape, withDevInfo: frontLandscapeCameraDevInfo)
            videoAdapter.addVideoDevice(withName: camera.namePortrait, withDevInfo: frontPortraitCameraDevInfo)

        } catch let e as VideoError {
            self.log.error("Error during capture device enumeration: \(e)")
        } catch {
            self.log.error("Unkonwn error configuring capture device")
        }
    }

    func switchCamera() {
        self.camera.switchCamera()
            .subscribe(onCompleted: {
            print ("camera switched")
        }, onError: { error in
            print(error)
        }).disposed(by: self.disposeBag)
    }

    func setCameraOrientation(orientation: UIDeviceOrientation, callID: String?) {
        var newOrientation: AVCaptureVideoOrientation
        switch orientation {
        case .portrait:
            newOrientation = AVCaptureVideoOrientation.portrait
        case .portraitUpsideDown:
            newOrientation = AVCaptureVideoOrientation.portraitUpsideDown
        case .landscapeLeft:
            newOrientation = AVCaptureVideoOrientation.landscapeRight
        case .landscapeRight:
            newOrientation = AVCaptureVideoOrientation.landscapeLeft
        default:
            newOrientation = AVCaptureVideoOrientation.portrait
        }
        if newOrientation == camera.getOrientation {
            self.log.warning("no orientation change required")
            return
        }
        self.blockOutgoingFrame = true
        let deviceName: String =
            (orientation == .landscapeLeft || orientation == .landscapeRight) ?
                self.camera.nameLandscape : self.camera.namePortrait
        self.switchInput(toDevice: self.camera.nameCamera + deviceName, callID: callID)
        self.camera.rotateCamera(orientation: newOrientation)
            .subscribe(onCompleted: { [unowned self] in
                self.log.debug("new camera orientation isPortrait: \(orientation.isPortrait)")
            }, onError: { error in
                self.log.debug("camera re-orientation error: \(error)")
            }).disposed(by: self.disposeBag)
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

    func decodingStarted(withRendererId rendererId: String, withWidth width: Int, withHeight height: Int) {
        self.log.debug("Decoding started...")
        videoAdapter.registerSinkTarget(withSinkId: rendererId, withWidth: width, withHeight: height)
    }

    func decodingStopped(withRendererId rendererId: String) {
        self.log.debug("Decoding stopped...")
        videoAdapter.removeSinkTarget(withSinkId: rendererId)
    }

    func startCapture(withDevice device: String) {
        self.log.debug("Capture started...")
        self.hardwareAccelerated = videoAdapter.getEncodingAccelerated()
        self.camera.startCapturing()
        self.blockOutgoingFrame = false
    }

    func startVideoCaptureBeforeCall() {
        self.camera.startCapturing()
    }

    func stopCapture() {
        self.log.debug("Capture stopped...")
        self.camera.stopCapturing()
    }

    func writeFrame(withImage image: UIImage?) {
        self.incomingVideoFrame.onNext(image)
    }

    func captured(imageBuffer: CVImageBuffer?, image: UIImage) {
        self.capturedVideoFrame.onNext(image)
        if self.blockOutgoingFrame {
            return
        }
        if self.hardwareAccelerated {
            videoAdapter.writeOutgoingHardwareDecodedFrame(with: imageBuffer)
            return
        }
        videoAdapter.writeOutgoingFrame(with: image)
    }
}
