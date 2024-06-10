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
                leading: Button(action: {
                    isPresented = false
                }) {
                    Text(L10n.Global.cancel)
                        .foregroundColor(Color(UIColor.label))
                },
                trailing: Button(action: {
                    model.updateProfile()
                    isPresented = false
                }) {
                    Text(L10n.Global.save)
                        .foregroundColor(.jamiColor)
                }
            )
        }
    }
}

struct QRCodeView: View {
    @Binding var isPresented: Bool
    let jamiId: String
    @SwiftUI.State var image: UIImage?

    var body: some View {
        NavigationView {
            VStack {
                Spacer()
                    .frame(height: 20)
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 270, height: 270)
                        .cornerRadius(10)
                        .padding()
                }
                Spacer()
            }
            .navigationBarItems(leading: Button(action: {
                isPresented = false
            }) {
                Text(L10n.Global.cancel)
                    .foregroundColor(.jamiColor)
            })
        }
        .onTapGesture {
            isPresented = false
        }
        .onAppear {
            image = jamiId.generateQRCode()
        }
        .optionalMediumPresentationDetents()
    }
}

struct ManageAccountView: View {
    @ObservedObject var model: AccountVM
    @Environment(\.presentationMode) var presentation
    @SwiftUI.State private var showRemovalAlert = false
    var body: some View {
        Form {
            Section {
                NavigationLink(destination: BlockedContacts()) {
                    HStack {
                        Text("Blocked contacts")
                    }
                }
                NavigationLink(destination: EncryptAccount()) {
                    HStack {
                        Text("Encrypt account with a passord")
                    }
                }
            }

            Section {
                Button {
                    showRemovalAlert = true
                } label: {
                    HStack {
                        Spacer()
                        Text(L10n.Global.removeAccount)
                            .foregroundColor(Color(UIColor.jamiFailure))
                        Spacer()
                    }
                }
                .alert(isPresented: $showRemovalAlert) {
                    Alert(
                        title: Text(L10n.Global.removeAccount),
                        message: Text(L10n.AccountPage.removeAccountMessage),
                        primaryButton: .destructive(Text(L10n.AccountPage.removeAccountButton)) {
                            model.startAccountRemoving()
                        },
                        secondaryButton: .cancel()
                    )
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(L10n.AccountPage.manageAccount)
        .navigationBarItems(leading:
                                Button(action: {
            presentation.wrappedValue.dismiss()
        }) {
            HStack {
                Group {
                    Image(systemName: "chevron.backward")
                    Text(L10n.AccountPage.accountHeader)
                }
                .foregroundColor(.jamiColor)
            }
        })
        .navigationBarBackButtonHidden(true)
    }
}

struct LinkedDevicesView: View {
    var body: some View {
        Text("Linked Devices View")
    }
}

struct BlockedContacts: View {
    var body: some View {
        Text("BlockedContacts")
    }
}

struct EncryptAccount: View {
    var body: some View {
        Text("EncryptAccount")
    }
}

struct ActivityViewController: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct ShareButtonView: View {
    let accountInfoToShare: String
    @SwiftUI.State private var showShareView = false

    var body: some View {
        VStack {
            if #available(iOS 16.0, *) {
                shareLinkButton
            } else {
                shareButtonFallback
            }
        }
    }

    // ShareLink for iOS 16 and above
    @available(iOS 16.0, *)
    private var shareLinkButton: some View {
        ShareLink(item: accountInfoToShare) {
            shareView()
        }
    }

    // Fallback for iOS versions prior to 16
    private var shareButtonFallback: some View {
        Button {
            showShareView = true
        } label: {
            shareView()
        }
        .sheet(isPresented: $showShareView) {
            ActivityViewController(activityItems: [accountInfoToShare])
        }
    }

    func shareView() -> some View {
        HStack {
            Group {
                Image(systemName: "envelope")
                Text("Invite friends")
            }
            .foregroundColor(.jamiColor)
        }
    }
}



