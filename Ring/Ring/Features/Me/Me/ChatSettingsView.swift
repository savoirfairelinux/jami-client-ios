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
                        get: { model.callsFromUnknownContacts},
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
                        VStack{
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
                        get: { model.proxyEnabled},
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
                        get: { model.autoConnectOnLocalNetwork},
                        set: { newValue in model.enableAutoConnectOnLocalNetwork(enable: newValue) }
                    ))
                }
            }
            Section(header: Text("connectivity")) {
                HStack {
                    Text("Use UPnP")
                    Spacer()
                    Toggle("", isOn: Binding<Any>.customBinding(
                        get: { model.upnpEnabled},
                        set: { newValue in model.enableUpnp(enable: newValue) }
                    ))
                }
                
                HStack {
                    Text("Enable TURN")
                    Spacer()
                    Toggle("", isOn: Binding<Any>.customBinding(
                        get: { model.turnEnabled},
                        set: { newValue in model.enableTurn(enable: newValue) }
                    ))
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

struct FileTransferSettingsView: View {
    @StateObject var model: GeneralSettings

    init(injectionBag: InjectionBag) {
        _model = StateObject(wrappedValue: GeneralSettings(injectionBag: injectionBag))
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Automaticly accept incoming files")
                    Spacer()
                    Toggle("", isOn: Binding<Any>.customBinding(
                        get: { model.automaticlyDownloadIncomingFiles},
                        set: { newValue in model.enableAutomaticlyDownload(enable: newValue) }
                    ))
                }
                HStack {
                    Text("Accept transfer limit") + Text("(in Mb, 0 = unlimited)")
                        .font(.footnote)
                        .foregroundColor(Color(UIColor.secondaryLabel))
                    Spacer()
                    TextField("", text: $model.downloadLimit, onCommit: {
                        model.saveDownloadLimit()
                    })
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .disabled(!model.automaticlyDownloadIncomingFiles)
                    .foregroundColor(model.automaticlyDownloadIncomingFiles ? .jamiColor : Color(UIColor.secondaryLabel))
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("File transfer")
    }
}

struct LocationSharingSettingsView: View {

    @SwiftUI.State private var selectedHours: Int = 0
    @SwiftUI.State private var selectedMinutes: Int = 1
    @StateObject var model: GeneralSettings

    let hourRange = Array(0...10)
    let minuteRange = Array(0...59)
    init(injectionBag: InjectionBag) {
        _model = StateObject(wrappedValue: GeneralSettings(injectionBag: injectionBag))
    }
    var body: some View {
        List {
            Section {
                HStack {
                    Text("Limit the duration of location sharing")
                    Spacer()
                    Toggle("", isOn: Binding<Any>.customBinding(
                        get: { model.limitLocationSharing},
                        set: { newValue in model.enableLocationSharingLimit(enable: newValue) }
                    ))
                }

                HStack {
                    Picker("Hours", selection: $selectedHours) {
                        ForEach(hourRange, id: \.self) { hour in
                            Text("\(hour) h")
                                .tag(hour)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 100, height: 150)

                    Picker("Minutes", selection: $selectedMinutes) {
                        ForEach(minuteRange, id: \.self) { minute in
                            Text("\(minute) min")
                                .tag(minute)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 100, height: 150)
                    .clipped()
                }
                .pickerStyle(WheelPickerStyle())
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Location sharing")
        }
    }
}

struct VideoSettingsView: View {
    @StateObject var model: GeneralSettings

    init(injectionBag: InjectionBag) {
        _model = StateObject(wrappedValue: GeneralSettings(injectionBag: injectionBag))
    }
    var body: some View {
        List {
            Section {
                HStack {
                    Text("Enable video acceleration")
                    Spacer()
                    Toggle("", isOn: Binding<Any>.customBinding(
                        get: { model.videoAccelerationEnabled},
                        set: { newValue in model.enableVideoAcceleration(enable: newValue) }
                    ))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Video")
        }
    }
}
