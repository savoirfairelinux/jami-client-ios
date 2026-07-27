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

enum CameraError: Error {
    case permissionDenied
    case deviceUnavailable
    case configurationFailed
}

enum CameraDevice {
    static let medium = "mediumCamera"
    static let high = "1280_720Camera"
}

/// Desired camera ownership and quality. `CameraCapturer` mutates this only
/// on its session queue, then reconciles the `AVCaptureSession` once per intent.
struct CameraCaptureState {
    private var previewActive = false
    private var daemonActive = false
    private var previewQuality = AVCaptureSession.Preset.high
    private var daemonQuality: AVCaptureSession.Preset?

    var shouldRun: Bool {
        return previewActive || daemonActive
    }

    var quality: AVCaptureSession.Preset {
        return daemonQuality ?? previewQuality
    }

    mutating func setPreview(active: Bool, quality: AVCaptureSession.Preset?) {
        previewActive = active
        if let quality = quality {
            previewQuality = quality
        }
    }

    mutating func setDaemon(active: Bool, quality: AVCaptureSession.Preset?) {
        daemonActive = active
        daemonQuality = active ? quality : nil
    }
}

/// Owns the AVCaptureSession. All session work runs asynchronously on one
/// serial queue.
final class CameraCapturer: NSObject, @unchecked Sendable {

    /// Captured frames, delivered on the session queue.
    var onFrame: ((_ imageBuffer: CVImageBuffer?, _ sampleBuffer: CMSampleBuffer) -> Void)?
    var onPositionChanged: ((AVCaptureDevice.Position) -> Void)?

    private let sessionQueue = DispatchQueue(label: "com.savoirfairelinux.jami.camera")
    private let captureSession = AVCaptureSession()
    private var systemPressureObservation: NSKeyValueObservation?

    private var captureState = CameraCaptureState()
    private var position = AVCaptureDevice.Position.front
    private let connectionOrientation = AVCaptureVideoOrientation.landscapeLeft

    // MARK: - Permission

    func ensurePermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    continuation.resume(returning: granted)
                }
            }
        default:
            return false
        }
    }

    // MARK: - Configuration

    /// Configures inputs/outputs for the front camera. Runs on the
    /// session queue; awaits completion.
    func configure() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionQueue.async { [weak self] in
                guard let self = self else {
                    return continuation.resume(throwing: CameraError.configurationFailed)
                }
                do {
                    try self.performConfiguration()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// libjami device descriptors for registration (`addVideoDevice`).
    func deviceInfo(quality: AVCaptureSession.Preset) async throws -> [String: String] {
        try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async { [weak self] in
                guard let self = self,
                      let device = self.selectDevice(position: self.position) else {
                    return continuation.resume(throwing: CameraError.deviceUnavailable)
                }
                self.captureSession.sessionPreset = quality
                let dimensions = CMVideoFormatDescriptionGetDimensions(
                    device.activeFormat.formatDescription)
                continuation.resume(returning: [
                    "format": "BGRA",
                    "width": String(dimensions.width),
                    "height": String(dimensions.height),
                    "rate": String(Int(Framerate.high.rawValue))
                ])
            }
        }
    }

    // MARK: - Start / stop / switch

    func setPreviewCapture(active: Bool, quality: AVCaptureSession.Preset? = nil) {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.captureState.setPreview(active: active, quality: quality)
            self.reconcileCaptureState()
        }
    }

    func setDaemonCapture(active: Bool, quality: AVCaptureSession.Preset? = nil) {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.captureState.setDaemon(active: active, quality: quality)
            self.reconcileCaptureState()
        }
    }

    func currentQuality() async -> AVCaptureSession.Preset {
        await withCheckedContinuation { continuation in
            sessionQueue.async { [weak self] in
                continuation.resume(returning: self?.captureState.quality ?? .high)
            }
        }
    }

    func switchCamera() async throws -> AVCaptureDevice.Position {
        try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async { [weak self] in
                guard let self = self else {
                    return continuation.resume(throwing: CameraError.configurationFailed)
                }
                do {
                    let position = try self.performSwitchCamera()
                    continuation.resume(returning: position)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Returns capture to the front camera, so a session that ended on the
    /// back camera doesn't carry that choice into the next one.
    func resetToFrontCamera() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            sessionQueue.async { [weak self] in
                guard let self = self, self.position != .front else {
                    return continuation.resume()
                }
                do {
                    try self.performSelectCamera(position: .front)
                } catch {
                    NSLog("CameraCapturer: front camera reset failed: %@",
                          error.localizedDescription)
                }
                continuation.resume()
            }
        }
    }

    // MARK: - Session-queue internals

    private func performConfiguration() throws {
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        captureSession.inputs.forEach(captureSession.removeInput)
        captureSession.outputs.forEach(captureSession.removeOutput)
        captureSession.sessionPreset = captureState.quality

        guard let device = selectDevice(position: position) else {
            throw CameraError.deviceUnavailable
        }
        observeSystemPressure(device: device)

        if #available(iOS 16.0, *), captureSession.isMultitaskingCameraAccessSupported {
            captureSession.isMultitaskingCameraAccessEnabled = true
        }

        let input = try AVCaptureDeviceInput(device: device)
        guard captureSession.canAddInput(input) else {
            throw CameraError.configurationFailed
        }
        captureSession.addInput(input)

        let output = AVCaptureVideoDataOutput()
        if output.availableVideoPixelFormatTypes
            .contains(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange) {
            output.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String:
                    kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
            ]
        }
        output.setSampleBufferDelegate(self, queue: sessionQueue)
        guard captureSession.canAddOutput(output) else {
            throw CameraError.configurationFailed
        }
        captureSession.addOutput(output)

        try configureOutputConnection()
    }

    private func performSwitchCamera() throws -> AVCaptureDevice.Position {
        guard let currentInput = captureSession.inputs.first as? AVCaptureDeviceInput else {
            throw CameraError.configurationFailed
        }
        let newPosition: AVCaptureDevice.Position =
            currentInput.device.position == .back ? .front : .back
        try performSelectCamera(position: newPosition)
        return newPosition
    }

    private func reconcileCaptureState() {
        let quality = captureState.quality
        if captureSession.sessionPreset != quality,
           captureSession.canSetSessionPreset(quality) {
            captureSession.beginConfiguration()
            captureSession.sessionPreset = quality
            captureSession.commitConfiguration()
        }

        if captureState.shouldRun {
            if !captureSession.isRunning {
                captureSession.startRunning()
            }
        } else if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }

    private func performSelectCamera(position newPosition: AVCaptureDevice.Position) throws {
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        guard let newDevice = selectDevice(position: newPosition) else {
            throw CameraError.deviceUnavailable
        }
        if let currentInput = captureSession.inputs.first as? AVCaptureDeviceInput {
            captureSession.removeInput(currentInput)
        }
        observeSystemPressure(device: newDevice)

        let newInput = try AVCaptureDeviceInput(device: newDevice)
        guard captureSession.canAddInput(newInput) else {
            throw CameraError.configurationFailed
        }
        captureSession.addInput(newInput)
        try configureOutputConnection()

        position = newPosition
        onPositionChanged?(newPosition)
    }

    /// Pins mirroring so the buffer orientation is deterministic across
    /// camera switches; visual mirroring for the front preview is applied
    /// by the renderer transform.
    private func configureOutputConnection() throws {
        guard let connection = captureSession.outputs.first?.connection(with: .video),
              connection.isVideoOrientationSupported,
              connection.isVideoMirroringSupported else {
            throw CameraError.configurationFailed
        }
        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = false
        connection.videoOrientation = connectionOrientation
    }

    private func selectDevice(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        return AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera],
                                                mediaType: .video,
                                                position: position).devices.first
    }

    // MARK: - Thermal pressure

    private enum Framerate: CGFloat {
        case high = 30
        case medium = 20
        case low = 15
    }

    private func observeSystemPressure(device: AVCaptureDevice) {
        setFramerate(device: device, framerate: Framerate.high.rawValue)
        systemPressureObservation = device.observe(\.systemPressureState, options: .new) {
            [weak self, weak device] _, change in
            guard let self = self, let device = device,
                  let level = change.newValue?.level else { return }
            self.sessionQueue.async {
                switch level {
                case .nominal:
                    self.setFramerate(device: device, framerate: Framerate.high.rawValue)
                case .fair:
                    self.setFramerate(device: device, framerate: Framerate.medium.rawValue)
                case .serious, .critical:
                    self.setFramerate(device: device, framerate: Framerate.low.rawValue)
                case .shutdown:
                    self.captureSession.stopRunning()
                default:
                    break
                }
            }
        }
    }

    private func setFramerate(device: AVCaptureDevice, framerate: CGFloat) {
        let supported = device.activeFormat.videoSupportedFrameRateRanges.contains {
            $0.maxFrameRate >= framerate && $0.minFrameRate <= framerate
        }
        guard supported else { return }
        let duration = CMTimeMake(value: 1, timescale: Int32(framerate))
        guard device.activeVideoMinFrameDuration != duration
                || device.activeVideoMaxFrameDuration != duration else { return }
        do {
            try device.lockForConfiguration()
            device.activeVideoMinFrameDuration = duration
            device.activeVideoMaxFrameDuration = duration
            device.unlockForConfiguration()
        } catch {
            NSLog("CameraCapturer: framerate configuration failed: %@",
                  error.localizedDescription)
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraCapturer: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        onFrame?(CMSampleBufferGetImageBuffer(sampleBuffer), sampleBuffer)
    }
}

struct CameraOrientationState: Equatable {

    let orientation: AVCaptureVideoOrientation
    let cameraPosition: AVCaptureDevice.Position
    let layerTransform: CGAffineTransform
    let imageOrientation: UIImage.Orientation
    let outgoingAngle: Int

    static func make(orientation: AVCaptureVideoOrientation,
                     cameraPosition: AVCaptureDevice.Position) -> CameraOrientationState {
        let mirrored = cameraPosition == .front
        return CameraOrientationState(
            orientation: orientation,
            cameraPosition: cameraPosition,
            layerTransform: orientation.localPreviewTransform(mirrored: mirrored),
            imageOrientation: orientation.imageOrientation(mirrored: mirrored),
            outgoingAngle: outgoingAngle(orientation: orientation,
                                         cameraPosition: cameraPosition))
    }

    private static func outgoingAngle(orientation: AVCaptureVideoOrientation,
                                      cameraPosition: AVCaptureDevice.Position) -> Int {
        switch orientation {
        case .portrait:
            return cameraPosition == .front ? 270 : 90
        case .portraitUpsideDown:
            return cameraPosition == .front ? 90 : 270
        case .landscapeLeft:
            return 180
        default:
            return 0
        }
    }
}
