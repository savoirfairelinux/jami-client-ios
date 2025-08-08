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

typealias DisplayMode = DeviceLinkingMode

struct LinkToAccountView: View {
    @StateObject var viewModel: LinkToAccountVM
    let dismissHandler = DismissHandler()
    @Environment(\.verticalSizeClass)
    var verticalSizeClass
    @Environment(\.colorScheme)
    var colorScheme
    @SwiftUI.State private var displayMode: DisplayMode = .qrCode
    @SwiftUI.State private var showAlert = false

    init(injectionBag: InjectionBag,
         linkAction: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue:
                                    LinkToAccountVM(with: injectionBag,
                                                    linkAction: linkAction, size: 44))
    }

    var body: some View {
        mainContent
            .padding()
            .frame(maxWidth: 500)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(L10n.LinkToAccount.importAccount)
            .navigationBarBackButtonHidden(true)
            .toolbar { toolbarContent }
            .alert(isPresented: $showAlert, content: alertContent)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(backgroundColor)
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
            inProgressView
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
    }

    @ViewBuilder private var tokenView: some View {
        if verticalSizeClass == .regular {
            portraitView
        } else {
            landscapeView
        }
    }

    private var connectingView: some View {
        VStack {
            Text(L10n.LinkToAccount.actionRequired)
                .multilineTextAlignment(.center)
                .font(.callout)
                .lineSpacing(4)
            Spacer()
        }
    }

    private var autenticatingView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 15) {
                userInfoView
                if viewModel.hasPassword {
                    passwordView.padding(.top)
                }
                Button(action: { [weak viewModel] in
                    viewModel?.connect()
                }, label: {
                    Text(L10n.LinkToAccount.importAccount)
                        .commonButtonStyle()
                })
                .disabled(viewModel.hasPassword && viewModel.password.isEmpty)
                .opacity((viewModel.hasPassword && viewModel.password.isEmpty) ? 0.5 : 1)
                Spacer()
            }
            .padding(.horizontal)
        }
    }

    private var inProgressView: some View {
        HStack {
            Spacer()
            VStack {
                SwiftUI.ProgressView()
                Spacer()
            }
            Spacer()
        }
    }

    private func successView() -> some View {
        SuccessStateView(
            message: L10n.LinkToAccount.allSet,
            buttonTitle: L10n.LinkToAccount.goToAccounts
        ) { [weak dismissHandler, weak viewModel] in
            guard let dismissHandler = dismissHandler,
                  let viewModel = viewModel else { return }
            dismissHandler.dismissView()
            viewModel.linkCompleted()
        }
    }

    private func errorView(_ message: String) -> some View {
        ErrorStateView(
            message: message,
            buttonTitle: L10n.LinkToAccount.exit
        ) { [weak dismissHandler, weak viewModel] in
            guard let dismissHandler = dismissHandler,
                  let viewModel = viewModel else { return }
            dismissHandler.dismissView()
            viewModel.onCancel()
        }
    }

    private var portraitView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 30) {
                info
                tokenDisplay
                    .frame(maxWidth: 500)
                Spacer()
            }
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
    }

    private var info: some View {
        (
            Text(L10n.LinkToAccount.exportInstructions + "\n")
                + Text(L10n.LinkToAccount.exportInstructionsPath + "\n").bold()
                + Text(displayMode == .qrCode ?
                        L10n.LinkToAccount.scanQrCode : L10n.LinkToAccount.enterProvidedCode)
        )
        .multilineTextAlignment(.center)
        .font(.callout)
        .lineSpacing(4)
        .frame(maxWidth: 500)
    }

    @ViewBuilder private var tokenDisplay: some View {
        ModeSelectorView(selectedMode: $displayMode, isLinkToAccount: true)
        tokenContent
    }

    private var qrCodeView: some View {
        QRCodeView(jamiId: viewModel.token, accessibilityLabel: L10n.Accessibility.Account.tokenQRcode, size: 200)
    }

    @ViewBuilder private var tokenContent: some View {
        Group {
            if displayMode == .pin {
                tokenLabel
            } else {
                qrCodeView
                    .frame(maxWidth: 500)
            }
        }
        .padding()
        .background(colorScheme == .light ? Color(UIColor.secondarySystemGroupedBackground) : Color(UIColor.systemGray2))
        .cornerRadius(10)
        .padding(.horizontal)
    }

    private var tokenLabel: some View {
        VStack(spacing: 30) {
            Text(viewModel.token)
                .font(.footnote)
                .contextMenu {
                    Button(action: {
                        UIPasteboard.general.string = viewModel.token
                    }, label: {
                        Text(L10n.Global.copy)
                        Image(systemName: "doc.on.doc")
                    })
                }
            ShareButtonView(infoToShare: viewModel.getShareInfo())
        }
    }

    private var passwordView: some View {
        VStack {
            Text(L10n.LinkToAccount.accountLockedWithPassword)
                .font(.callout)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
            WalkthroughPasswordView(text: $viewModel.password, placeholder: L10n.Global.password)
            if let error = viewModel.authError {
                Text(error)
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color(UIColor.jamiFailure))
                    .font(.footnote)
            }
        }
    }

    private var userInfoView: some View {
        VStack(spacing: 15) {
            AvatarImageView(model: viewModel, width: 60, height: 60)
            if let username = viewModel.username {
                Text(username)
            }
            Text(viewModel.jamiId).font(.callout)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(colorScheme == .light ? Color(UIColor.secondarySystemGroupedBackground) : Color(UIColor.systemGray2))
        .cornerRadius(10)
    }

    func cancelRequested() {
        if viewModel.shouldShowAlert() {
            self.showAlert = true
        } else {
            cancel()
        }
    }

    func cancel() {
        dismissHandler.dismissView()
        viewModel.onCancel()
    }

    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            BackButton(action: cancelRequested)
        }
    }

    private func alertContent() -> Alert {
        Alert(
            title: Text(L10n.LinkToAccount.alertTile),
            message: Text(L10n.LinkToAccount.alertMessage),
            primaryButton: .destructive(Text(L10n.Global.confirm), action: cancel),
            secondaryButton: .cancel()
        )
    }

    private var backgroundColor: some View {
        Color(UIColor.systemGroupedBackground)
            .ignoresSafeArea()
    }
}
