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
    let linkAction: (_ pin: String, _ password: String) -> Void
    @SwiftUI.State private var password: String = ""
    @SwiftUI.State private var pin: String = ""
    @SwiftUI.State private var scannedCode: String?
    @SwiftUI.State private var animatableScanSwitch: Bool = true
    @SwiftUI.State private var notAnimatableScanSwitch: Bool = true

    @Environment(\.verticalSizeClass) var verticalSizeClass

    var body: some View {
        VStack {
            header
            if verticalSizeClass != .regular {
                landscapeView
            } else {
                portraitView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.secondarySystemBackground).ignoresSafeArea())
    }

    private var header: some View {
        HStack {
            cancelButton
            Spacer()
            Text(L10n.LinkToAccount.linkDeviceTitle)
            Spacer()
            linkButton
        }
        .padding()
    }

    private var portraitView: some View {
        ScrollView(showsIndicators: false) {
            info
            pinSection
        }
    }

    private var landscapeView: some View {
        HStack(spacing: 30) {
            VStack {
                Spacer().frame(height: 50)
                info
                Spacer()
            }
            ScrollView(showsIndicators: false) {
                pinSection
            }
        }
    }

    private var info: some View {
        VStack {
            Text(L10n.LinkToAccount.explanationMessage)
                .font(.headline)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 500)
                .padding(.horizontal)
            HStack {
                Text(L10n.LinkToAccount.pinPlaceholder + ":")
                Text(pin)
                    .foregroundColor(.green)
            }
            .padding()
        }
    }

    private var scanQRCodeView: some View {
        ZStack {
            QRCodeScannerView {
                self.pin = $0
                self.scannedCode = $0
            }
            .frame(width: 350, height: 350)
            .cornerRadius(12)
            QRCodeScannerOverlayView()
                .frame(width: 350, height: 350)
        }
    }

    private var pinSection: some View {
        VStack(spacing: 15) {
            if scannedCode == nil {
                pinSwitchButtons
                if animatableScanSwitch {
                    scanQRCodeView
                } else {
                    manualEntryPinView
                }
            }
            passwordView
        }
        .frame(minWidth: 350, maxWidth: 500)
        .padding(.horizontal)
    }

    private var pinSwitchButtons: some View {
        HStack {
            switchButton(text: L10n.LinkToAccount.scanQRCode, isHeadline: notAnimatableScanSwitch, isHighlighted: animatableScanSwitch, transitionEdge: .trailing, action: {
                notAnimatableScanSwitch = true
                withAnimation {
                    animatableScanSwitch = true
                }
            })

            Spacer()

            switchButton(text: L10n.LinkToAccount.pinLabel, isHeadline: !notAnimatableScanSwitch, isHighlighted: !animatableScanSwitch, transitionEdge: .leading, action: {
                notAnimatableScanSwitch = false
                withAnimation {
                    animatableScanSwitch = false
                }
            })
        }
    }

    private func switchButton(text: String, isHeadline: Bool, isHighlighted: Bool, transitionEdge: Edge, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack {
                Text(text)
                    .foregroundColor(Color(UIColor.label))
                    .font(isHeadline ? .headline : .body)
                if isHighlighted {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.black)
                        .frame(height: 1)
                        .padding(.horizontal)
                        .transition(.move(edge: transitionEdge))
                } else {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.clear)
                        .frame(height: 1)
                        .padding(.horizontal)
                        .transition(.move(edge: transitionEdge))
                }
            }
        }
    }

    private var manualEntryPinView: some View {
        VStack {
            TextField(L10n.LinkToAccount.pinLabel, text: $pin)
                .padding(12)
                .background(Color.white)
                .cornerRadius(12)
        }
    }

    private var passwordView: some View {
        VStack {
            Text(L10n.LinkToAccount.passwordExplanation)
                .padding(.top)
            SecureField(L10n.Global.enterPassword, text: $password)
                .padding(12)
                .background(Color.white)
                .cornerRadius(12)
        }
    }

    private var cancelButton: some View {
        Button(action: {
            dismissAction()
        }) {
            Text(L10n.Global.cancel)
                .foregroundColor(Color(UIColor.label))
        }
    }

    private var linkButton: some View {
        Button(action: {
            linkAction(pin, password)
        }) {
            Text(L10n.LinkToAccount.linkButtonTitle)
                .foregroundColor(pin.isEmpty ? Color(UIColor.secondaryLabel) : .jamiColor)
        }
        .disabled(pin.isEmpty )
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
            metadataOutput.rectOfInterest = CGRect(x: 0, y: 0, width: 350, height: 350)
        } else {
            return viewController
        }

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = CGRect(x: 0, y: 0, width: 350, height: 350)
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
