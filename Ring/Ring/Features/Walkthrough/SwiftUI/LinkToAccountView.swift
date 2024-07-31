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
        ZStack {
            HStack {
                cancelButton
                Spacer()
                linkButton
            }
            Text(L10n.LinkToAccount.linkDeviceTitle)
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
        ScanQRCodeView(width: 350, height: 280) { pin in
            self.pin = pin
            self.scannedCode = pin
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
        CreateAccountTextEditView(text: $pin, placeholder: L10n.LinkToAccount.pinLabel)
    }

    private var passwordView: some View {
        VStack {
            Text(L10n.LinkToAccount.passwordExplanation)
                .padding(.top)
            CreateAccountPasswordView(text: $password, placeholder: L10n.Global.password)
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
