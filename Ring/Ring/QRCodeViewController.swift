/*
 *  Copyright (C) 2016 Savoir-faire Linux Inc.
 *
 *  Author: Edric Ladent-Milaret <edric.ladent-milaret@savoirfairelinux.com>
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

import UIKit
import AVFoundation
import CoreData

class QRCodeViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {

    // MARK: - Properties
    var captureSession: AVCaptureSession?
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    var qrCodeFrameView: UIView?

    // MARK: - UIViewController
    override func viewDidLoad() {
        super.viewDidLoad()

        let captureDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)

        do {
            let input = try AVCaptureDeviceInput(device: captureDevice)

            captureSession = AVCaptureSession()
            captureSession?.addInput(input as AVCaptureInput)

            let captureMetadataOutput = AVCaptureMetadataOutput()
            captureSession?.addOutput(captureMetadataOutput)

            captureMetadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            captureMetadataOutput.metadataObjectTypes = [AVMetadataObjectTypeQRCode]

            videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            videoPreviewLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
            videoPreviewLayer?.frame = view.layer.bounds
            view.layer.addSublayer(videoPreviewLayer!)

            qrCodeFrameView = UIView()
            qrCodeFrameView?.layer.borderColor = UIColor.green.cgColor
            qrCodeFrameView?.layer.borderWidth = 2
            view.addSubview(qrCodeFrameView!)
            view.bringSubview(toFront: qrCodeFrameView!)

            captureSession?.startRunning()

        } catch {
            // TODO: Handle that correctly
            print("Error Opening Capture input")
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - AVCaptureMetadataOutputObjectsDelegate
    func captureOutput(_ captureOutput: AVCaptureOutput!,
        didOutputMetadataObjects metadataObjects: [Any]!,
        from connection: AVCaptureConnection!) {

            if metadataObjects == nil || metadataObjects.count == 0 {
                qrCodeFrameView?.frame = CGRect.zero
                return
            }

            let metadataObj = metadataObjects[0] as! AVMetadataMachineReadableCodeObject

            if metadataObj.type == AVMetadataObjectTypeQRCode {
                let barCodeObject = videoPreviewLayer?.transformedMetadataObject(for: metadataObj as AVMetadataMachineReadableCodeObject) as! AVMetadataMachineReadableCodeObject
                qrCodeFrameView?.frame = barCodeObject.bounds;

                if metadataObj.stringValue != nil {
                    let predicate = NSPredicate(format: "uri == %@", metadataObj.stringValue)
                    Table<Contact>.createIfNotExist(predicate) {
                        $0.uri = metadataObj.stringValue
                        $0.lastUsed = Date().timeIntervalSince1970 as NSNumber?
                    }
                }
            }
            self.navigationController?.popViewController(animated: true)
    }
}
