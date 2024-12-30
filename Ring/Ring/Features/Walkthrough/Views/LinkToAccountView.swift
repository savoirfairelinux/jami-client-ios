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
         linkAction: @escaping () -> Void) {
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

    private var header: some View {
        ZStack {
            HStack {
                cancelButton
                Spacer()
            }
            Text("Import account")
                .font(.system(size: 18, weight: .semibold))
        }
        .padding()
    }

    @ViewBuilder private var mainContent: some View {
        switch viewModel.uiState {
        case .initial:
            loadingView
        case .displayingToken:
            tokenView
        case .connecting:
            connectingView
        case .authenticating:
            autenticatingView
        case .inProgress:
            VStack {
                SwiftUI.ProgressView()
                Spacer()
            }
            .padding()
        case .success:
            successView()
        case .error(let message):
            errorView(message)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 30) {
            info
            SwiftUI.ProgressView()
            Spacer()
        }
        .padding(.horizontal)
    }

    private var tokenView: some View {
        Group {
            if verticalSizeClass == .regular {
                portraitView
            } else {
                landscapeView
            }
        }
    }

    private var connectingView: some View {
        VStack(spacing: 15) {
            Text("Action required.\nPlease confirm account on your old device.")
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal)
    }

    private var autenticatingView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 15) {
                userInfoView
                if viewModel.hasPassword {
                    passwordView
                        .padding(.top)
                }
                StyleImportAccountButton(title: "Import", action: { [weak viewModel] in
                    viewModel?.connect()
                })
                Spacer()
            }
            .padding(.horizontal)
        }
    }

    private func successView() -> some View {
        VStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(Color(UIColor.jamiSuccess))
                .font(.system(size: 50))
                .padding()
            Text("You are all set!")
            Text("Your account is successfully imported on the new device!")
            StyleImportAccountButton(title: "Go to accounts", action: { [weak dismissHandler, weak viewModel] in
                dismissHandler?.dismissView()
                viewModel?.linkCompleted()
            })
            Spacer()
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(Color(UIColor.jamiFailure))
                .font(.system(size: 50))
                .padding()
            Text(message)
            StyleImportAccountButton(title: "Exit", action: { [weak dismissHandler, weak viewModel] in
                dismissHandler?.dismissView()
                viewModel?.onCancel()
            })
            Spacer()
        }
    }

    private var portraitView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 30) {
                info
                tokenDisplay
                Spacer()
            }
            .padding(.horizontal)
        }
    }

    private var landscapeView: some View {
        HStack(spacing: 30) {
            VStack {
                Spacer().frame(height: 30)
                info
                Spacer()
            }
            ScrollView(showsIndicators: false) {
                VStack(spacing: 30) {
                    tokenDisplay
                }
            }
            Spacer()
        }
        .padding(.horizontal)
    }

    private var info: some View {
        (
            Text("On the old device, initiate the exportation.\n")
                + Text("Select Account > Account Settings > Link a new device.\n").bold()
                + Text(displayMode == .qrCode ? "When ready, scan the provided QR code." : "When ready, enter provided code.")
        )
        .multilineTextAlignment(.center)
        .frame(maxWidth: 500)
    }

    @ViewBuilder private var tokenDisplay: some View {
        Group {
            Picker("Display Mode", selection: $displayMode) {
                ForEach(DisplayMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(SegmentedPickerStyle())

            // Display based on chosen mode
            if displayMode == .label {
                tokenLabel
            } else {
                qrCodeView
            }
        }
    }

    private var qrCodeView: some View {
        QRCodeView(jamiId: viewModel.token, size: 200)
    }

    private var tokenLabel: some View {
        VStack(spacing: 30) {
            Text(viewModel.token)
                .font(.footnote)
                .contextMenu {
                    Button(action: {
                        UIPasteboard.general.string = viewModel.token
                    }, label: {
                        Text("Copy")
                        Image(systemName: "doc.on.doc")
                    })
                }
            ShareButtonView(infoToShare: viewModel.getShareInfo())
        }
    }

    private var passwordView: some View {
        VStack {
            Text("Your account is locked with password. Unlock it to continue")
                .multilineTextAlignment(.center)
            WalkthroughPasswordView(text: $viewModel.password, placeholder: L10n.Global.password)
        }
    }

    private var userInfoView: some View {
        VStack(spacing: 15) {
            AvatarImageView(model: viewModel, width: 100, height: 100)
            if let username = viewModel.username {
                Text(username)
            }
            Text(viewModel.jamiId).font(.callout)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }

    private var cancelButton: some View {
        Button(action: {[weak dismissHandler, weak viewModel] in
            dismissHandler?.dismissView()
            viewModel?.onCancel()
        }, label: {
            Text(L10n.Global.cancel)
                .foregroundColor(Color(UIColor.label))
                .font(.system(size: 18))
        })
    }
}

struct StyleImportAccountButton: View {
    let title: String
    let action: () -> Void
    var backgroundColor: Color = Color.jamiColor
    var textColor: Color = .white

    var body: some View {
        Button(action: action) {
            Text(title)
                .foregroundColor(textColor)
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(backgroundColor)
                .cornerRadius(10)
        }
        .padding()
    }
}
