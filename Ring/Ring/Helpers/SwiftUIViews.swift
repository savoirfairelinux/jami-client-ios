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

enum IndicatorOrientation {
    case vertical
    case horizontal
}

struct Indicator: View {
    let orientation: IndicatorOrientation

    var body: some View {
        RoundedRectangle(cornerRadius: ActionsConstants.indicatorHeight / 2)
            .fill(Color.white.opacity(0.6))
            .frame(
                width: orientation == .horizontal ? 60 : ActionsConstants.indicatorHeight,
                height: orientation == .horizontal ? ActionsConstants.indicatorHeight : 60
            )
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
    let placeholder: String
    let leadingInset: CGFloat
    let trailingInset: CGFloat
    @Binding var text: String
    @Binding var isFocused: Bool
    @Binding var dynamicHeight: CGFloat
    let maxHeight: CGFloat = 100

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isScrollEnabled = true
        textView.textAlignment = .left
        textView.font = UIFont.preferredFont(forTextStyle: .callout)
        textView.textContainerInset = UIEdgeInsets(top: 12, left: leadingInset, bottom: 12, right: trailingInset)
        textView.textContainer.lineFragmentPadding = 0
        textView.adjustsFontForContentSizeCategory = true
        if withBackground {
            textView.backgroundColor = .clear
            textView.layer.cornerRadius = 0
        }
        textView.clipsToBounds = true
        textView.delegate = context.coordinator
        context.coordinator.configurePlaceholder(in: textView)

        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        context.coordinator.updatePlaceholder(in: uiView)

        DispatchQueue.main.async {
            if self.isFocused && !uiView.isFirstResponder {
                uiView.becomeFirstResponder()
            } else if !self.isFocused && uiView.isFirstResponder {
                uiView.resignFirstResponder()
            }
            dynamicHeight = min(uiView.sizeThatFits(CGSize(width: uiView.frame.size.width, height: .infinity)).height, maxHeight)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: UITextViewWrapper
        private let placeholderLabel = UILabel()

        init(_ textViewWrapper: UITextViewWrapper) {
            self.parent = textViewWrapper
        }

        func configurePlaceholder(in textView: UITextView) {
            placeholderLabel.numberOfLines = 1
            placeholderLabel.lineBreakMode = .byTruncatingTail
            placeholderLabel.adjustsFontForContentSizeCategory = true
            placeholderLabel.isUserInteractionEnabled = false
            textView.addSubview(placeholderLabel)
            updatePlaceholder(in: textView)
        }

        func updatePlaceholder(in textView: UITextView) {
            placeholderLabel.text = parent.placeholder
            placeholderLabel.font = textView.font
            placeholderLabel.textColor = .placeholderText
            placeholderLabel.isHidden = !textView.text.isEmpty

            let linePadding = textView.textContainer.lineFragmentPadding
            let textStartX = textView.textContainerInset.left + linePadding
            let yPosition = textView.textContainerInset.top
            let maxWidth = textView.bounds.width
                - textStartX
                - textView.textContainerInset.right
                - linePadding
            placeholderLabel.frame = CGRect(
                x: textStartX,
                y: yPosition,
                width: max(0, maxWidth),
                height: placeholderLabel.intrinsicContentSize.height
            )
        }

        func textViewDidChange(_ textView: UITextView) {
            self.parent.text = textView.text
            updatePlaceholder(in: textView)
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.isFocused = true
            updatePlaceholder(in: textView)
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            parent.isFocused = false
            updatePlaceholder(in: textView)
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
        private var lastScannedCode: String?

        init(parent: QRCodeScannerView) {
            self.parent = parent
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput,
                            didOutput metadataObjects: [AVMetadataObject],
                            from connection: AVCaptureConnection) {
            guard let metadataObject = metadataObjects.first,
                  let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
                  let stringValue = readableObject.stringValue else {
                return
            }

            guard stringValue != lastScannedCode else { return }
            lastScannedCode = stringValue

            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            parent.didFindCode(stringValue)
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
