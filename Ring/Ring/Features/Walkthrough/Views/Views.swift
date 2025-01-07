/*
 *  Copyright (C) 2024 Savoir-faire Linux Inc.
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

struct WalkthroughPasswordView: View {
    @Binding var text: String
    var placeholder: String
    var identifier: String = ""

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .foregroundColor(Color(UIColor.secondarySystemGroupedBackground))
            PasswordFieldView(text: $text, placeholder: placeholder)
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
        }
    }
}

struct WalkthroughTextEditView: View {
    @Binding var text: String
    var placeholder: String
    var identifier: String = ""

    var body: some View {
        TextField(placeholder, text: $text)
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
            .autocorrectionDisabled(true)
            .autocapitalization(.none)
            .accessibilityIdentifier(identifier)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(10)
    }
}

struct WalkthroughFocusableTextView: View {
    @Binding var text: String
    @Binding var isTextFieldFocused: Bool
    var placeholder: String
    var identifier: String = ""

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .foregroundColor(Color(UIColor.secondarySystemGroupedBackground))
            FocusableTextField(
                text: $text,
                isFirstResponder: $isTextFieldFocused,
                placeholder: placeholder,
                identifier: identifier
            )
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
        }
    }
}

struct ScanQRCodeView: View {
    let width: CGFloat
    let height: CGFloat
    var onScan: (String) -> Void

    var body: some View {
        ZStack {
            QRCodeScannerView(width: width, height: height, didFindCode: { scannedCode in
                onScan(scannedCode)
            })
            .frame(width: width, height: height)
            .cornerRadius(12)
            QRCodeScannerOverlayView(size: (min(width, height) * 0.5))
                .frame(width: width, height: height)
        }
    }
}

struct QRCodeScannerOverlayView: View {
    let size: CGFloat
    var body: some View {
        GeometryReader { geometry in
            let frameSize: CGFloat = size
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

struct AlertFactory {
    static func alertWithOkButton(title: String,
                                  message: String,
                                  action: @escaping () -> Void) -> some View {
        VStack(spacing: 20) {
            Text(title)
                .font(.headline)
            Text(message)
            HStack {
                Spacer()
                Button(action: action, label: {
                    Text(L10n.Global.ok)
                        .foregroundColor(.jamiColor)
                        .padding(.horizontal)
                })
            }
        }
    }

    static func createLoadingView() -> some View {
        VStack(spacing: 20) {
            Text(L10n.CreateAccount.creatingAccount)
                .font(.headline)
                .padding()
            SwiftUI.ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(2)
                .padding(.bottom, 30)
        }
        .padding()
    }
}
