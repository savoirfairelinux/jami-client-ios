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
                ToggleCell(
                    toggleText: L10n.AccountPage.callsFromUnknownContacts,
                    getAction: { model.callsFromUnknownContacts },
                    setAction: { newValue in model.enableCallsFromUnknownContacts(enable: newValue) }
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(L10n.Global.call)
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
                ToggleCell(
                    toggleText: L10n.AccountPage.enableNotifications,
                    getAction: { model.proxyEnabled },
                    setAction: { newValue in model.enableNotifications(enable: newValue) }
                )
            }

            if model.proxyEnabled {
                Section(header: Text(L10n.AccountPage.proxyHeader), footer: Text(L10n.AccountPage.proxyExplanation)) {
                    ToggleCell(
                        toggleText: L10n.AccountPage.useProxyList,
                        getAction: { model.proxyListEnabled },
                        setAction: { newValue in model.enableProxyList(enable: newValue) }
                    )

                    if model.proxyListEnabled {
                        NavigationLink(destination: EditableFieldView(value: $model.proxyListUrl, title: L10n.AccountPage.proxyListURL, placeholder: L10n.AccountPage.proxyListURL, onDisappearAction: {
                            model.saveProxyListUrl()
                        })) {
                            FieldRowView(label: L10n.AccountPage.proxyListURL, value: model.proxyListUrl)
                        }
                    } else {
                        NavigationLink(destination: EditableFieldView(value: $model.proxyAddress,
                                                                      title: L10n.AccountPage.proxyPaceholder,
                                                                      placeholder: L10n.AccountPage.proxyPaceholder,
                                                                      onDisappearAction: {
                                                                        model.saveProxyAddress()
                                                                      })) {
                            FieldRowView(label: L10n.AccountPage.proxyPaceholder, value: model.proxyAddress)
                        }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(L10n.AccountPage.notificationTitle)
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

struct NameServerView: View {
    @StateObject var model: AccountSettings

    init(injectionBag: InjectionBag, account: AccountModel) {
        _model = StateObject(wrappedValue: AccountSettings(account: account, injectionBag: injectionBag))
    }

    var body: some View {
        List {
            NavigationLink(destination: EditableFieldView(value: $model.serverName, title: L10n.AccountPage.nameServer, placeholder: L10n.Account.serverLabel, onDisappearAction: {
                model.saveNameServer()
            })) {
                FieldRowView(label: L10n.AccountPage.nameServer, value: model.serverName)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(L10n.AccountPage.notificationTitle)
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
                    ToggleCell(
                        toggleText: L10n.AccountPage.autoRegistration,
                        getAction: { model.autoRegistrationEnabled },
                        setAction: { newValue in model.enableaAtoregister(enable: newValue) }
                    )

                    NavigationLink(destination: EditExpirationtime(expirationtime: $model.autoRegistrationExpirationTime, onDisappearAction: {
                        model.setExpirationTime()
                    })) {
                        FieldRowView(label: L10n.AccountPage.sipExpirationTime, value: model.autoRegistrationExpirationTime)
                    }
                }

            } else {
                dhtConfigurationView()
            }
            connectivityView()
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(L10n.AccountPage.connectivityAndConfiguration)
    }

    func dhtConfigurationView() -> some View {
        Section(header: Text(L10n.AccountPage.dhtConfiguration)) {
            NavigationLink(destination: EditableFieldView(value: $model.bootstrap,
                                                          title: L10n.AccountPage.bootstrap,
                                                          placeholder: L10n.AccountPage.bootstrap,
                                                          onDisappearAction: {
                                                            model.saveBootstrap()
                                                          })) {
                FieldRowView(label: L10n.AccountPage.bootstrap, value: model.bootstrap)
            }
            VStack(alignment: .leading) {
                ToggleCell(
                    toggleText: L10n.AccountPage.peerDiscovery,
                    getAction: { model.peerDiscovery },
                    setAction: { newValue in model.enablePeerDiscovery(enable: newValue) }
                )
                Text(L10n.AccountPage.peerDiscoveryExplanation)
                    .font(.footnote)
                    .foregroundColor(Color(UIColor.secondaryLabel))
            }
        }
    }

    func connectivityView() -> some View {
        Section(header: Text(L10n.AccountPage.connectivityHeader)) {
            ToggleCell(
                toggleText: L10n.AccountPage.upnpEnabled,
                getAction: { model.upnpEnabled },
                setAction: { newValue in model.enableUpnp(enable: newValue) }
            )

            ToggleCell(
                toggleText: L10n.AccountPage.turnEnabled,
                getAction: { model.turnEnabled },
                setAction: { newValue in model.enableTurn(enable: newValue) }
            )

            if model.turnEnabled {
                NavigationLink(destination: EditableFieldView(value: $model.turnServer, title: L10n.AccountPage.turnServer, placeholder: L10n.AccountPage.turnServer, onDisappearAction: {
                    model.saveTurnSettings()
                })) {
                    FieldRowView(label: L10n.AccountPage.turnServer, value: model.turnServer)
                }
                NavigationLink(destination: EditableFieldView(value: $model.turnUsername, title: L10n.AccountPage.turnUsername, placeholder: L10n.AccountPage.turnUsername, onDisappearAction: {
                    model.saveTurnSettings()
                })) {
                    FieldRowView(label: L10n.AccountPage.turnUsername, value: model.turnUsername)
                }

                NavigationLink(destination: EditPasswordView(password: $model.turnPassword, onDisappearAction: {
                    model.saveTurnSettings()
                })) {
                    FieldRowView(label: L10n.AccountPage.turnPassword, value: model.turnPassword.maskedPassword)
                }

                NavigationLink(destination: EditableFieldView(value: $model.turnRealm, title: L10n.AccountPage.turnRealm, placeholder: L10n.AccountPage.turnRealm, onDisappearAction: {
                    model.saveTurnSettings()
                })) {
                    FieldRowView(label: L10n.AccountPage.turnRealm, value: model.turnRealm)
                }
            }
        }
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
                ToggleCell(
                    toggleText: L10n.AccountPage.enableSRTP,
                    getAction: { model.enableSRTP },
                    setAction: { newValue in model.enableSRTP(enable: newValue) }
                )
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
