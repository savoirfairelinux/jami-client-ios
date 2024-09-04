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
    @ObservedObject var viewModel: LinkToAccountViewModel
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
        .background(Color(UIColor.systemGroupedBackground)
                        .ignoresSafeArea()
        )
    }

    private var header: some View {
        ZStack {
            HStack {
                cancelButton
                Spacer()
                linkButton
            }
            Text(L10n.LinkToAccount.linkDeviceTitle)
                .font(.headline)
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
                .multilineTextAlignment(.center)
                .frame(maxWidth: 500)
                .padding(.horizontal)
            HStack {
                Text(L10n.LinkToAccount.pinPlaceholder + ":")
                Text(viewModel.pin)
                    .foregroundColor(Color(UIColor.jamiSuccess))
            }
            .padding()
        }
    }

    private var scanQRCodeView: some View {
        ScanQRCodeView(width: 350, height: 280) { pin in
            viewModel.didScanQRCode(pin)
        }
    }

    private var pinSection: some View {
        VStack(spacing: 15) {
            if viewModel.scannedCode == nil {
                pinSwitchButtons
                if viewModel.animatableScanSwitch {
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
            switchButton(text: L10n.LinkToAccount.scanQRCode,
                         isHeadline: viewModel.notAnimatableScanSwitch,
                         isHighlighted: viewModel.animatableScanSwitch,
                         transitionEdge: .trailing,
                         action: {
                viewModel.switchToQRCode()
            })

            Spacer()

            switchButton(text: L10n.LinkToAccount.pinLabel,
                         isHeadline: !viewModel.notAnimatableScanSwitch,
                         isHighlighted: !viewModel.animatableScanSwitch,
                         transitionEdge: .leading,
                         action: {
                viewModel.switchToManualEntry()
            })
        }
    }

    private func switchButton(text: String,
                              isHeadline: Bool,
                              isHighlighted: Bool,
                              transitionEdge: Edge,
                              action: @escaping () -> Void) -> some View {
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
        WalkthroughTextEditView(text: $viewModel.pin,
                                placeholder: L10n.LinkToAccount.pinLabel)
    }

    private var passwordView: some View {
        VStack {
            Text(L10n.ImportFromArchive.passwordExplanation)
                .multilineTextAlignment(.center)
            WalkthroughPasswordView(text: $viewModel.password, placeholder: L10n.Global.password)
        }
        .padding(.vertical)
    }

    private var cancelButton: some View {
        Button(action: {
            viewModel.dismissView()
        }, label: {
            Text(L10n.Global.cancel)
                .foregroundColor(Color(UIColor.label))
        })
    }

    private var linkButton: some View {
        Button(action: {
            viewModel.link()
        }, label: {
            Text(L10n.LinkToAccount.linkButtonTitle)
                .foregroundColor(viewModel.linkButtonColor)
        })
        .disabled(!viewModel.isLinkButtonEnabled)
    }
}
