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
    @StateObject var viewModel: LinkToAccountVM
    let dismissHandler = DismissHandler()
    @Environment(\.verticalSizeClass)
    var verticalSizeClass

    init(injectionBag: InjectionBag,
         linkAction: @escaping (_ pin: String, _ password: String) -> Void) {
        _viewModel = StateObject(wrappedValue:
                                    LinkToAccountVM(with: injectionBag,
                                                    linkAction: linkAction))
    }

    var body: some View {
        VStack {
            header
            mainContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGroupedBackground)
            .ignoresSafeArea()
        )
    }

    @ViewBuilder
    private var mainContent: some View {
        switch viewModel.uiState {
            case .initial:
                VStack {
                    SwiftUI.ProgressView("Initializing...")
                        .progressViewStyle(.circular)
                    Spacer()
                }
            case .awaitingPin:
                VStack {
                    SwiftUI.ProgressView("awaitingPin")
                        .progressViewStyle(.circular)
                    Spacer()
                }
            case .displayingPin:
                if verticalSizeClass != .regular {
                    landscapeView
                } else {
                    portraitView
                }
            case .connecting:
                VStack {
                    SwiftUI.ProgressView("connecting ")
                        .progressViewStyle(.circular)
                    Spacer()
                }
            case .authenticating:
                VStack {
                    SwiftUI.ProgressView("authenticating")
                        .progressViewStyle(.circular)
                    Spacer()
                }
            case .inProgress:
                VStack {
                    SwiftUI.ProgressView("VStack")
                        .progressViewStyle(.circular)
                    Spacer()
                }
            case .success:
                VStack {
                    successView
                    Spacer()
                }
            case .error(let message):
                VStack {
                    errorView(message)
                    Spacer()
                }
        }
    }

    private var successView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 50))
            Text("")
            Button("") {
                dismissHandler.dismissView()
            }
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
                .font(.system(size: 50))
            Text(message)
                .foregroundColor(.red)
            Button("") {
                viewModel.retryConnection()
            }
        }
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
            VStack(spacing: 30) {
                info
                pinDisplay
                passwordView
            }
            .padding()
        }
    }

    private var landscapeView: some View {
        HStack(spacing: 30) {
            VStack {
                info
                Spacer()
            }
            ScrollView(showsIndicators: false) {
                VStack {
                    pinDisplay
                    passwordView
                }
            }
        }
        .padding()
    }

    private var info: some View {
        Text(L10n.LinkToAccount.explanationMessage)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 500)
    }

    private var pinDisplay: some View {
        VStack(spacing: 15) {
            pinSwitchButtons
            if viewModel.showQRCode {
                qrCodeView
            } else {
                pinLabel
            }
        }
       .frame(minWidth: 350, maxWidth: 500)
       .padding(.horizontal)
    }

    private var pinSwitchButtons: some View {
        HStack {
            switchButton(text: "show qr code",
                        isSelected: viewModel.showQRCode,
                        transitionEdge: .trailing,
                        action: { viewModel.switchToQRCode() })
            
            Spacer()
            
            switchButton(text: "show text code",
                        isSelected: !viewModel.showQRCode,
                        transitionEdge: .leading,
                        action: { viewModel.switchToPin() })
        }
    }

    private func switchButton(text: String,
                            isSelected: Bool,
                            transitionEdge: Edge,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack {
                Text(text)
                    .foregroundColor(Color(UIColor.label))
                    .font(isSelected ? .headline : .body)
                    .transition(.move(edge: transitionEdge))
                if isSelected {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.black)
                        .frame(height: 1)
                        .padding(.horizontal, 40)
                        .transition(.move(edge: transitionEdge))
                }
            }
        }
    }

    private var qrCodeView: some View {
        QRCodeView(jamiId: viewModel.pin, size: 150)
    }

    private var pinLabel: some View {
        Text(viewModel.pin)
            .font(.footnote)
    }

    private var passwordView: some View {
        VStack {
            Text(L10n.ImportFromArchive.passwordExplanation)
                .multilineTextAlignment(.center)
            WalkthroughPasswordView(text: $viewModel.password, placeholder: L10n.Global.password)
        }
        .padding(.bottom)
    }

    private var cancelButton: some View {
        Button(action: {[weak dismissHandler] in
            dismissHandler?.dismissView()
        }, label: {
            Text(L10n.Global.cancel)
                .foregroundColor(Color(UIColor.label))
        })
    }

    private var linkButton: some View {
        Button(action: {[weak dismissHandler, weak viewModel] in
            dismissHandler?.dismissView()
            viewModel?.link()
        }, label: {
            Text(L10n.LinkToAccount.linkButtonTitle)
                .foregroundColor(viewModel.linkButtonColor)
        })
        .disabled(!viewModel.isLinkButtonEnabled)
    }
}

