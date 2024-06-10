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

struct CallSettingsView: View {
    @StateObject var model: AccountSettings

    init(injectionBag: InjectionBag, account: AccountModel) {
        _model = StateObject(wrappedValue: AccountSettings(account: account, injectionBag: injectionBag))
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Allow incoming calls from unknown contacts")
                    Spacer()
                    Toggle("", isOn: Binding<Any>.customBinding(
                        get: { model.callsFromUnknownContacts },
                        set: { newValue in model.enableCallsFromUnknownContacts(enable: newValue) }
                    ))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Call")
        }
    }
}

struct NotificationsSettingsView: View {
    @StateObject var model: AccountSettings

    init(injectionBag: InjectionBag, account: AccountModel) {
        _model = StateObject(wrappedValue: AccountSettings(account: account, injectionBag: injectionBag))
    }

    var body: some View {
        List {
            Section(footer:
                        VStack {
                            if model.showNotificationPermitionIssue {
                                Button {
                                    DispatchQueue.main.async {
                                        if let url = URL(string: UIApplication.openSettingsURLString) {
                                            UIApplication.shared.open(url)
                                        }
                                    }
                                } label: {
                                    Text(L10n.AccountPage.notificationErrorPart1)
                                        .font(.footnote)
                                        .foregroundColor(.red) + Text(" ")
                                        .font(.footnote)
                                        .foregroundColor(.red) + Text(L10n.AccountPage.notificationErrorPart2)
                                        .font(.footnote)
                                        .foregroundColor(.red)
                                        .underline()
                                }
                            }
                        }
            ) {
                HStack {
                    Text(L10n.AccountPage.enableNotifications)
                    Spacer()
                    Toggle("", isOn: Binding<Any>.customBinding(
                        get: { model.proxyEnabled },
                        set: { newValue in model.enableNotifications(enable: newValue) }
                    ))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(L10n.AccountPage.notificationTitle)
        }
    }
}

struct ConnectivitySettingsView: View {
    @StateObject var model: AccountSettings

    init(injectionBag: InjectionBag, account: AccountModel) {
        _model = StateObject(wrappedValue: AccountSettings(account: account, injectionBag: injectionBag))
    }

    var body: some View {
        List {
            if model.account.type == .sip {
                Section {
                    HStack {
                        Text("Auto register After Expired")
                        Spacer()
                        Toggle("", isOn: Binding<Any>.customBinding(
                            get: { model.autoRegistrationEnabled },
                            set: { newValue in model.enableaAtoregister(enable: newValue) }
                        ))
                        .labelsHidden()
                    }
                    NavigationLink(destination: EditExpirationtime(expirationtime: $model.autoRegistrationExpirationTime, onDisappearAction: {
                        model.setExpirationTime()
                    })) {
                        FieldRowView(label: "Registration expiration time (seconds)", value: model.autoRegistrationExpirationTime)
                    }
                }

            } else {
                Section {
                    HStack {
                        Text("Auto connect on a local network")
                        Spacer()
                        Toggle("", isOn: Binding<Any>.customBinding(
                            get: { model.autoConnectOnLocalNetwork },
                            set: { newValue in model.enableAutoConnectOnLocalNetwork(enable: newValue) }
                        ))
                        .labelsHidden()
                    }
                }
            }
            Section(header: Text("connectivity")) {
                HStack {
                    Text("Use UPnP")
                    Spacer()
                    Toggle("", isOn: Binding<Any>.customBinding(
                        get: { model.upnpEnabled },
                        set: { newValue in model.enableUpnp(enable: newValue) }
                    ))
                    .labelsHidden()
                }

                HStack {
                    Text("Enable TURN")
                    Spacer()
                    Toggle("", isOn: Binding<Any>.customBinding(
                        get: { model.turnEnabled },
                        set: { newValue in model.enableTurn(enable: newValue) }
                    ))
                    .labelsHidden()
                }

                if model.turnEnabled {
                    HStack {
                        Text("TURN address")
                        Spacer()
                        TextField("TURN address", text: $model.turnServer, onCommit: {
                            model.saveTurnSettings()
                        })
                        .autocorrectionDisabled(true)
                        .autocapitalization(.none)
                        .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("TURN username")
                        Spacer()
                        TextField("TURN username", text: $model.turnUsername, onCommit: {
                            model.saveTurnSettings()
                        })
                        .autocorrectionDisabled(true)
                        .autocapitalization(.none)
                        .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("TURN password")
                        Spacer()
                        TextField("TURN password", text: $model.turnPassword, onCommit: {
                            model.saveTurnSettings()
                        })
                        .autocorrectionDisabled(true)
                        .autocapitalization(.none)
                        .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("TURN realm")
                        Spacer()
                        TextField("TURN realm", text: $model.turnRealm, onCommit: {
                            model.saveTurnSettings()
                        })
                        .autocorrectionDisabled(true)
                        .autocapitalization(.none)
                        .multilineTextAlignment(.trailing)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Connectivity & configurations")
    }
}

struct SecuritySettingsView: View {
    @StateObject var model: AccountSettings

    init(injectionBag: InjectionBag, account: AccountModel) {
        _model = StateObject(wrappedValue: AccountSettings(account: account, injectionBag: injectionBag))
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Encrypt media streams(SRTP)")
                    Spacer()
                    Toggle("", isOn: Binding<Any>.customBinding(
                        get: { model.enableSRTP },
                        set: { newValue in model.enableSRTP(enable: newValue) }
                    ))
                    .labelsHidden()
                }
                HStack {
                    Text("Verify server TLS certificates")
                    Spacer()
                    Toggle("", isOn: Binding<Any>.customBinding(
                        get: { model.tlsVerifyServer },
                        set: { newValue in model.enableVerifyTlsServer(enable: newValue) }
                    ))
                    .labelsHidden()
                }

                HStack {
                    Text("Verify client TLS certificates")
                    Spacer()
                    Toggle("", isOn: Binding<Any>.customBinding(
                        get: { model.tlsVerifyClient },
                        set: { newValue in model.enableVerifyTlsServer(enable: newValue) }
                    ))
                    .labelsHidden()
                }

                HStack {
                    Text("Requere certificate for incoming TLS connections")
                    Spacer()
                    Toggle("", isOn: Binding<Any>.customBinding(
                        get: { model.tlsRequireClientCertificate },
                        set: { newValue in model.enableTlsClientCertificate(enable: newValue) }
                    ))
                    .labelsHidden()
                }

                HStack {
                    Text("Disable secure dialog check for incoming TLS data")
                    Spacer()
                    Toggle("", isOn: Binding<Any>.customBinding(
                        get: { model.disableSecureDlgCheck },
                        set: { newValue in model.disableSecureDlgCheck(disable: newValue) }
                    ))
                    .labelsHidden()
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Securety")
    }
}

struct EditExpirationtime: View {
    @Binding var expirationtime: String
    var onDisappearAction: () -> Void
    @SwiftUI.State private var isTextFieldFocused = false
    @SwiftUI.State private var stepperValue: Int = 0

    var body: some View {
        Form {
            Section(footer: Text("Select time (in seconds) for registration expiration")) {
                HStack {
                    TextField("Time", text: $expirationtime)
                        .padding(.vertical, 10)
                        .padding(.horizontal)
                        .keyboardType(.numberPad)
                        .onChange(of: expirationtime) { newValue in
                            if let value = Int(newValue) {
                                stepperValue = value
                            } else {
                                stepperValue = 0
                            }
                        }
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(UIColor.secondaryLabel), lineWidth: 1))
                        .padding(.vertical, 10)

                    Stepper("", value: Binding(
                        get: {
                            stepperValue
                        },
                        set: { newValue in
                            stepperValue = newValue
                            expirationtime = "\(newValue)"
                        }
                    ), in: 0...3600, step: 1)
                }
            }
        }
        .navigationTitle("Edit Expiration Time")
        .onAppear {
            if let initialValue = Int(expirationtime) {
                stepperValue = initialValue
            }
        }
        .onDisappear {
            onDisappearAction()
        }
    }
}
