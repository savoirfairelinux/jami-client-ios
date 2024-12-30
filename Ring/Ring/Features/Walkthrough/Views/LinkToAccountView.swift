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

enum DisplayMode: String, CaseIterable, Identifiable {
    case qrCode = "Show QR Code"
    case label = "Show PIN Code"

    var id: String { rawValue }
}

struct LinkToAccountView: View {
    @StateObject var viewModel: LinkToAccountVM
    let dismissHandler = DismissHandler()
    @Environment(\.verticalSizeClass)
    var verticalSizeClass
    @SwiftUI.State private var displayMode: DisplayMode = .qrCode

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
                VStack(spacing: 30) {
                    info
                    SwiftUI.ProgressView()
                    Spacer()
                }
                .padding()
            case .displayingPin:
                if verticalSizeClass != .regular {
                    landscapeView
                } else {
                    portraitView
                }
            case .connecting:
                VStack {
                    SwiftUI.ProgressView()
                    Spacer()
                }
                .padding()
            case .authenticating:
                autenticatingView
            case .inProgress:
                VStack {
                    SwiftUI.ProgressView()
                    Spacer()
                }
                .padding()
            case .success:
                VStack {
                   Text("Completed")
                }
                .onAppear { [weak dismissHandler] in
                    dismissHandler?.dismiss
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
                if viewModel.uiState == .authenticating {
                    linkButton
                }
            }
                Text("Connect")
                    .font(.headline)
        }
        .padding()
    }

    private var readyView: some View {
        Group {
            if verticalSizeClass != .regular {
                landscapeView
            } else {
                portraitView
            }
        }
    }

    private var autenticatingView: some View {
        VStack(spacing: 30) {
            info
            AvatarImageView(model: viewModel, width: 100, height: 100)
            if let username = viewModel.username {
                Text(username)
            }
            Text(viewModel.jamiId)
            if viewModel.hasPassword {
                passwordView
            }
        }
        .padding()
    }

    private var portraitView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 30) {
                info
                pinDisplay
                Spacer()
                if viewModel.uiState == .authenticating {
                    Text("autenticating")
                }
                if viewModel.uiState == .authenticating && viewModel.hasPassword {
                    passwordView
                }
            }
            .padding()
        }
    }

    private var landscapeView: some View {
        HStack(spacing: 30) {
            VStack {
                Spacer()
                info
                Spacer()
            }
            ScrollView(showsIndicators: false) {
                VStack(spacing: 30) {
                    pinDisplay
                    if viewModel.uiState == .authenticating {
                        Text("autenticating")
                    }
                    if viewModel.uiState == .authenticating && viewModel.hasPassword {
                        passwordView
                    }
                }
            }
            Spacer()
        }
        .padding()
    }

    private var info: some View {
        Text("On the old device, initiate the exportation. Select Account > Account Settings > Link a new device. When ready, scan the QR Code below.")
            .multilineTextAlignment(.center)
            .frame(maxWidth: 500)
    }

    @ViewBuilder
    private var pinDisplay: some View {
        Group {
            Picker("Display Mode", selection: $displayMode) {
                ForEach(DisplayMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(SegmentedPickerStyle())

            // Display based on chosen mode
            if displayMode == .label {
                pinLabel
            } else {
                qrCodeView
            }
        }
    }

    private var qrCodeView: some View {
        QRCodeView(jamiId: viewModel.pin, size: 200)
    }

    private var pinLabel: some View {
        VStack(spacing: 30) {
            Text(viewModel.pin)
                .font(.footnote)
                .contextMenu {
                    Button(action: {
                        UIPasteboard.general.string = viewModel.pin
                    }) {
                        Text("Copy")
                        Image(systemName: "doc.on.doc")
                    }
                }
            ShareButtonView(infoToShare: viewModel.pin)
        }
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
        Button(action: {[weak dismissHandler, weak viewModel] in
            dismissHandler?.dismissView()
            viewModel?.onCancel()
        }, label: {
            Text(L10n.Global.cancel)
                .foregroundColor(Color(UIColor.label))
        })
    }

    private var linkButton: some View {
        Button(action: {[weak dismissHandler, weak viewModel] in
           // dismissHandler?.dismissView()
            viewModel?.connect()
        }, label: {
            Text("Connect")
                .foregroundColor(viewModel.linkButtonColor)
        })
        // .disabled(!viewModel.isLinkButtonEnabled)
    }
}

