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

struct AccountSummaryView: View {
    @StateObject var model: AccountSummaryVM

    let state = AccountStatePublisher()

    @SwiftUI.State private var showEditPrpofile = false
    @SwiftUI.State private var showAccountRegistration = false
    @SwiftUI.State private var showQRcode = false

    let avatarSize: CGFloat = 60

    init(injectionBag: InjectionBag, account: AccountModel) {
        _model = StateObject(wrappedValue:
                                AccountSummaryVM(injectionBag: injectionBag,
                                                 account: account))
    }

    var body: some View {
        ZStack {
            Form {
                profileSection()

                Section(header: Text(L10n.AccountPage.accountHeader)) {
                    HStack {
                        Text(model.accountStatus)
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { model.accountEnabled },
                            set: { newValue in model.enableAccount(enable: newValue) }
                        ))
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: Color.jamiColor))
                    }
                    .accessibilityElement(children: .combine)
                }

                if model.account.type == .sip {
                    Section {
                        NavigationLink(destination: ManageSipAccountView(injectionBag: model.injectionBag, account: model.account, removeAccount: {
                            model.removeAccount(statePublisher: self.state)
                        })) {
                            SettingsRow(iconName: "person.crop.circle", title: L10n.AccountPage.manageAccount)
                        }
                    }
                } else {
                    userIdentitySection()
                    Section {
                        NavigationLink(destination: ManageAccountView(model: model, state: self.state)) {
                            SettingsRow(iconName: "person.crop.circle", title: L10n.AccountPage.manageAccount)
                        }
                        NavigationLink(destination: LinkedDevicesView(account: model.account, accountService: model.accountService)) {
                            SettingsRow(iconName: "link", title: L10n.AccountPage.linkedDevices)
                        }
                        ShareButtonView(infoToShare: model.accountInfoToShare) {
                            HStack {
                                Spacer()
                                Group {
                                    Image(systemName: "envelope")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 18, height: 18)
                                        .padding(.trailing, 5)
                                    Text(L10n.Smartlist.inviteFriends)
                                }
                                .foregroundColor(.jamiColor)
                                Spacer()
                            }
                        }
                    }
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
        .navigationBarItems(leading: Button(action: {[weak state] in
            state?.dismiss()
        }, label: {
            Text(L10n.Global.close)
                .foregroundColor(.jamiColor)
        }),
        trailing:
            NavigationLink(destination: SettingsSummaryView(model: model)) {
                Image(systemName: "gearshape.fill")
                    .foregroundColor(.jamiColor)
                    .accessibilityLabel(L10n.Accessibility.accountSummaryEditSettingsButton)
            })
    }

    func userIdentitySection() -> some View {
        Section {
            usernameView()
                .listRowBackground(Color(UIColor.secondarySystemGroupedBackground))
            HStack {
                Text(model.jamiId)
                    .conditionalTextSelection()
                    .truncationMode(.middle)
                    .lineLimit(1)
                    .accessibilityHidden(true)

                Spacer()
                    .frame(width: 15)
                Spacer()

                Button(action: {
                    showQRcode = true
                }, label: {
                    Image(systemName: "qrcode")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                        .foregroundColor(.jamiColor)
                })
                .sheet(isPresented: $showQRcode) {
                    QRCodePresenter(isPresented: $showQRcode, jamiId: model.jamiId, accessibilityLabel: L10n.Accessibility.accountSummaryQrCode)
                }
                .accessibilityLabel(L10n.Accessibility.accountSummaryQrCode)
                .accessibilityHint(L10n.Accessibility.accountSummaryQrCodeHint)
                .buttonStyle(PlainButtonStyle())
            }
            .listRowBackground(Color(UIColor.secondarySystemGroupedBackground))
        }
    }

    func profileSection() -> some View {
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
                showEditPrpofile = true
            }
            .sheet(isPresented: $showEditPrpofile) {
                EditProfileView(accountModel: model,
                                isPresented: $showEditPrpofile)
            }
            .accessibilityElement(children: /*@START_MENU_TOKEN@*/.ignore/*@END_MENU_TOKEN@*/)
            .accessibilityLabel(getProfileName())
            .accessibilityHint(L10n.Accessibility.accountSummaryEditProfileHint)
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

    func getProfileName() -> String {
        if model.profileName.isEmpty {
            return L10n.AccountPage.profileNameNotSelected
        } else {
            return model.profileName
        }
    }

    func editProfileButton() -> some View {
        VStack {
            Image(systemName: "pencil")
                .resizable()
                .foregroundColor(Color.secondary)
                .frame(width: 15, height: 15)
            Spacer()
        }
    }

    func usernameView() -> some View {
        if model.account.isJams {
            return AnyView(
                Text(model.username ?? "")
                    .conditionalTextSelection()
            )
        }
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
                }, label: {
                    HStack {
                        Group {
                            Image(systemName: "person.crop.circle.badge.checkmark")
                            Text(L10n.Global.registerAUsername)
                        }
                        .foregroundColor(.jamiColor)
                    }
                })
            )
        }
    }
}
