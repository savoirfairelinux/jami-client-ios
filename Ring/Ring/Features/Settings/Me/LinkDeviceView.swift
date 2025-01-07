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

enum EntryMode: String, CaseIterable, Identifiable {
    case qrCode = "Scan QR Code"
    case label = "Enter PIN Code"

    var id: String { rawValue }
}

struct LinkDeviceView: View {
    @ObservedObject var model: LinkedDevicesVM
    @SwiftUI.State var askForPassword: Bool
    @SwiftUI.State var password: String = ""
    @SwiftUI.State private var entryMode: EntryMode = .qrCode
    @Environment(\.verticalSizeClass)
    var verticalSizeClass

    var body: some View {
        createLinkDeviceView()
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
                    tokenView
                }
            }
            Spacer()
        }
        .padding(.horizontal)
    }

    private var info: some View {
        (
            Text("On the new device, initiate a new account.\n")
                + Text("Select Add Account > Connect from another device.\n").bold()
                + Text(entryMode == .qrCode ? "When ready, scan the QR Code" : "When ready, enter the code and press `Connect`.")
        )
        .multilineTextAlignment(.center)
        .frame(maxWidth: 500)
    }

    @ViewBuilder private var tokenView: some View {
        Group {
            Picker("Entry Mode", selection: $entryMode) {
                ForEach(EntryMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(SegmentedPickerStyle())

            if entryMode == .label {
                tokenEntry
            } else {
                qrCodeView
            }
        }
        Spacer()
    }

    private func connectingView() -> some View {
        VStack(spacing: 30) {
            info
            SwiftUI.ProgressView()
                .padding()
            Spacer()
        }
        .padding()
    }

    func authenticatedView(address: String) -> some View {
        VStack {
            Text("New device found at address below. Is that you?\nClicking on confirm will continue transfering account")
                .multilineTextAlignment(.center)
            Text("new device IP: \(address)").bold()
                .multilineTextAlignment(.center)
            HStack {
                Spacer()
                Button(action: {
                    model.confirmAddDevice()
                }, label: {
                    Text("Confirm")
                        .foregroundColor(Color(UIColor.label))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 12)
                        .background(Color.jamiTertiaryControl)
                        .cornerRadius(10)
                })
                .padding()
                Button(action: {
                    model.cancelAddDevice()
                }, label: {
                    Text("Cancel")
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
    }

    func loadingView() -> some View {
        VStack {
            SwiftUI.ProgressView()
                .padding()
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
            Spacer()
        }
    }

    private var qrCodeView: some View {
        ScanQRCodeView(width: 350, height: 280) { jamiAuthentication in
            model.handleAuthenticationUri(jamiAuthentication)
        }
    }

    func connectButton() -> some View {
        Button(action: {
            withAnimation {
                model.handleAuthenticationUri(model.exportToken)
            }
        }, label: {
            Text("Connect")
                .foregroundColor(Color(UIColor.label))
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
                .background(Color.jamiTertiaryControl)
                .cornerRadius(10)
        })
    }

    private var tokenEntry: some View {
        VStack {
            WalkthroughTextEditView(text: $model.exportToken,
                                    placeholder: "token")
                .onAppear {
                    model.exportToken = "jami-auth://"
                    model.entryError = nil
                }
            Text(model.entryError ?? "")
                .font(.footnote)
                .foregroundColor(Color(UIColor.jamiFailure))
            connectButton()
                .padding()
        }
    }
}
