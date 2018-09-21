//
//  ScanViewController.swift
//  Ring
//
//  Created by Quentin on 2018-09-13.
//  Copyright © 2018 Savoir-faire Linux. All rights reserved.
//

import Reusable
import UIKit
import AVFoundation
import AudioToolbox
import RxSwift

class ScanViewController: UIViewController, StoryboardBased, AVCaptureMetadataOutputObjectsDelegate, ViewModelBased {
    // MARK: outlets
    @IBOutlet weak var header: UIView!
    @IBOutlet weak var scanImage: UIImageView!
    @IBOutlet weak var searchTitle: UILabel!
    
    // MARK: variables
    let systemSoundId: SystemSoundID = 1016
    typealias VMType = ScanViewModel
    var scannedQrCode: Bool = false
    //captureSession manages capture activity and coordinates between input device and captures outputs
    var captureSession: AVCaptureSession?
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    var viewModel: ScanViewModel!
    //Empty Rectangle with border to outline detected QR or BarCode
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
        captureSession?.stopRunning()
    }

    override func viewDidAppear(_ animated: Bool) {
        captureSession?.startRunning()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        UIApplication.shared.statusBarStyle = .lightContent
        //AVCaptureDevice allows us to reference a physical capture device (video in our case)
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

                //We tell our Output the expected Meta-data type
                captureMetadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                captureMetadataOutput.metadataObjectTypes = [.code128, .qr, .ean13, .ean8, .code39, .upce, .aztec, .pdf417]
                //AVMetadataObject.ObjectType

                captureSession?.startRunning()

                //The videoPreviewLayer displays video in conjunction with the captureSession
                videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
                videoPreviewLayer?.videoGravity = .resizeAspectFill
                videoPreviewLayer?.frame = view.layer.bounds
                self.searchTitle.text = L10n.Scan.search
                view.layer.addSublayer(videoPreviewLayer!)
                view.bringSubview(toFront: header)
                view.bringSubview(toFront: self.scanImage)
            } catch { print("Error") }
        }

    }

    // the metadataOutput function informs our delegate (the ScanViewController) that the captureOutput emitted a new metaData Object
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {

        if !self.scannedQrCode {
            if metadataObjects.isEmpty {
                print("no objects returned")
                return
            }
            let metaDataObject = metadataObjects[0] as! AVMetadataMachineReadableCodeObject
            guard let stringCodeValue = metaDataObject.stringValue else {
                return
            }

            view.addSubview(codeFrame)

            //transformedMetaDataObject returns layer coordinates/height/width from visual properties
            guard let metaDataCoordinates = videoPreviewLayer?.transformedMetadataObject(for: metaDataObject) else {
                return
            }

            //Those coordinates are assigned to our codeFrame
            codeFrame.frame = metaDataCoordinates.bounds

            let ringId = stringCodeValue.components(separatedBy: "http://").last!

            if ringId.isSHA1() {
                AudioServicesPlayAlertSound(systemSoundId)
                print("RingId : " + ringId)
                self.dismiss(animated: true, completion: nil)
                self.viewModel.createNewConversation(recipientRingId: ringId)
                self.scannedQrCode = true
            } else {
                let alert = UIAlertController(title: L10n.Scan.badQrCode, message: "", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: L10n.Global.ok, style: .default, handler: nil))
                self.present(alert, animated: true, completion: nil)
            }
        }
    }

    @IBAction func closeScan(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
}
