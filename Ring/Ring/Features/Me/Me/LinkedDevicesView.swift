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
                                    Text(L10n.AccountPage.unlink)
                                        .foregroundColor(.jamiColor)
                                }
                            } else {
                                Button(action: {
                                    if editDevice {
                                        self.model.editDeviceName(name: deviceName)
                                        isFocused = false
                                        editDevice = false
                                    } else {
                                        if let name = device.deviceName {
                                            deviceName = name
                                        }
                                        editDevice = true
                                        isFocused = true
                                    }
                                }) {
                                    Text(editDevice ? L10n.Global.save : L10n.Global.edit)
                                        .foregroundColor(.jamiColor)
                                }

                            }
                        }
                        .padding(.vertical, 5)
                    }
                }
                linkDeviceButton()
            }
            if showRevocationAlert {
                revocationAlertView()
            }
        }
        .navigationTitle( L10n.AccountPage.linkedDevices)
        .navigationBarTitleDisplayMode(.inline)
    }

    func linkDeviceButton() -> some View {
        Button(action: {

        }, label: {
            Text(L10n.Global.save)
                .foregroundColor(Color(UIColor.label))
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(Color.jamiTertiaryControl)
                .cornerRadius(10)
        })
        .listRowBackground(Color.clear)
        .optionalRowSeparator(hidden: true)
        .listRowInsets(EdgeInsets(top: 20 ,leading: 0,bottom: 0,trailing: 0))
    }

    func revocationAlertView() -> some View {
        ZStack {
            Color.black.opacity(showRevocationAlert ? 0.3 : 0)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text(L10n.AccountPage.revokeDeviceTitle)
                    .font(.headline)

                Text(L10n.AccountPage.revokeDeviceMessage)
                    .font(.subheadline)

                SecureField(L10n.Global.enterPassword, text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()

                HStack {
                    Button(action: {
                        withAnimation {
                            showRevocationAlert = false
                            if let deviceToRevoke = deviceToRevoke {
                                model.revokeDevice(deviceId: deviceToRevoke.deviceId, accountPassword: password)
                            }
                            deviceToRevoke = nil
                        }
                    }) {
                        Text(L10n.AccountPage.revokeDeviceButton)
                            .foregroundColor(.jamiColor)
                    }

                    Spacer()

                    Button(action: {
                        withAnimation {
                            showRevocationAlert = false
                            deviceToRevoke = nil
                        }
                    }) {
                        Text(L10n.Global.cancel)
                            .foregroundColor(.jamiColor)
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .shadow(radius: 10)
            .padding()
            .transition(.move(edge: .bottom))
        }
    }
}

struct FocusableTextField: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFirstResponder: Bool

    class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String
        @Binding var isFirstResponder: Bool

        init(text: Binding<String>, isFirstResponder: Binding<Bool>) {
            _text = text
            _isFirstResponder = isFirstResponder
        }

        func textFieldDidChangeSelection(_ textField: UITextField) {
            self.text = textField.text ?? ""
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            self.isFirstResponder = true
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            self.isFirstResponder = false
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(text: $text, isFirstResponder: $isFirstResponder)
    }

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField(frame: .zero)
        textField.delegate = context.coordinator
        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        uiView.text = text

        if isFirstResponder {
            uiView.becomeFirstResponder()
        } else {
            uiView.resignFirstResponder()
        }
    }
}
