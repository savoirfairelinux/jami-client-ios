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
