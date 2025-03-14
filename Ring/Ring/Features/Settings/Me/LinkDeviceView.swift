/*
 *  Copyright (C) 2024-2025 Savoir-faire Linux Inc.
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

typealias EntryMode = DeviceLinkingMode

struct LinkDeviceView: View {
    @StateObject var model: LinkDeviceVM
    @SwiftUI.State var entryMode: DeviceLinkingMode = .qrCode
    @Environment(\.verticalSizeClass)
    var verticalSizeClass
    @Environment(\.colorScheme)
    var colorScheme
    @SwiftUI.State private var showAlert = false
    @Environment(\.presentationMode)
    var presentation

    init(account: AccountModel, accountService: AccountsService) {
        _model = StateObject(wrappedValue:
                                LinkDeviceVM(account: account,
                                             accountService: accountService))
    }

    var body: some View {
        createLinkDeviceView()
            .padding()
            .frame(maxWidth: 500)
            .navigationBarBackButtonHidden(true)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(L10n.LinkDevice.title)
            .toolbar { toolbarContent }
            .alert(isPresented: $showAlert, content: alertContent)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(UIColor.systemGroupedBackground)
                            .ignoresSafeArea())
    }

    @ViewBuilder
    func createLinkDeviceView() -> some View {
        switch model.exportState {
        case .initial:
            initialView
        case .connecting:
            connectingView()
        case .authenticating(peerAddress: let peerAddress):
            authenticatedView(address: peerAddress ?? "")
        case .inProgress:
            loadingView()
        case .error(let error):
            errorView(error)
        case .success:
            successView()
        }
    }

    @ViewBuilder private var initialView: some View {
        if verticalSizeClass == .regular {
            portraitView
        } else {
            landscapeView
        }
    }

    private var portraitView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 30) {
                info
                tokenView
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
                    tokenView
                        .frame(maxWidth: 500)
                }
            }
            Spacer()
        }
    }

    private var info: some View {
        (
            Text(L10n.LinkDevice.initialInfo) +
                Text(entryMode == .qrCode ? "\n" + L10n.LinkDevice.infoQRCode : "\n" + L10n.LinkDevice.infoCode)
        )
        .multilineTextAlignment(.center)
        .font(.callout)
        .lineSpacing(4)
        .frame(maxWidth: 500)
    }

    @ViewBuilder private var tokenView: some View {
        ModeSelectorView(selectedMode: $entryMode, isLinkToAccount: false)
            .onChange(of: entryMode) { _ in
                model.cleanState()
            }
        tokenContent
    }

    @ViewBuilder private var tokenContent: some View {
        Group {
            if entryMode == .pin {
                tokenEntry
            } else {
                qrCodeView
                    .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(colorScheme == .light ? Color(UIColor.secondarySystemGroupedBackground) : Color(UIColor.systemGray2))
        .cornerRadius(10)
        .padding(.horizontal)
    }

    private func connectingView() -> some View {
        VStack {
            Text(L10n.LinkDevice.connecting)
                .multilineTextAlignment(.center)
                .font(.callout)
                .lineSpacing(4)
            SwiftUI.ProgressView()
                .padding()
            Spacer()
        }
    }

    func authenticatedView(address: String) -> some View {
        VStack {
            VStack {
                Text(L10n.LinkDevice.authenticationInfo)
                    .multilineTextAlignment(.center)
                    .font(.callout)
                    .lineSpacing(4)
                Text(L10n.LinkDevice.newDeviceIP("\(address)"))
                    .bold().padding(.vertical)
                    .multilineTextAlignment(.center)
                HStack {
                    Spacer()
                    Button(action: {
                        model.confirmAddDevice()
                    }, label: {
                        Text(L10n.Global.confirm)
                            .foregroundColor(Color(UIColor.label))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 12)
                            .background(Color.jamiTertiaryControl)
                            .cornerRadius(10)
                    })
                    .padding(.horizontal)
                    Button(action: {
                        model.cancelAddDevice()
                    }, label: {
                        Text(L10n.Global.cancel)
                            .foregroundColor(Color(UIColor.label))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 12)
                            .background(Color.jamiTertiaryControl)
                            .cornerRadius(10)
                    })
                    Spacer()
                }
            }
            .padding()
            .background(colorScheme == .light ? Color(UIColor.secondarySystemGroupedBackground) : Color(UIColor.systemGray2))
            .cornerRadius(10)
            .padding(.horizontal)
            .frame(maxWidth: 500)
            Spacer()
        }
    }

    func loadingView() -> some View {
        VStack {
            Text(L10n.LinkDevice.exportInProgress)
                .multilineTextAlignment(.center)
                .font(.callout)
                .lineSpacing(4)
            SwiftUI.ProgressView()
                .padding()
            Spacer()
        }
    }

    private func successView() -> some View {
        SuccessStateView(
            message: L10n.LinkDevice.completed,
            buttonTitle: L10n.Global.ok
        ) {
            presentation.wrappedValue.dismiss()
        }
    }

    private func errorView(_ message: String) -> some View {
        ErrorStateView(
            message: message,
            buttonTitle: L10n.Global.ok
        ) {
            presentation.wrappedValue.dismiss()
        }
    }

    private var qrCodeView: some View {
        ScanQRCodeView(width: 250, height: 200) { jamiAuthentication in
            model.handleAuthenticationUri(jamiAuthentication)
        }
    }

    func connectButton() -> some View {
        Button(action: {
            withAnimation {
                model.handleAuthenticationUri(model.exportToken)
            }
        }, label: {
            Text(L10n.Global.connect)
                .commonButtonStyle()
        })
    }

    private var tokenEntry: some View {
        VStack {
            TextField(L10n.LinkDevice.token, text: $model.exportToken)
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
                .autocorrectionDisabled(true)
                .autocapitalization(.none)
                .background(Color(UIColor.systemGroupedBackground))
                .cornerRadius(10)
            Text(model.entryError ?? "")
                .font(.footnote)
                .foregroundColor(Color(UIColor.jamiFailure))
                .multilineTextAlignment(.center)
            connectButton()
                .padding(.top)
        }
    }

    func cancelRequested() {
        if model.shouldShowAlert() {
            self.showAlert = true
        } else {
            cancel()
        }
    }

    func cancel() {
        presentation.wrappedValue.dismiss()
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
}
