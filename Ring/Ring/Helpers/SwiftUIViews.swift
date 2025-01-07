/*
 *  Copyright (C) 2023 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
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

import SwiftUI

let screenWidth = UIScreen.main.bounds.size.width
let screenHeight = UIScreen.main.bounds.size.height

enum IndicatorOrientation {
    case vertical
    case horizontal
}

struct Indicator: View {
    let orientation: IndicatorOrientation

    var body: some View {
        switch orientation {
        case .vertical:
            RoundedRectangle(cornerRadius: 5)
                .fill(Color(UIColor.lightGray))
                .frame(width: 5, height: 60)
        case .horizontal:
            RoundedRectangle(cornerRadius: 5)
                .fill(Color(UIColor.lightGray))
                .frame(width: 60, height: 5)
        }
    }
}

struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

struct MeasureSizeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(GeometryReader { geometry in
                Color.clear.preference(key: SizePreferenceKey.self, value: geometry.size)
            })
    }
}

struct UITextViewWrapper: UIViewRepresentable {
    let withBackground: Bool
    @Binding var text: String
    @Binding var isFocused: Bool
    @Binding var dynamicHeight: CGFloat
    let maxHeight: CGFloat = 100

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isScrollEnabled = true
        textView.textAlignment = .left
        textView.font = UIFont.systemFont(ofSize: UIFont.preferredFont(forTextStyle: .callout).pointSize)
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        if withBackground {
            textView.backgroundColor = UIColor.secondarySystemBackground
            textView.layer.cornerRadius = 18
        }
        textView.clipsToBounds = true
        textView.delegate = context.coordinator
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.text = text

        DispatchQueue.main.async {
            if self.isFocused && !uiView.isFirstResponder {
                uiView.becomeFirstResponder()
            }
            dynamicHeight = min(uiView.sizeThatFits(CGSize(width: uiView.frame.size.width, height: .infinity)).height, maxHeight)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: UITextViewWrapper

        init(_ textViewWrapper: UITextViewWrapper) {
            self.parent = textViewWrapper
        }

        func textViewDidChange(_ textView: UITextView) {
            self.parent.text = textView.text
        }
    }
}

struct QRCodeScannerView: UIViewControllerRepresentable {
    let width: CGFloat
    let height: CGFloat
    var didFindCode: (String) -> Void

    var previewLayer = AVCaptureVideoPreviewLayer()

    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        var parent: QRCodeScannerView

        init(parent: QRCodeScannerView) {
            self.parent = parent
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput,
                            didOutput metadataObjects: [AVMetadataObject],
                            from connection: AVCaptureConnection) {
            if let metadataObject = metadataObjects.first,
               let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
               let stringValue = readableObject.stringValue {
                AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
                parent.didFindCode(stringValue)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        let session = AVCaptureSession()

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            showCameraDisabledMessage(in: viewController)
            return viewController
        }

        do {
            let videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
            if session.canAddInput(videoInput) {
                session.addInput(videoInput)
            } else {
                showCameraDisabledMessage(in: viewController)
                return viewController
            }
        } catch {
            showCameraDisabledMessage(in: viewController)
            return viewController
        }

        let metadataOutput = AVCaptureMetadataOutput()
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(context.coordinator, queue: .main)
            metadataOutput.metadataObjectTypes = [.qr]
            metadataOutput.rectOfInterest = CGRect(x: 0, y: 0, width: width, height: height)
        } else {
            showCameraDisabledMessage(in: viewController)
            return viewController
        }

        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill

        previewLayer.frame = viewController.view.bounds
        viewController.view.layer.addSublayer(previewLayer)

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }

        return viewController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        previewLayer.frame = uiViewController.view.bounds

        if let connection = previewLayer.connection, connection.isVideoOrientationSupported {
            connection.videoOrientation = AVCaptureVideoOrientation(ScreenHelper.currentOrientation())
        }
    }

    private func showCameraDisabledMessage(in viewController: UIViewController) {
        viewController.view.backgroundColor = .black
        let label = UILabel()
        label.text = L10n.Global.cameraDisabled
        label.numberOfLines = 0
        label.textColor = .white
        label.textAlignment = .center
        label.frame = CGRect(x: 20, y: 0, width: width - 40, height: height)
        viewController.view.addSubview(label)
    }
}

extension AVCaptureVideoOrientation {
    init(_ orientation: UIInterfaceOrientation) {
        switch orientation {
        case .portrait:
            self = .portrait
        case .portraitUpsideDown:
            self = .portraitUpsideDown
        case .landscapeLeft:
            // If you are seeing an upside-down preview in landscape,
            // switch this to .landscapeLeft
            self = .landscapeLeft
        case .landscapeRight:
            self = .landscapeRight
        case .unknown:
            self = .portrait
        @unknown default:
            self = .portrait
        }
    }
}

struct CommonButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundColor(Color(UIColor.label))
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Color.jamiTertiaryControl)
            .cornerRadius(10)
    }
}

extension View {
    func commonButtonStyle() -> some View {
        self.modifier(CommonButtonStyle())
    }
}
