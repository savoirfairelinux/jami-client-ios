/*
 *  Copyright (C) 2024 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
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

struct LinkedDevicesView: View {
    @StateObject var model: LinkedDevicesVM

    @SwiftUI.State var editDevice: Bool = false
    @SwiftUI.State private var isFocused: Bool = false
    @SwiftUI.State private var deviceName: String = ""
    @SwiftUI.State private var showRevocationAlert: Bool = false
    @SwiftUI.State private var showLinkDeviceAlert: Bool = false
    @SwiftUI.State private var deviceToRevoke: DeviceModel?
    @SwiftUI.State private var password = ""

    init(account: AccountModel, accountService: AccountsService) {
        _model = StateObject(wrappedValue: LinkedDevicesVM(account: account, accountService: accountService))
    }

    var body: some View {
        ZStack {
            List {
                Section {
                    ForEach(model.devices, id: \.self) { device in
                        createDeviceRow(device: device)
                    }
                }
               linkDeviceButton()
            }
            if showRevocationAlert {
                RevocationView(model: model, showRevocationAlert: $showRevocationAlert, deviceToRevoke: $deviceToRevoke)
            }

            if showLinkDeviceAlert {
                LinkDeviceView(model: model, askForPassword: model.hasPassword(), showLinkDeviceAlert: $showLinkDeviceAlert)
            }
        }
        .onChange(of: showRevocationAlert) { _ in
            if !showRevocationAlert {
                deviceToRevoke = nil
                model.cleanInfoMessages()
            }
        }
        .navigationTitle( L10n.AccountPage.linkedDevices)
        .navigationBarTitleDisplayMode(.inline)
    }

    func createDeviceRow(device: DeviceModel) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                if let name = device.deviceName {
                    if !editDevice {
                        Text(name)
                    } else {
                        FocusableTextField(text: $deviceName, isFirstResponder: $isFocused)
                    }
                }
                Text(device.deviceId)
                    .font(.footnote)
                    .foregroundColor(Color(UIColor.secondaryLabel))
                    .lineLimit(1)
            }
            Spacer()
            if !device.isCurrent {
                Button(action: {
                    deviceToRevoke = device
                    withAnimation {
                        showRevocationAlert = true
                    }
                }) {
                    Text(L10n.Global.remove)
                        .foregroundColor(.jamiColor)
                }
            } else {
                Button(action: {
                    handleButtonAction(device: device)
                }) {
                    Text(editDevice ? L10n.Global.save : L10n.Global.edit)
                        .foregroundColor(.jamiColor)
                }
            }
        }
        .padding(.vertical, 5)
    }

    func linkDeviceButton() -> some View {
        Button(action: {
            withAnimation {
                showLinkDeviceAlert = true
            }
        }, label: {
            Text(L10n.LinkDevice.title)
                .foregroundColor(Color(UIColor.label))
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(Color.jamiTertiaryControl)
                .cornerRadius(10)
        })
        .listRowBackground(Color.clear)
        .optionalRowSeparator(hidden: true)
        .listRowInsets(EdgeInsets(top: 0 ,leading: 0,bottom: 0,trailing: 0))
        .listRowBackground(Color.clear)
    }

    private func handleButtonAction(device: DeviceModel) {
        if editDevice {
            saveDeviceName()
        } else {
            enterEditMode(device: device)
        }
    }

    private func saveDeviceName() {
        model.editDeviceName(name: deviceName)
        isFocused = false
        editDevice = false
    }

    private func enterEditMode(device: DeviceModel) {
        if let name = device.deviceName {
            deviceName = name
        }
        editDevice = true
        isFocused = true
    }
}

struct LinkDeviceView: View {
    @ObservedObject var model: LinkedDevicesVM
    @SwiftUI.State var askForPassword: Bool
    @Binding var showLinkDeviceAlert: Bool
    @SwiftUI.State var password: String = ""

    var body: some View {
        CustomAlert(content: { createLinkDeviceView()})
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
                        showLinkDeviceAlert = false
                    }
                }) {
                    Text(L10n.Global.cancel)
                        .foregroundColor(.jamiColor)
                }
                Spacer()
                Button(action: {
                    withAnimation {
                        askForPassword = false
                    }
                    model.linkDevice(with: password)
                }) {
                    Text(L10n.LinkToAccount.linkButtonTitle)
                        .foregroundColor(.jamiColor)
                }
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
            }
            HStack(spacing: 15) {
                Image(systemName: "info.circle")
                    .resizable()
                    .foregroundColor(.jamiColor)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                VStack(spacing: 5)  {
                    Text(L10n.AccountPage.pinExplanationTitle)
                    Text(L10n.AccountPage.pinExplanationMessage)
                        .font(.footnote)
                }
            }
            .padding()
            .background(Color.jamiTertiaryControl)
            .cornerRadius(12)

            HStack {
                Spacer()
                Button(action: {
                    withAnimation {
                        showLinkDeviceAlert = false
                    }
                }) {
                    Text(L10n.Global.close)
                        .foregroundColor(.jamiColor)
                        .padding(.horizontal)
                }
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
                        showLinkDeviceAlert = false
                    }
                }) {
                    Text(L10n.Global.close)
                        .foregroundColor(.jamiColor)
                        .padding(.horizontal)
                }
            }
        }
    }
}

struct RevocationView: View {
    @ObservedObject var model: LinkedDevicesVM
    @Binding var showRevocationAlert: Bool
    @Binding  var deviceToRevoke: DeviceModel?
    @SwiftUI.State var password: String = ""
    @SwiftUI.State var revocationRequested: Bool = false

    var body: some View {
        CustomAlert(content: { createRevocationViewView()})
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
                }) {
                    Text(L10n.Global.ok)
                        .foregroundColor(.jamiColor)
                }
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
                }) {
                    Text(L10n.Global.ok)
                        .foregroundColor(.jamiColor)
                }
            }
        }
        .padding(.top)
    }

    func loadingView() -> some View {
        VStack {
            SwiftUI.ProgressView(L10n.AccountPage.deviceRevocationProgress)
                .padding()
        }
        .frame(minWidth: 280, minHeight: 150)
    }

    func initialView() -> some View {
        VStack(spacing: 20) {
            Text(L10n.AccountPage.revokeDeviceTitle)
                .font(.headline)
            Text(L10n.AccountPage.revokeDeviceMessage)
                .font(.subheadline)
            if model.hasPassword() {
                PasswordFieldView(text: $password, placeholder: L10n.Global.enterPassword)
                    .textFieldStyleInAlert()
            }
            HStack {
                Button(action: {
                    withAnimation {
                        showRevocationAlert = false
                    }
                }) {
                    Text(L10n.Global.cancel)
                        .foregroundColor(.jamiColor)
                }

                Spacer()

                Button(action: {
                    revocationRequested = true
                    if let deviceToRevoke = deviceToRevoke {
                        model.revokeDevice(deviceId: deviceToRevoke.deviceId, accountPassword: password)
                    }
                    password = ""
                    deviceToRevoke = nil
                }) {
                    Text(L10n.Global.remove)
                        .foregroundColor(.jamiColor)
                }
                .disabled(model.hasPassword() && password.isEmpty)
                .opacity(model.hasPassword() && password.isEmpty ? 0.5 : 1)
            }
        }
    }
}

