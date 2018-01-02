/*
 *  Copyright (C) 2018 Savoir-faire Linux Inc.
 *
 *  Author: Andreas Traczyk <andreas.traczyk@savoirfairelinux.com>
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
    func captured(image: UIImage)
}

class FrameExtractor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    private let log = SwiftyBeaver.self

    private let quality = AVCaptureSession.Preset.medium

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

    func getDeviceInfo(forPosition position: AVCaptureDevice.Position) throws -> DeviceInfo {
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
        let devInfo: DeviceInfo = ["format": "NV12",
                                   "width": String(dimensions.height),
                                   "height": String(dimensions.width),
                                   "rate": String(bestRate)]
        return devInfo
    }

    func startCapturing() {
        sessionQueue.async { [unowned self] in
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

    func configureSession(withPosition position: AVCaptureDevice.Position) throws {
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
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "sample buffer"))
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
        connection.videoOrientation = .portrait
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
            self.captureSession.addInput(newVideoInput)
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
        guard let uiImage = imageFromSampleBuffer(sampleBuffer: sampleBuffer) else { return }
        DispatchQueue.main.async { [unowned self] in
            self.delegate?.captured(image: uiImage)
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
            try camera.configureSession(withPosition: AVCaptureDevice.Position.front)
            self.log.debug("Camera successfully configured")
            let frontCameraDevInfo: [String: String] = try camera.getDeviceInfo(forPosition: AVCaptureDevice.Position.front)
            self.log.debug("Camera device info: \(frontCameraDevInfo as AnyObject)")
            videoAdapter.addVideoDevice(withName: "frontCamera", withDevInfo: frontCameraDevInfo)
        } catch let e as VideoError {
            self.log.error("Error during capture device enumeration: \(e)")
        } catch {
            self.log.error("Unkonwn error configuring capture device")
        }
    }
}

extension VideoService: VideoAdapterDelegate {
    func switchInput(toDevice device: String) {
        videoAdapter.switchInput(device)
    }

    func setDecodingAccelerated(withState state: Bool) {
        videoAdapter.setDecodingAccelerated(false)
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
        self.camera.startCapturing()
    }

    func stopCapture() {
        self.log.debug("Capture stopped...")
        self.camera.stopCapturing()
    }

    func writeFrame(withImage image: UIImage?) {
        self.incomingVideoFrame.onNext(image)
    }

    func captured(image: UIImage) {
        videoAdapter.writeOutgoingFrame(with: image)
        self.capturedVideoFrame.onNext(image)
    }

}
