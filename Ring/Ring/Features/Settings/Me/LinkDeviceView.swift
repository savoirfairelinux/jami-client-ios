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

enum EntryMode: String, CaseIterable, Identifiable {
    case qrCode = "qrCode"
    case label = "enterCode"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .qrCode:
            return L10n.LinkDevice.scanQRCode
        case .label:
            return L10n.LinkDevice.enterCode
        }
    }
}

struct LinkDeviceView: View {
    @StateObject var model: LinkDeviceVM
    @SwiftUI.State private var entryMode: EntryMode = .qrCode
    @Environment(\.verticalSizeClass)
    var verticalSizeClass
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

    private var initialView: some View {
        Group {
            if verticalSizeClass == .regular {
                portraitView
            } else {
                landscapeView
            }
        }
    }

    private var portraitView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 30) {
                info
                tokenView
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
                }
            }
            Spacer()
        }
    }

    private var info: some View {
        (
            Text(L10n.LinkDevice.initialInfo)
                + Text(L10n.LinkDevice.infoAddAccount).bold()
                + Text(entryMode == .qrCode ? L10n.LinkDevice.infoQRCode : L10n.LinkDevice.infoCode)
        )
        .multilineTextAlignment(.center)
        .frame(maxWidth: 500)
    }

    @ViewBuilder private var tokenView: some View {
        Group {
            Picker("Entry Mode", selection: $entryMode) {
                ForEach(EntryMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: entryMode) { _ in
                model.cleanState()
            }

            if entryMode == .label {
                tokenEntry
            } else {
                qrCodeView
            }
        }
        Spacer()
    }

    private func connectingView() -> some View {
        VStack {
            Text(L10n.LinkDevice.connecting)
                .multilineTextAlignment(.center)
            SwiftUI.ProgressView()
                .padding()
            Spacer()
        }
    }

    func authenticatedView(address: String) -> some View {
        VStack {
            Text(L10n.LinkDevice.authenticationInfo)
                .multilineTextAlignment(.center)
            Text(L10n.LinkDevice.newDeviceIP + " \(address)").bold().padding(.vertical)
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
            Spacer()
        }
    }

    func loadingView() -> some View {
        VStack {
            Text(L10n.LinkDevice.exportInProgress)
                .multilineTextAlignment(.center)
            SwiftUI.ProgressView()
                .padding()
            Spacer()
        }
    }

    private func successView() -> some View {
        VStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(Color(UIColor.jamiSuccess))
                .font(.system(size: 50))
                .padding()
            Text(L10n.LinkToAccount.allSet)
                .multilineTextAlignment(.center)
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
                .multilineTextAlignment(.center)
            Spacer()
        }
    }

    private var qrCodeView: some View {
        ScanQRCodeView(width: 300, height: 250) { jamiAuthentication in
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
                .foregroundColor(Color(UIColor.label))
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
                .background(Color.jamiTertiaryControl)
                .cornerRadius(10)
        })
    }

    private var tokenEntry: some View {
        VStack {
            WalkthroughTextEditView(text: $model.exportToken,
                                    placeholder: L10n.LinkDevice.token)
            Text(model.entryError ?? "")
                .font(.footnote)
                .foregroundColor(Color(UIColor.jamiFailure))
                .multilineTextAlignment(.center)
            connectButton()
                .padding(.vertical, 30)
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
            backButton
        }
    }

    @ViewBuilder
    private var backButton: some View {
        Button(action: cancelRequested) {
            HStack {
                Group {
                    Image(systemName: "chevron.left")
                    Text(L10n.Actions.backAction)
                }
                .foregroundColor(Color(UIColor.jamiButtonDark))
            }
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
