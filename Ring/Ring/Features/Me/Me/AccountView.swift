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

struct ProfileImageView: View {
    @ObservedObject var model: AccountVM
    @SwiftUI.State var width: CGFloat
    @SwiftUI.State var height: CGFloat
    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let image = model.profileImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipShape(Circle())
            } else if !model.profileName.isEmpty {
                Circle()
                    .fill(Color(model.getProfileColor()))
                    .frame(width: width, height: height)
                    .overlay(
                        Text(String(model.profileName.prefix(1)))
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    )
            } else if let registeredName = model.username {
                Circle()
                    .fill(Color(model.getProfileColor()))
                    .frame(width: width, height: height)
                    .overlay(
                        Text(String(registeredName.prefix(1)))
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    )
            } else {
                Image(systemName: "person")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .padding(20)
                    .background(Color(model.getProfileColor()))
                    .foregroundColor(Color.white)
                    .frame(width: width, height: height)
                    .clipShape(Circle())
            }
        }
        .frame(width: width, height: height)
    }
}

struct AccountView: View {
    init(injectionBag: InjectionBag, account: AccountModel) {
        _model = StateObject(wrappedValue: AccountVM(injectionBag: injectionBag, account: account))
    }
    @StateObject var model: AccountVM

    @SwiftUI.State private var showEditPrpofile = false
    @SwiftUI.State private var showAccountRegistration = false

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
                        ProfileImageView(model: model, width: avatarSize, height: avatarSize)
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
                            .toggleStyle(SwitchToggleStyle(tint: .green))
                    }
                }

                Section {
                    usernameView()
                    HStack {
                        Text(model.jamiId)
                            .conditionalTextSelection()
                            .truncationMode(.middle)
                            .lineLimit(1)
                        Spacer()
                            .frame(width: 15)
                        Spacer()
                        Button {
                            print("Edit button was tapped")
                        } label: {
                            Image(systemName: "qrcode")
                        }
                    }
                }

                Section {
                    NavigationLink(destination: ManageAccountView()) {
                        HStack {
                            Image(systemName: "person.crop.circle")
                            Text("Manage account")
                        }
                    }
                    NavigationLink(destination: LinkedDevicesView()) {
                        HStack {
                            Image(systemName: "link")
                            Text("Linked devices")
                        }
                    }

                    Button {
                        print("Edit button was tapped")
                    } label: {
                        HStack {
                            Image(systemName: "envelope")
                            Text("Invite friends")
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
            .navigationTitle("Account")
            .navigationBarItems(trailing: HStack {
                Button(action: {
                }) {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(.blue)
                }
            })
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
                        Image(systemName: "person.crop.circle.badge.checkmark")
                        Text(L10n.Global.registerAUsername)
                    }
                }
            )
        }
    }
}

struct EditProfileView: View {
    @Binding var isPresented: Bool
    @ObservedObject var model: AccountVM
    @SwiftUI.State private var profileImage: Image? = Image(systemName: "person.circle")
    @SwiftUI.State private var profileName: String = ""
    
    @SwiftUI.State private var showingImagePicker = false
    @SwiftUI.State private var imagePickerType: PhotoSheetType?

    let avatarSize: CGFloat = 100

    var body: some View {
        NavigationView {
            VStack(alignment: .center) {
                Button(action: {
                    showingImagePicker = true
                }) {
                    ZStack {
                        ProfileImageView(model: model, width: avatarSize, height: avatarSize)
                        Circle()
                            .fill(Color.black.opacity(0.5))
                            .frame(width: avatarSize, height: avatarSize)

                        Image(systemName: "camera.fill")
                            .foregroundColor(.white)
                            .padding(8)
                    }
                }
                .actionSheet(isPresented: $showingImagePicker) {
                    ActionSheet(
                        title: Text(""),
                        buttons: [
                            .default(Text(L10n.Alerts.profileTakePhoto)) {
                                imagePickerType = .picture
                            },
                            .default(Text(L10n.Alerts.profileUploadPhoto)) {
                                imagePickerType = .gallery
                            },
                            .cancel()
                        ]
                    )
                }
                .sheet(item: $imagePickerType) { type in
                    let sourceType: UIImagePickerController.SourceType = type == .picture ? .camera : .photoLibrary
                    ImagePicker(sourceType: sourceType, showingType: $imagePickerType, image: $model.newImage)
                }
                
                Spacer()
                    .frame(height: 40)
                
                Text(L10n.AccountPage.profileName)

                TextField(L10n.AccountPage.profileNamePlaceholder, text: $model.newName)
                    .padding()
                    .autocorrectionDisabled(true)
                    .autocapitalization(.none)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                    .padding(.bottom, 20)
                
                Spacer()
            }
            .padding()
            .navigationBarTitle(L10n.AccountPage.editProfile, displayMode: .inline)
            .navigationBarItems(
                leading: Button(L10n.Global.cancel) {
                    isPresented = false
                },
                trailing: Button(L10n.Global.save) {
                    model.updateProfile()
                    isPresented = false
                }
            )
        }
    }
}

struct ManageAccountView: View {
    var body: some View {
        Text("Manage Account View")
    }
}

struct LinkedDevicesView: View {
    var body: some View {
        Text("Linked Devices View")
    }
}

struct InviteFriendsView: View {
    var body: some View {
        Text("Invite Friends View")
    }
}



