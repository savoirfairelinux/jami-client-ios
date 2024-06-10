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

    @SwiftUI.State var editingDevice: String = ""
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
                Section(header: Text(L10n.AccountPage.thisDevice)) {
                    ForEach(model.devices, id: \.self) { device in
                        if device.isCurrent {
                            createDeviceRow(device: device)
                        }
                    }
                }
                if !model.devices.filter({ device in
                    !device.isCurrent
                }).isEmpty {
                    Section(header: Text(L10n.AccountPage.otherDevices)) {
                        ForEach(model.devices, id: \.self) { device in
                            if !device.isCurrent {
                                createDeviceRow(device: device)
                            }
                        }
                    }
                }
                linkDeviceButton()
            }
            if showRevocationAlert {
                RevocationView(model: model, showRevocationAlert: $showRevocationAlert, deviceToRevoke: $deviceToRevoke)
            }

            if model.showLinkDeviceAlert {
                LinkDeviceView(model: model, askForPassword: model.hasPassword())
            }
        }
        .onChange(of: showRevocationAlert) { _ in
            if !showRevocationAlert {
                deviceToRevoke = nil
                model.cleanInfoMessages()
            }
        }
        .onChange(of: model.showLinkDeviceAlert ) { _ in
            if !model.showLinkDeviceAlert {
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
                    if editingDevice != device.deviceId {
                        Text(name)
                            .conditionalTextSelection()
                    } else {
                        FocusableTextField(text: $deviceName, isFirstResponder: $isFocused)
                    }
                }
                Text(device.deviceId)
                    .font(.footnote)
                    .foregroundColor(Color(UIColor.secondaryLabel))
                    .lineLimit(1)
                    .conditionalTextSelection()
            }
            Spacer()
            if !device.isCurrent {
                Text(L10n.Global.remove)
                    .foregroundColor(.jamiColor)
                    .onTapGesture {
                        deviceToRevoke = device
                        withAnimation {
                            showRevocationAlert = true
                        }
                    }
            } else {
                Text(editingDevice == device.deviceId ? L10n.Global.save : L10n.Global.edit)
                    .foregroundColor(.jamiColor)
                    .onTapGesture {
                        handleButtonAction(device: device)
                    }
            }
        }
        .padding(.vertical, 5)
    }

    func linkDeviceButton() -> some View {
        Button(action: {
            withAnimation {
                model.showLinkDevice()
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
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        .listRowBackground(Color.clear)
    }

    private func handleButtonAction(device: DeviceModel) {
        if editingDevice == device.deviceId {
            saveDeviceName()
        } else {
            enterEditMode(device: device)
        }
    }

    private func saveDeviceName() {
        model.editDeviceName(name: deviceName)
        isFocused = false
        editingDevice = ""
    }

    private func enterEditMode(device: DeviceModel) {
        if let name = device.deviceName {
            deviceName = name
        }
        isFocused = true
        editingDevice = device.deviceId
    }
}
