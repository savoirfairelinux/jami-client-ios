/*
 *  Copyright (C) 2018-2019 Savoir-faire Linux Inc.
 *
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

import AudioToolbox
import AVFoundation
import Reusable
import RxSwift
import UIKit

class ScanViewController: UIViewController, StoryboardBased, AVCaptureMetadataOutputObjectsDelegate,
                          ViewModelBased {
    // MARK: outlets

    @IBOutlet var header: UIView!
    @IBOutlet var scanImage: UIImageView!
    @IBOutlet var searchTitle: UILabel!
    @IBOutlet var bottomMarginTitleConstraint: NSLayoutConstraint!
    @IBOutlet var bottomCloseButtonConstraint: NSLayoutConstraint!
    let disposeBag = DisposeBag()
    var onCodeScanned: ((String) -> Void)?

    // MARK: variables

    let systemSoundId: SystemSoundID = 1016

    typealias VMType = ScanViewModel

    var scannedQrCode: Bool = false
    // captureSession manages capture activity and coordinates between input device and captures
    // outputs
    var captureSession: AVCaptureSession?
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    var viewModel: ScanViewModel!
    // Empty Rectangle with border to outline detected QR or BarCode
    lazy var codeFrame: UIView = {
        let cFrame = UIView()
        cFrame.layer.borderColor = UIColor.cyan.cgColor
        cFrame.layer.borderWidth = 2
        cFrame.layer.cornerRadius = 4
        cFrame.frame = CGRect.zero
        cFrame.translatesAutoresizingMaskIntoConstraints = false
        return cFrame
    }()

    // MARK: functions

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        captureSession?.stopRunning()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if UIDevice.current.hasNotch {
            bottomMarginTitleConstraint.constant = 45
            bottomCloseButtonConstraint.constant = 17
        } else {
            bottomMarginTitleConstraint.constant = 35
            bottomCloseButtonConstraint.constant = 25
        }
        // AVCaptureDevice allows us to reference a physical capture device (video in our case)
        let captureDevice = AVCaptureDevice.default(for: AVMediaType.video)

        if let captureDevice = captureDevice {
            do {
                captureSession = AVCaptureSession()

                // CaptureSession needs an input to capture Data from
                let input = try AVCaptureDeviceInput(device: captureDevice)
                captureSession?.addInput(input)

                // CaptureSession needs and output to transfer Data to
                let captureMetadataOutput = AVCaptureMetadataOutput()
                captureSession?.addOutput(captureMetadataOutput)

                // We tell our Output the expected Meta-data type
                captureMetadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                captureMetadataOutput.metadataObjectTypes = [
                    .code128,
                    .qr,
                    .ean13,
                    .ean8,
                    .code39,
                    .upce,
                    .aztec,
                    .pdf417
                ]

                // The videoPreviewLayer displays video in conjunction with the captureSession
                videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
                if videoPreviewLayer?.connection?.isVideoMirroringSupported ?? false {
                    videoPreviewLayer?.connection?.automaticallyAdjustsVideoMirroring = false
                    videoPreviewLayer?.connection?.isVideoMirrored = false
                }
                videoPreviewLayer?.videoGravity = .resizeAspectFill
                videoPreviewLayer?.frame = view.bounds
                searchTitle.text = L10n.Global.search
                view.layer.addSublayer(videoPreviewLayer!)
                view.bringSubviewToFront(header)
                view.bringSubviewToFront(scanImage)
                DispatchQueue.global(qos: .background).async { [weak self] in
                    self?.captureSession?.startRunning()
                }
            } catch { print("Error") }
        }
        updateOrientation()
        NotificationCenter.default.rx
            .notification(UIDevice.orientationDidChangeNotification)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                guard let self = self,
                      UIDevice.current.portraitOrLandscape else { return }
                self.videoPreviewLayer?.frame = self.view.bounds
                self.updateOrientation()
                self.view.layoutSubviews()
                self.view.layer.layoutSublayers()
            })
            .disposed(by: disposeBag)
    }

    func updateOrientation() {
        if videoPreviewLayer?.connection!.isVideoOrientationSupported ?? false {
            let orientation: UIDeviceOrientation = UIDevice.current.orientation
            var cameraOrientation = AVCaptureVideoOrientation.portrait
            switch orientation {
            case .landscapeRight:
                cameraOrientation = AVCaptureVideoOrientation.landscapeLeft
            case .landscapeLeft:
                cameraOrientation = AVCaptureVideoOrientation.landscapeRight
            case .portraitUpsideDown:
                cameraOrientation = AVCaptureVideoOrientation.portraitUpsideDown
            default:
                cameraOrientation = AVCaptureVideoOrientation.portrait
            }
            videoPreviewLayer?.connection?.videoOrientation = cameraOrientation
        }
    }

    // the metadataOutput function informs our delegate (the ScanViewController) that the
    // captureOutput emitted a new metaData Object
    func metadataOutput(
        _: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from _: AVCaptureConnection
    ) {
        if !scannedQrCode {
            if metadataObjects.isEmpty {
                print("no objects returned")
                return
            }
            guard let metaDataObject = metadataObjects[0] as? AVMetadataMachineReadableCodeObject
            else { return }
            guard let stringCodeValue = metaDataObject.stringValue else {
                return
            }

            view.addSubview(codeFrame)

            // transformedMetaDataObject returns layer coordinates/height/width from visual
            // properties
            guard let metaDataCoordinates = videoPreviewLayer?
                    .transformedMetadataObject(for: metaDataObject)
            else {
                return
            }

            // Those coordinates are assigned to our codeFrame
            codeFrame.frame = metaDataCoordinates.bounds

            guard let jamiId = stringCodeValue.components(separatedBy: "http://").last else {
                let alert = UIAlertController(
                    title: L10n.Scan.badQrCode,
                    message: "",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: L10n.Global.ok, style: .default, handler: nil))
                present(alert, animated: true, completion: nil)
                return
            }

            if jamiId.isSHA1() {
                AudioServicesPlayAlertSound(systemSoundId)
                print("jamiId : " + jamiId)
                onCodeScanned?(jamiId)
                scannedQrCode = true
            } else {
                let alert = UIAlertController(
                    title: L10n.Scan.badQrCode,
                    message: "",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: L10n.Global.ok, style: .default, handler: nil))
                present(alert, animated: true, completion: nil)
            }
        }
    }

    @IBAction func closeScan(_: Any) {
        dismiss(animated: true, completion: nil)
    }
}
