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
                    Text(L10n.AccountPage.callsFromUnknownContacts)
                    Spacer()
                    Toggle("", isOn: Binding<Any>.customBinding(
                        get: { model.callsFromUnknownContacts },
                        set: { newValue in model.enableCallsFromUnknownContacts(enable: newValue) }
                    ))
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: Color.jamiColor))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(L10n.Global.call)
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
            Section(footer: notificationsFooterView()) {
                HStack {
                    Text(L10n.AccountPage.enableNotifications)
                    Spacer()
                    Toggle("", isOn: Binding<Any>.customBinding(
                        get: { model.proxyEnabled },
                        set: { newValue in model.enableNotifications(enable: newValue) }
                    ))
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: Color.jamiColor))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(L10n.AccountPage.notificationTitle)
        }
    }

    func notificationsFooterView() -> some View {
        VStack {
            if model.showNotificationPermitionIssue {
                Button {
                    DispatchQueue.main.async {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                } label: {
                    Text(L10n.AccountPage.notificationError)
                        .font(.footnote)
                        .underline()
                        .foregroundColor(.red)
                        .padding(.vertical, 10)
                }
            }
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
                        Text(L10n.AccountPage.autoRegistration)
                        Spacer()
                        Toggle("", isOn: Binding<Any>.customBinding(
                            get: { model.autoRegistrationEnabled },
                            set: { newValue in model.enableaAtoregister(enable: newValue) }
                        ))
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: Color.jamiColor))
                    }
                    NavigationLink(destination: EditExpirationtime(expirationtime: $model.autoRegistrationExpirationTime, onDisappearAction: {
                        model.setExpirationTime()
                    })) {
                        FieldRowView(label: L10n.AccountPage.sipExpirationTime, value: model.autoRegistrationExpirationTime)
                    }
                }

            } else {
                Section {
                    HStack {
                        Text(L10n.AccountPage.peerDiscovery)
                        Spacer()
                        Toggle("", isOn: Binding<Any>.customBinding(
                            get: { model.autoConnectOnLocalNetwork },
                            set: { newValue in model.enableAutoConnectOnLocalNetwork(enable: newValue) }
                        ))
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: Color.jamiColor))
                    }
                }
            }
            Section(header: Text(L10n.AccountPage.connectivityHeader)) {
                HStack {
                    Text(L10n.AccountPage.upnpEnabled)
                    Spacer()
                    Toggle("", isOn: Binding<Any>.customBinding(
                        get: { model.upnpEnabled },
                        set: { newValue in model.enableUpnp(enable: newValue) }
                    ))
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: Color.jamiColor))
                }

                HStack {
                    Text(L10n.AccountPage.turnEnabled)
                    Spacer()
                    Toggle("", isOn: Binding<Any>.customBinding(
                        get: { model.turnEnabled },
                        set: { newValue in model.enableTurn(enable: newValue) }
                    ))
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: Color.jamiColor))
                }

                if model.turnEnabled {
                    HStack {
                        Text(L10n.AccountPage.turnServer)
                        Spacer()
                        TextField(L10n.AccountPage.turnServer, text: $model.turnServer, onCommit: {
                            model.saveTurnSettings()
                        })
                        .autocorrectionDisabled(true)
                        .autocapitalization(.none)
                        .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text(L10n.AccountPage.turnUsername)
                        Spacer()
                        TextField(L10n.AccountPage.turnUsername, text: $model.turnUsername, onCommit: {
                            model.saveTurnSettings()
                        })
                        .autocorrectionDisabled(true)
                        .autocapitalization(.none)
                        .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text(L10n.AccountPage.turnPassword)
                        Spacer()
                        TextField(L10n.AccountPage.turnPassword, text: $model.turnPassword, onCommit: {
                            model.saveTurnSettings()
                        })
                        .autocorrectionDisabled(true)
                        .autocapitalization(.none)
                        .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text(L10n.AccountPage.turnRealm)
                        Spacer()
                        TextField(L10n.AccountPage.turnRealm, text: $model.turnRealm, onCommit: {
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
        .navigationTitle(L10n.AccountPage.conenctivityAndConfiguration)
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
                    Text(L10n.AccountPage.enableSRTP)
                    Spacer()
                    Toggle("", isOn: Binding<Any>.customBinding(
                        get: { model.enableSRTP },
                        set: { newValue in model.enableSRTP(enable: newValue) }
                    ))
                    .labelsHidden()
                }
                HStack {
                    Text(L10n.AccountPage.tlsVerifyServerCertificates)
                    Spacer()
                    Toggle("", isOn: Binding<Any>.customBinding(
                        get: { model.tlsVerifyServer },
                        set: { newValue in model.enableVerifyTlsServer(enable: newValue) }
                    ))
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: Color.jamiColor))
                }

                HStack {
                    Text(L10n.AccountPage.tlsVerifyClientCertificates)
                    Spacer()
                    Toggle("", isOn: Binding<Any>.customBinding(
                        get: { model.tlsVerifyClient },
                        set: { newValue in model.enableVerifyTlsClient(enable: newValue) }
                    ))
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: Color.jamiColor))
                }

                HStack {
                    Text(L10n.AccountPage.tlsRequireTlsCertificate)
                    Spacer()
                    Toggle("", isOn: Binding<Any>.customBinding(
                        get: { model.tlsRequireClientCertificate },
                        set: { newValue in model.enableTlsClientCertificate(enable: newValue) }
                    ))
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: Color.jamiColor))
                }

                HStack {
                    Text(L10n.AccountPage.tlsDisableSecureDlgCheck)
                    Spacer()
                    Toggle("", isOn: Binding<Any>.customBinding(
                        get: { model.disableSecureDlgCheck },
                        set: { newValue in model.disableSecureDlgCheck(disable: newValue) }
                    ))
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: Color.jamiColor))
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(L10n.AccountPage.security)
    }
}

struct EditExpirationtime: View {
    @Binding var expirationtime: String
    var onDisappearAction: () -> Void
    @SwiftUI.State private var isTextFieldFocused = false
    @SwiftUI.State private var stepperValue: Int = 0

    var body: some View {
        Form {
            Section(footer: Text(L10n.AccountPage.selectSipExpirationTime)) {
                HStack {
                    TextField(L10n.Global.time, text: $expirationtime)
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
        .navigationTitle(L10n.AccountPage.editSipExpirationTime)
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
