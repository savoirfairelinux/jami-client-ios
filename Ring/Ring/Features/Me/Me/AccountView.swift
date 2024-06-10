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
import RxSwift

struct AccountView: View {
    init(injectionBag: InjectionBag, account: AccountModel, stateSubject: PublishSubject<State>) {
        _model = StateObject(wrappedValue: AccountVM(injectionBag: injectionBag, account: account, stateSubject: stateSubject))
    }
    @StateObject var model: AccountVM

    @SwiftUI.State private var showEditPrpofile = false
    @SwiftUI.State private var showAccountRegistration = false
    @SwiftUI.State private var showQRcode = false

    @Environment(\.presentationMode) var presentation

    let avatarSize: CGFloat = 60

    var userManagedOn: Binding<Bool> {
        .init {
            return model.accountEnabled
        } set: { newValue in
            self.model.enableAccount(enable: newValue)
        }
    }
    var body: some View {
        ZStack {
            Form {
                Section(header: Text(L10n.AccountPage.profileHeader)) {
                    HStack {
                        AvatarImageView(model: model, width: avatarSize, height: avatarSize)
                        Spacer()
                            .frame(width: 15)
                        profileName()
                        Spacer()
                        editProfileButton()
                    }
                    .padding(.vertical, 8)
                    .onTapGesture {
                        model.presentEditProfile()
                        showEditPrpofile = true
                    }
                    .sheet(isPresented: $showEditPrpofile) {
                        EditProfileView(isPresented: $showEditPrpofile, model: model)
                    }
                }

                Section(header: Text(L10n.AccountPage.accountHeader)) {
                    HStack {
                        Text(model.accountStatus)
                        Spacer()
                        Toggle("", isOn: userManagedOn)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                }

                Section {
                    usernameView()
                        .listRowBackground(Color(UIColor.systemBackground))
                    HStack {
                        Text(model.jamiId)
                            .conditionalTextSelection()
                            .truncationMode(.middle)
                            .lineLimit(1)
                        Spacer()
                            .frame(width: 15)
                        Spacer()
                        Image(systemName: "qrcode")
                            .foregroundColor(.jamiColor)
                            .onTapGesture {
                                showQRcode = true
                            }
                            .sheet(isPresented: $showQRcode) {
                                QRCodeView(isPresented: $showQRcode, jamiId: model.jamiId)
                            }
                    }
                    .listRowBackground(Color(UIColor.systemBackground))
                }

                Section {
                    NavigationLink(destination: ManageAccountView(model: model)) {
                        HStack {
                            Image(systemName: "person.crop.circle")
                            Text(L10n.AccountPage.manageAccount)
                        }
                    }
                    NavigationLink(destination: LinkedDevicesView()) {
                        HStack {
                            Image(systemName: "link")
                            Text("Linked devices")
                        }
                    }
                    ShareButtonView(accountInfoToShare: model.accountInfoToShare)
                }
            }
            if showAccountRegistration {
                NameRegistrationView(injectionBag: model.injectionBag, account: model.account, showAccountRegistration: $showAccountRegistration, nameRegisteredCb: {
                    model.nameRegistered()
                })
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(L10n.AccountPage.accountHeader)
        .navigationBarItems(leading:
                                Button(action: {
            presentation.wrappedValue.dismiss()
        }) {
            Image(systemName: "chevron.backward")
                .foregroundColor(.jamiColor)
        }, trailing: HStack {
            Button(action: {
            }) {
                Image(systemName: "gearshape.fill")
                    .foregroundColor(.jamiColor)
            }
        })
        .navigationBarBackButtonHidden(true)
        .onChange(of: model.accountRemoved) { _ in
            if model.accountRemoved {
                presentation.wrappedValue.dismiss()
            }
        }
    }

    func profileName() -> some View {
        if model.profileName.isEmpty {
            Text(L10n.AccountPage.profileNameNotSelected)
                .foregroundColor(.gray)
        } else {
            Text(model.profileName)
                .font(.title3)
        }
    }

    func editProfileButton() -> some View {
        VStack {
            Image(systemName: "pencil")
                .resizable()
                .foregroundColor(Color.gray)
                .frame(width: 15, height: 15)
            Spacer()
        }
    }

    func usernameView() -> some View {
        if let name = model.username {
            return AnyView(
                Text(name)
                    .conditionalTextSelection()
            )
        } else {
            return AnyView(
                Button(action: {
                    withAnimation {
                        showAccountRegistration = true
                    }
                }) {
                    HStack {
                        Group {
                            Image(systemName: "person.crop.circle.badge.checkmark")
                            Text(L10n.Global.registerAUsername)
                        }
                        .foregroundColor(.jamiColor)
                    }
                }
            )
        }
    }
}

struct LinkedDevicesView: View {
    var body: some View {
        Text("Linked Devices View")
    }
}

struct EncryptAccount: View {
    var body: some View {
        Text("EncryptAccount")
    }
}
