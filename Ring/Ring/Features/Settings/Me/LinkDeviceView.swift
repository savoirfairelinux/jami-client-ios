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

struct LinkDeviceView: View {
    @ObservedObject var model: LinkedDevicesVM
    @SwiftUI.State var askForPassword: Bool
    @SwiftUI.State var password: String = ""

    var body: some View {
        CustomAlert(content: { createLinkDeviceView() })
    }

    func createLinkDeviceView() -> some View {
        VStack(spacing: 20) {
            if askForPassword {
                passwordView()
            } else {
                switch model.generatingState {
                case .initial, .generatingPin:
                    loadingView()
                case .success(let pin):
                    successView(pin: pin)
                case .error(let error):
                    errorView(error: error.description)
                }
            }
        }
    }

    func loadingView() -> some View {
        VStack {
            SwiftUI.ProgressView(L10n.AccountPage.generatingPin)
                .padding()
        }
        .frame(minWidth: 280, minHeight: 150)
    }

    func passwordView() -> some View {
        VStack(spacing: 20) {
            Text(L10n.LinkDevice.title)
                .font(.headline)
            Text(L10n.AccountPage.passwordForPin)
                .font(.subheadline)
            PasswordFieldView(text: $password, placeholder: L10n.Global.enterPassword)
                .textFieldStyleInAlert()
            HStack {
                Button(action: {
                    withAnimation {
                        model.showLinkDeviceAlert = false
                    }
                }, label: {
                    Text(L10n.Global.cancel)
                        .foregroundColor(.jamiColor)
                })
                Spacer()
                Button(action: {
                    withAnimation {
                        askForPassword = false
                    }
                    model.linkDevice(with: password)
                }, label: {
                    Text(L10n.LinkToAccount.linkButtonTitle)
                        .foregroundColor(.jamiColor)
                })
                .disabled(password.isEmpty)
                .opacity(password.isEmpty ? 0.5 : 1)
            }
        }
    }

    func successView(pin: String) -> some View {
        VStack(spacing: 20) {
            Text("\(pin)")
                .foregroundColor(.jamiColor)
                .font(.headline)
                .conditionalTextSelection()
            if let image = model.PINImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 140, height: 140)
                    .accessibilityHidden(true)
            }
            HStack(spacing: 15) {
                Image(systemName: "info.circle")
                    .resizable()
                    .foregroundColor(.jamiColor)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                VStack(spacing: 5) {
                    Text(L10n.AccountPage.pinExplanationTitle)
                    Text(L10n.AccountPage.pinExplanationMessage)
                        .font(.footnote)
                }
            }
            .padding()
            .background(Color.jamiTertiaryControl)
            .cornerRadius(12)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(L10n.AccountPage.pinExplanationTitle + " " + L10n.AccountPage.pinExplanationMessage)
            .accessibilityAutoFocusOnAppear()

            HStack {
                Spacer()
                Button(action: {
                    withAnimation {
                        model.showLinkDeviceAlert = false
                    }
                }, label: {
                    Text(L10n.Global.close)
                        .foregroundColor(.jamiColor)
                        .padding(.horizontal)
                })
            }
        }
    }

    func errorView(error: String) -> some View {
        VStack {
            Text(L10n.AccountPage.pinError + ": \(error.description)")
                .foregroundColor(Color(UIColor.jamiFailure))
                .font(.subheadline)
                .padding()
            HStack {
                Spacer()
                Button(action: {
                    withAnimation {
                        model.showLinkDeviceAlert = false
                    }
                }, label: {
                    Text(L10n.Global.close)
                        .foregroundColor(.jamiColor)
                        .padding(.horizontal)
                })
            }
        }
    }
}
