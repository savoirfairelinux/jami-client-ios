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

    var body: some View {
        List {
            Section(header: Text(L10n.Global.accountSettings), footer: Text(L10n.AccountPage.accountSettingsExplanation)) {
                if model.account.type == .sip {
                    NavigationLink(destination: SecuritySettingsView(injectionBag: model.injectionBag, account: model.account)) {
                        SettingsRow(iconName: "shield", title: L10n.AccountPage.security)
                    }
                } else {
                    NavigationLink(destination: CallSettingsView(injectionBag: model.injectionBag, account: model.account)) {
                        SettingsRow(iconName: "phone", title: L10n.Global.call)
                    }
                    NavigationLink(destination: NotificationsSettingsView(injectionBag: model.injectionBag, account: model.account)) {
                        SettingsRow(iconName: "bell", title: L10n.AccountPage.notificationsHeader)
                    }

                    NavigationLink(destination: NameServerView(injectionBag: model.injectionBag, account: model.account)) {
                        SettingsRow(iconName: "server.rack", title: L10n.AccountPage.nameServer)
                    }
                }
                NavigationLink(destination: ConnectivitySettingsView(injectionBag: model.injectionBag, account: model.account)) {
                    SettingsRow(iconName: "link", title: L10n.AccountPage.connectivityAndConfiguration)
                }
            }

            Section(header: Text(L10n.AccountPage.appSettings), footer: Text(L10n.AccountPage.appSettingsExplanation)) {
                if model.account.type != .sip {
                    NavigationLink(destination: FileTransferSettingsView(injectionBag: model.injectionBag)) {
                        SettingsRow(iconName: "folder", title: L10n.GeneralSettings.fileTransfer)
                    }
                    NavigationLink(destination: LocationSharingSettingsView(injectionBag: model.injectionBag)) {
                        SettingsRow(iconName: "location", title: L10n.GeneralSettings.locationSharing)
                    }
                    NavigationLink(destination: VideoSettingsView(injectionBag: model.injectionBag)) {
                        SettingsRow(iconName: "video", title: L10n.Global.video)
                    }
                }
                NavigationLink(destination: LogUI(injectiomBag: model.injectionBag)) {
                    SettingsRow(iconName: "waveform.path.ecg", title: L10n.LogView.title)
                }
            }
        }
        .navigationTitle(L10n.AccountPage.settingsHeader)
        .listStyle(InsetGroupedListStyle())
    }
}
