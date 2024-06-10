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

struct SettingsSummaryView: View {
    @ObservedObject var model: AccountSummaryVM
    @Environment(\.presentationMode) var presentation
    @SwiftUI.State private var showRemovalAlert = false
    var body: some View {
        List {
            Section(header: Text("account settings"), footer: Text("These settings will only apply for this account")) {
                NavigationLink(destination: CallSettingsView(injectionBag: model.injectionBag, account: model.account)) {
                    SettingsRow(iconName: "phone", title: "Call")
                }
                NavigationLink(destination: NotificationsSettingsView(injectionBag: model.injectionBag, account: model.account)) {
                    SettingsRow(iconName: "bell", title: "Notifications")
                }
                NavigationLink(destination: ConnectivitySettingsView(injectionBag: model.injectionBag, account: model.account)) {
                    SettingsRow(iconName: "link", title: "Connectivity & configurations")
                }
            }

            Section(header: Text("app settings"), footer: Text("These settings will apply on all the application")) {
                NavigationLink(destination: FileTransferSettingsView()) {
                    SettingsRow(iconName: "folder", title: "File transfer")
                }
                NavigationLink(destination: LocationSharingSettingsView()) {
                    SettingsRow(iconName: "location", title: "Location sharing")
                }
                NavigationLink(destination: VideoSettingsView()) {
                    SettingsRow(iconName: "video", title: "Video")
                }
                NavigationLink(destination: DiagnosticsSettingsView()) {
                    SettingsRow(iconName: "waveform.path.ecg", title: "Diagnostics")
                }
            }
        }
        .navigationTitle("Settings")
        .listStyle(InsetGroupedListStyle())
    }
}

struct SettingsRow: View {
    var iconName: String
    var title: String

    var body: some View {
        HStack {
            Image(systemName: iconName)
                .frame(width: 20, height: 20)
                .foregroundColor(.primary)
            Text(title)
                .foregroundColor(.primary)
        }
    }
}


