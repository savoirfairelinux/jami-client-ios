//
//  LinkDeviceView.swift
//  Ring
//
//  Created by kateryna on 2024-07-31.
//  Copyright © 2024 Savoir-faire Linux. All rights reserved.
//

import SwiftUI

struct LinkToAccountView: View {
    let dismissAction: () -> Void
    @SwiftUI.State var value: String = ""
    @SwiftUI.State private var scannedCode: String?
    var body: some View {
        NavigationView {
            VStack {
                ScrollView {
                    Text("A PIN is requered to use an existing Jami account on this device")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .padding()
                    HStack {
                        Text("Provided PIN:")
                        if let scannedCode = scannedCode {
                            Text(scannedCode)
                        }
                    }
                    .padding()
                    if let scannedCode = scannedCode {
                        Text("Rescan qrCode")
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.blue)
                            .cornerRadius(12)
                    } else {
                        VStack {
                            Text("Scan qrCode")
                            ZStack {
                                QRCodeScannerView {
                                    self.scannedCode = $0
                                }
                                .frame(width: 300, height: 300)
                                .cornerRadius(20)
                                QRCodeScannerOverlayView()
                                    .frame(width: 300, height: 300)
                            }
                        }
                    }

                    Text("Or enter pin manually")
                        .padding(.top)

                    TextField("Enter PIN", text: $value)
                        .padding(.horizontal)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Text("Fill if the account password encrypted")
                        .padding(.top)
                    TextField("Enter password", text: $value)
                        .padding(.horizontal)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                Spacer()
            }
            .ignoresSafeArea()
            .background(Color(UIColor.secondarySystemBackground))
            .navigationBarTitle("Link device", displayMode: .inline)
            .navigationBarItems(
                leading: Button(action: {
                    dismissAction()
                }, label: {
                    Text("Cancel")
                        .foregroundColor(Color(UIColor.label))
                }),
                trailing: Button(action: {
                    //                    model.updateProfile()
                    //                    isPresented = false
                }, label: {
                    Text("Import")
                        .foregroundColor(Color(UIColor.label))
                })
            )
        }
    }
}

struct QRCodeScannerOverlayView: View {
    var body: some View {
        GeometryReader { geometry in
            let frameSize: CGFloat = 150
            let cornerLength: CGFloat = 20
            let lineWidth: CGFloat = 4

            let rect = CGRect(
                x: (geometry.size.width - frameSize) / 2,
                y: (geometry.size.height - frameSize) / 2,
                width: frameSize,
                height: frameSize
            )

            Path { path in
                // Top-left corner
                path.move(to: CGPoint(x: rect.minX, y: rect.minY + cornerLength))
                path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.minX + cornerLength, y: rect.minY))

                // Top-right corner
                path.move(to: CGPoint(x: rect.maxX - cornerLength, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cornerLength))

                // Bottom-left corner
                path.move(to: CGPoint(x: rect.minX, y: rect.maxY - cornerLength))
                path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
                path.addLine(to: CGPoint(x: rect.minX + cornerLength, y: rect.maxY))

                // Bottom-right corner
                path.move(to: CGPoint(x: rect.maxX - cornerLength, y: rect.maxY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerLength))
            }
            .stroke(Color.white, lineWidth: lineWidth)
        }
        .background(Color.clear)
    }
}

struct QRCodeScannerView: UIViewControllerRepresentable {
    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        var parent: QRCodeScannerView

        init(parent: QRCodeScannerView) {
            self.parent = parent
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            if let metadataObject = metadataObjects.first {
                guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
                guard let stringValue = readableObject.stringValue else { return }
                AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
                parent.didFindCode(stringValue)
            }
        }
    }

    var didFindCode: (String) -> Void

    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        let session = AVCaptureSession()

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return viewController }
        let videoInput: AVCaptureDeviceInput

        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return viewController
        }

        if session.canAddInput(videoInput) {
            session.addInput(videoInput)
        } else {
            return viewController
        }

        let metadataOutput = AVCaptureMetadataOutput()

        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)

            metadataOutput.setMetadataObjectsDelegate(context.coordinator, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
            metadataOutput.rectOfInterest = CGRect(x: 0, y: 0, width: 300, height: 300)
        } else {
            return viewController
        }

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = CGRect(x: 0, y: 0, width: 300, height: 300)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.cornerRadius = 20
        viewController.view.layer.addSublayer(previewLayer)

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }

        return viewController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
