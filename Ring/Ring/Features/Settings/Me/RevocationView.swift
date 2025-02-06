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

struct RevocationView: View {
    @ObservedObject var model: LinkedDevicesVM
    @Binding var showRevocationAlert: Bool
    @Binding  var deviceToRevoke: DeviceModel?
    @SwiftUI.State var password: String = ""
    @SwiftUI.State var revocationRequested: Bool = false

    var body: some View {
        CustomAlert(content: { createRevocationViewView() })
    }

    func createRevocationViewView() -> some View {
        VStack(spacing: 20) {
            if let errorMessage = model.revocationError {
                errorView(errorMessage: errorMessage)
            } else if let successMessage = model.revocationSuccess {
                successView(successMessage: successMessage)
            } else if revocationRequested {
                loadingView()
            } else {
                initialView()
            }
        }
    }

    func errorView(errorMessage: String) -> some View {
        VStack(spacing: 20) {
            HStack {
                Spacer()
                Text(errorMessage)
                    .foregroundColor(Color(UIColor.jamiFailure))
                Spacer()
            }
            HStack {
                Spacer()
                Button(action: {
                    withAnimation {
                        showRevocationAlert = false
                    }
                }, label: {
                    Text(L10n.Global.ok)
                        .foregroundColor(.jamiColor)
                })
            }
        }
        .padding(.top)
    }

    func successView(successMessage: String) -> some View {
        VStack(spacing: 20) {
            HStack {
                Spacer()
                Group {
                    Image(systemName: "checkmark")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 15, height: 15)
                        .padding(.trailing, 5)
                    Text(successMessage)
                }
                .foregroundColor(Color(UIColor.jamiSuccess))
                Spacer()
            }
            HStack {
                Spacer()
                Button(action: {
                    withAnimation {
                        showRevocationAlert = false
                    }
                }, label: {
                    Text(L10n.Global.ok)
                        .foregroundColor(.jamiColor)
                })
            }
        }
        .padding(.top)
    }

    func loadingView() -> some View {
        VStack {
            SwiftUI.ProgressView(L10n.AccountPage.deviceRevocationProgress)
                .padding()
                .accessibilityAutoFocusOnAppear()
        }
        .frame(minWidth: 280, minHeight: 150)
    }

    func initialView() -> some View {
        VStack(spacing: 20) {
            Text(L10n.AccountPage.removeDeviceTitle)
                .font(.headline)
            Text(L10n.AccountPage.revokeDeviceMessage)
                .font(.subheadline)
                .accessibilityAutoFocusOnAppear()
            if model.hasPassword() {
                PasswordFieldView(text: $password, placeholder: L10n.Global.enterPassword)
                    .textFieldStyleInAlert()
            }
            HStack {
                Button(action: {
                    withAnimation {
                        showRevocationAlert = false
                    }
                }, label: {
                    Text(L10n.Global.cancel)
                        .foregroundColor(Color(UIColor.label))
                })

                Spacer()

                Button(action: {
                    revocationRequested = true
                    if let deviceToRevoke = deviceToRevoke {
                        model.revokeDevice(deviceId: deviceToRevoke.deviceId, accountPassword: password)
                    }
                    password = ""
                    deviceToRevoke = nil
                }, label: {
                    Text(L10n.Global.remove)
                        .foregroundColor(.jamiColor)
                })
                .disabled(model.hasPassword() && password.isEmpty)
                .opacity(model.hasPassword() && password.isEmpty ? 0.5 : 1)
            }
        }
    }
}
