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

struct ChatSettingsView: View {
    var body: some View {
        Text("Chat Settings")
    }
}

struct CallSettingsView: View {
    var body: some View {
        Text("Call Settings")
    }
}

struct NotificationsSettingsView: View {
    var model: AccountSettings
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
                        Text(L10n.AccountPage.notificatioerrorPart1)
                            .font(.footnote)
                            .foregroundColor(.red) + Text(" ")
                            .font(.footnote)
                            .foregroundColor(.red) + Text(L10n.AccountPage.notificatioerrorPart2)
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
                    .labelsHidden()
                    .toggleStyle(.switch)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(L10n.AccountPage.notificationTitle)
        }
    }
}

struct ConnectivitySettingsView: View {
    var body: some View {
        Text("Connectivity & Configurations Settings")
    }
}

struct FileTransferSettingsView: View {
    var body: some View {
        Text("File Transfer Settings")
    }
}

struct LocationSharingSettingsView: View {
    var body: some View {
        Text("Location Sharing Settings")
    }
}

struct VideoSettingsView: View {
    var body: some View {
        Text("Video Settings")
    }
}

struct DiagnosticsSettingsView: View {
    var body: some View {
        Text("Diagnostics Settings")
    }
}
