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
                            .font(.largeTitle)
                            .foregroundColor(.white)
                    )
            } else if let registeredName = model.username {
                Circle()
                    .fill(Color(model.getProfileColor()))
                    .frame(width: width, height: height)
                    .overlay(
                        Text(String(registeredName.prefix(1)))
                            .font(.largeTitle)
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

    @SwiftUI.State private var isEditProfilePresented = false
    var body: some View {
            Form {
                Section(header: Text("Profile")) {
                    HStack {
                        ProfileImageView(model: model, width: 60, height: 60)
                            .frame(width: 60, height: 60)
                        if model.profileName.isEmpty {
                            Text("Name not selected")
                                .foregroundColor(.gray)
                        } else {
                            Text(model.profileName)
                                .font(.title3)
                        }
                        Spacer()
                        VStack {
                            Image(systemName: "pencil")
                                .resizable()
                                .foregroundColor(Color.gray)
                                .frame(width: 15, height: 15)
                            Spacer()
                        }
                    }
                    .padding(.vertical, 8)
                    .onTapGesture {
                        model.presentEditProfile()
                        isEditProfilePresented = true
                    }
                    .sheet(isPresented: $isEditProfilePresented) {
                        EditProfileView(isPresented: $isEditProfilePresented, model: model)
                    }
                }

                Section(header: Text("Account")) {
                    HStack {
                        Text("Online")
                        Spacer()
                        Toggle("", isOn: .constant(true))
                            .labelsHidden()
                            .toggleStyle(SwitchToggleStyle(tint: .green))
                    }
                }

                Section(header: EmptyView().padding(.bottom, -10), footer: EmptyView())  {
                    Text("Simona")
                        .lineLimit(1)
                    HStack {
                        Text("jhgtyu8765434567ygfertyefg...")
                            .foregroundColor(.gray)
                            .lineLimit(1)
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
                    //NavigationLink(destination: InviteFriendsView()) {
                    //}
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
}

struct EditProfileView: View {
    @Binding var isPresented: Bool
    @ObservedObject var model: AccountVM
    @SwiftUI.State private var profileImage: Image? = Image(systemName: "person.circle")
    @SwiftUI.State private var profileName: String = ""
    
    @SwiftUI.State private var showingImagePicker = false
    @SwiftUI.State private var imagePickerType: PhotoSheetType?
    
    var body: some View {
        NavigationView {
            VStack(alignment: .center) {
                Text("Profile Image:")
                    .font(.title3)
                Button(action: {
                    showingImagePicker = true
                }) {
                    ZStack {
                        ProfileImageView(model: model, width: 100, height: 100)
                            .frame(width: 100, height: 100)
                        Circle()
                            .fill(Color.black.opacity(0.5))
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: "camera.fill")
                            .foregroundColor(.white)
                            .padding(8)
                    }
                }
                .actionSheet(isPresented: $showingImagePicker) {
                    ActionSheet(
                        title: Text("Select accounmt profile image"),
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
                
                Text("Profile name:")
                    .font(.title3)
                
                TextField("Enter your profile name", text: $model.newName)
                    .font(.title3)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                    .padding(.bottom, 20)
                
                Spacer()
            }
            .padding()
            .navigationBarTitle("Edit Profile", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    isPresented = false
                },
                trailing: Button("Save") {
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

struct CustomFooter: View {
    var height: CGFloat

    var body: some View {
        Spacer()
            .frame(height: height)
            .background(Color.clear)
    }
}


